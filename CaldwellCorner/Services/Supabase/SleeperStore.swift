import Foundation
import SwiftUI

// MARK: - Coach context bridge (actor-safe snapshot the AI Coach can read)

struct SleeperRosterContext: Sendable {
    let leagueName: String
    let scoringFormat: String
    let teamName: String
    let starterSleeperIds: [String]
    let benchSleeperIds: [String]
    let allSleeperIds: [String]
}

actor SleeperContextBox {
    static let shared = SleeperContextBox()
    private(set) var context: SleeperRosterContext?
    func set(_ c: SleeperRosterContext?) { context = c }
    func get() -> SleeperRosterContext? { context }
}

// MARK: - Persisted connection

struct SleeperConnection: Codable, Equatable {
    var appUserId: String
    var userId: String
    var username: String
    var displayName: String
    var avatar: String?
    var leagueId: String
    var leagueName: String
    var scoringFormat: String
    var season: Int
    var teamName: String
    var starterIds: [String]
    var benchIds: [String]
    var allPlayerIds: [String]
}

/// A resolved roster for display: Sleeper ids matched to Caldwell IQ players.
struct ConnectedRoster: Equatable {
    var starters: [RankedPlayer]
    var bench: [RankedPlayer]
    var unmatched: [String]
}

// MARK: - Store

@MainActor
final class SleeperStore: ObservableObject {
    static let shared = SleeperStore()

    enum Phase: Equatable {
        case disconnected
        case connecting
        case leagues([SleeperLeague])
        case syncing
        case connected
        case failed(String)
    }

    @Published var phase: Phase = .disconnected
    @Published var connection: SleeperConnection?
    @Published var roster: ConnectedRoster?

    private let api = SleeperAPIService.shared
    private let supabase = SupabaseService.shared
    private let auth = SupabaseAuth.shared
    private var pendingUser: SleeperUser?
    private var pendingSeason: Int = 0

    private let defaults = UserDefaults.standard
    private let connectionKey = "ciq.sleeperConnection"

    init() {
        if let data = defaults.data(forKey: connectionKey),
           let saved = try? JSONDecoder().decode(SleeperConnection.self, from: data) {
            connection = saved
            phase = .connected
            Task { await resolveRoster() }
        }
    }

    // MARK: Flow

    func connect(username: String) async {
        phase = .connecting
        do {
            // RLS requires an authenticated session before any league sync.
            let session = try await auth.ensureSession()
            #if DEBUG
            print("🔐 Supabase auth user id (app_user_id): \(session.userId)")
            #endif

            let user = try await api.fetchUser(username: username)
            #if DEBUG
            print("🟢 Sleeper user resolved: @\(user.username ?? "?") (user_id \(user.userId))")
            #endif

            let state = try await api.fetchState()
            let seasons = [state.leagueSeason, state.season, state.previousSeason].compactMap { $0 }

            var leagues: [SleeperLeague] = []
            var used = ""
            for s in seasons {
                let found = (try? await api.fetchLeagues(userId: user.userId, season: s)) ?? []
                if !found.isEmpty { leagues = found; used = s; break }
            }
            #if DEBUG
            print("🏈 Leagues returned: \(leagues.count) (season \(used))")
            #endif
            guard !leagues.isEmpty else { phase = .failed(SleeperAPIService.SleeperError.noLeagues.errorDescription ?? "No leagues"); return }

            pendingUser = user
            pendingSeason = Int(used) ?? 0
            phase = .leagues(leagues)
        } catch {
            phase = .failed(message(error))
        }
    }

    func selectLeague(_ league: SleeperLeague) async {
        guard let user = pendingUser else { phase = .failed("Missing connected user."); return }
        phase = .syncing
        do {
            let session = try await auth.ensureSession()
            #if DEBUG
            print("📋 Selected league: \(league.name ?? "?") (\(league.leagueId))")
            #endif

            async let usersF = api.fetchLeagueUsers(leagueId: league.leagueId)
            async let rostersF = api.fetchRosters(leagueId: league.leagueId)
            let users = try await usersF
            let rosters = try await rostersF
            #if DEBUG
            print("🧩 Rosters returned: \(rosters.count); league users: \(users.count)")
            #endif

            guard let mine = rosters.first(where: { $0.ownerId == user.userId }) else {
                phase = .failed("Couldn't find your team in that league.")
                return
            }
            #if DEBUG
            print("✅ User roster matched: roster_id \(mine.rosterId), owner_id \(user.userId)")
            #endif

            let teamName = users.first(where: { $0.userId == user.userId })?.teamName ?? (user.displayName ?? "My Team")
            let starters = mine.starters ?? []
            let all = mine.players ?? []
            let bench = all.filter { !starters.contains($0) }

            let conn = SleeperConnection(
                appUserId: session.userId, userId: user.userId, username: user.username ?? "",
                displayName: user.displayName ?? "", avatar: user.avatar,
                leagueId: league.leagueId, leagueName: league.name ?? "League",
                scoringFormat: league.scoringFormat, season: pendingSeason,
                teamName: teamName, starterIds: starters, benchIds: bench, allPlayerIds: all
            )
            connection = conn
            persist(conn)
            await resolveRoster()
            phase = .connected

            // Persist to Supabase with the authenticated user's JWT (RLS-scoped).
            await syncToSupabase(appUserId: session.userId, accessToken: session.accessToken,
                                 user: user, league: league, rosters: rosters)
        } catch {
            phase = .failed(message(error))
        }
    }

    func disconnect() {
        connection = nil
        roster = nil
        defaults.removeObject(forKey: connectionKey)
        phase = .disconnected
        Task { await SleeperContextBox.shared.set(nil) }
    }

    // MARK: Roster resolution (match Sleeper ids -> players.sleeper_id)

    private func resolveRoster() async {
        guard let conn = connection else { return }
        let matched = (try? await supabase.fetchPlayersBySleeperIds(conn.allPlayerIds)) ?? []
        var bySleeper: [String: RankedPlayer] = [:]
        for p in matched { if let sid = p.sleeperId { bySleeper[sid] = p } }

        let starters = conn.starterIds.compactMap { bySleeper[$0] }
        let bench = conn.benchIds.compactMap { bySleeper[$0] }
        let unmatched = conn.allPlayerIds.filter { bySleeper[$0] == nil }
        #if DEBUG
        if !unmatched.isEmpty { print("⚠️ Sleeper: \(unmatched.count) unmatched player ids: \(unmatched.prefix(20))") }
        #endif
        roster = ConnectedRoster(starters: starters, bench: bench, unmatched: unmatched)

        await SleeperContextBox.shared.set(SleeperRosterContext(
            leagueName: conn.leagueName, scoringFormat: conn.scoringFormat, teamName: conn.teamName,
            starterSleeperIds: conn.starterIds, benchSleeperIds: conn.benchIds, allSleeperIds: conn.allPlayerIds
        ))
    }

    // MARK: Persistence

    private func persist(_ conn: SleeperConnection) {
        if let data = try? JSONEncoder().encode(conn) { defaults.set(data, forKey: connectionKey) }
    }

    private func syncToSupabase(
        appUserId: String, accessToken: String,
        user: SleeperUser, league: SleeperLeague, rosters: [SleeperRoster]
    ) async {
        let now = ISO8601DateFormatter().string(from: Date())
        do {
            try await supabase.upsert(
                table: "connected_fantasy_accounts",
                rows: [ConnectedAccountRow(
                    app_user_id: appUserId, platform: "sleeper", platform_user_id: user.userId,
                    platform_username: user.username, display_name: user.displayName,
                    avatar_url: user.avatarURL?.absoluteString, connected_at: now, updated_at: now)],
                onConflict: "app_user_id,platform", accessToken: accessToken)

            let leagueRowId = await supabase.existingLeagueRowId(
                appUserId: appUserId, platform: "sleeper", platformLeagueId: league.leagueId,
                accessToken: accessToken) ?? UUID().uuidString

            try await supabase.upsert(
                table: "fantasy_leagues",
                rows: [LeagueRow(
                    id: leagueRowId, app_user_id: appUserId, platform: "sleeper",
                    platform_league_id: league.leagueId, name: league.name, season: pendingSeason,
                    total_rosters: league.totalRosters, scoring_settings: league.scoringSettings,
                    roster_positions: league.rosterPositions, status: league.status,
                    selected: true, synced_at: now)],
                onConflict: "app_user_id,platform,platform_league_id", accessToken: accessToken)

            let rosterRows = rosters.map { r in
                RosterRow(
                    id: UUID().uuidString, fantasy_league_id: leagueRowId, platform_roster_id: r.rosterId,
                    platform_owner_id: r.ownerId, is_user_roster: r.ownerId == user.userId,
                    players: r.players, starters: r.starters, reserve: r.reserve, taxi: r.taxi, synced_at: now)
            }
            try await supabase.upsert(table: "fantasy_rosters", rows: rosterRows,
                                      onConflict: "fantasy_league_id,platform_roster_id", accessToken: accessToken)
            #if DEBUG
            print("💾 Supabase save success: account + league + \(rosterRows.count) rosters")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Supabase save failed (non-blocking): \(message(error))")
            #endif
        }
    }

    private func message(_ error: Error) -> String {
        (error as? SleeperAPIService.SleeperError)?.errorDescription
            ?? (error as? SupabaseService.ServiceError)?.errorDescription
            ?? error.localizedDescription
    }
}

// MARK: - Supabase row payloads

private struct ConnectedAccountRow: Encodable {
    let app_user_id: String
    let platform: String
    let platform_user_id: String
    let platform_username: String?
    let display_name: String?
    let avatar_url: String?
    let connected_at: String
    let updated_at: String
}

private struct LeagueRow: Encodable {
    let id: String
    let app_user_id: String
    let platform: String
    let platform_league_id: String
    let name: String?
    let season: Int
    let total_rosters: Int?
    let scoring_settings: [String: Double]?
    let roster_positions: [String]?
    let status: String?
    let selected: Bool
    let synced_at: String
}

private struct RosterRow: Encodable {
    let id: String
    let fantasy_league_id: String
    let platform_roster_id: Int
    let platform_owner_id: String?
    let is_user_roster: Bool
    let players: [String]?
    let starters: [String]?
    let reserve: [String]?
    let taxi: [String]?
    let synced_at: String
}
