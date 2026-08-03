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

/// The connected Sleeper account plus ALL of the user's leagues, persisted so the
/// League screen can switch between them (identified by platform_league_id).
struct SleeperAccount: Codable, Equatable {
    var appUserId: String
    var userId: String
    var username: String
    var displayName: String
    var avatar: String?
    var season: Int
    var leagues: [SleeperLeague]
    var selectedLeagueId: String?

    var selectedLeague: SleeperLeague? {
        leagues.first { $0.leagueId == selectedLeagueId } ?? leagues.first
    }
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
    @Published var account: SleeperAccount?
    @Published var isSwitching = false
    @Published var loadError: String?

    private let api = SleeperAPIService.shared
    private let supabase = SupabaseService.shared
    private let auth = SupabaseAuth.shared
    private var pendingUser: SleeperUser?
    private var pendingSeason: Int = 0

    private let defaults = UserDefaults.standard
    private let connectionKey = "ciq.sleeperConnection"
    private let accountKey = "ciq.sleeperAccount"

    init() {
        // Restore the multi-league account + the last selected league's roster.
        if let data = defaults.data(forKey: accountKey),
           let savedAccount = try? JSONDecoder().decode(SleeperAccount.self, from: data) {
            account = savedAccount
        }
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
            let acct = SleeperAccount(
                appUserId: session.userId, userId: user.userId, username: user.username ?? "",
                displayName: user.displayName ?? "", avatar: user.avatar, season: pendingSeason,
                leagues: leagues, selectedLeagueId: account?.selectedLeagueId
            )
            account = acct
            persistAccount(acct)
            phase = .leagues(leagues)
        } catch {
            phase = .failed(message(error))
        }
    }

    /// Initial pick from the connect flow.
    func selectLeague(_ league: SleeperLeague) async {
        await activate(league, fromConnectFlow: true)
    }

    /// Switch to a different connected league from the League screen.
    func switchLeague(_ league: SleeperLeague) async {
        guard account?.selectedLeagueId != league.leagueId else { return }
        await activate(league, fromConnectFlow: false)
    }

    /// Retry loading the currently selected league.
    func reloadSelected() async {
        guard let league = account?.selectedLeague else { return }
        await activate(league, fromConnectFlow: false)
    }

    private func activate(_ league: SleeperLeague, fromConnectFlow: Bool) async {
        guard var acct = account, !acct.userId.isEmpty else {
            phase = .failed("Missing connected Sleeper account.")
            return
        }
        #if DEBUG
        print("👆 League tapped: \(league.name ?? "?") — platform_league_id \(league.leagueId)")
        #endif
        isSwitching = true
        loadError = nil
        roster = nil  // clear the previous league's content before showing the new one
        if fromConnectFlow { phase = .syncing }

        do {
            let session = try await auth.ensureSession()
            async let usersF = api.fetchLeagueUsers(leagueId: league.leagueId)
            async let rostersF = api.fetchRosters(leagueId: league.leagueId)
            let users = try await usersF
            let rosters = try await rostersF
            #if DEBUG
            print("🧩 Rosters returned: \(rosters.count) for platform_league_id \(league.leagueId)")
            #endif

            guard let mine = rosters.first(where: { $0.ownerId == acct.userId }) else {
                loadError = "Couldn't find your team in \(league.name ?? "that league")."
                isSwitching = false
                if fromConnectFlow { phase = .failed(loadError ?? "Load failed") }
                return
            }
            #if DEBUG
            print("✅ User roster matched: roster_id \(mine.rosterId), owner_id \(acct.userId)")
            #endif

            let teamName = users.first(where: { $0.userId == acct.userId })?.teamName ?? acct.displayName
            let starters = mine.starters ?? []
            let all = mine.players ?? []
            let bench = all.filter { !starters.contains($0) }

            let conn = SleeperConnection(
                appUserId: session.userId, userId: acct.userId, username: acct.username,
                displayName: acct.displayName, avatar: acct.avatar,
                leagueId: league.leagueId, leagueName: league.name ?? "League",
                scoringFormat: league.scoringFormat, season: acct.season,
                teamName: teamName, starterIds: starters, benchIds: bench, allPlayerIds: all
            )
            connection = conn
            persist(conn)

            acct.selectedLeagueId = league.leagueId
            acct.appUserId = session.userId
            account = acct
            persistAccount(acct)

            await resolveRoster()
            phase = .connected
            isSwitching = false

            await syncToSupabase(appUserId: session.userId, accessToken: session.accessToken,
                                 league: league, rosters: rosters)
        } catch {
            loadError = message(error)
            isSwitching = false
            if fromConnectFlow { phase = .failed(loadError ?? "Load failed") }
        }
    }

    func disconnect() {
        connection = nil
        roster = nil
        account = nil
        loadError = nil
        isSwitching = false
        defaults.removeObject(forKey: connectionKey)
        defaults.removeObject(forKey: accountKey)
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

    private func persistAccount(_ acct: SleeperAccount) {
        if let data = try? JSONEncoder().encode(acct) { defaults.set(data, forKey: accountKey) }
    }

    private func syncToSupabase(
        appUserId: String, accessToken: String,
        league: SleeperLeague, rosters: [SleeperRoster]
    ) async {
        guard let acct = account else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        let avatarURL = acct.avatar.map { "https://sleepercdn.com/avatars/thumbs/\($0)" }
        do {
            try await supabase.upsert(
                table: "connected_fantasy_accounts",
                rows: [ConnectedAccountRow(
                    app_user_id: appUserId, platform: "sleeper", platform_user_id: acct.userId,
                    platform_username: acct.username, display_name: acct.displayName,
                    avatar_url: avatarURL, connected_at: now, updated_at: now)],
                onConflict: "app_user_id,platform", accessToken: accessToken)

            // Persist selection: clear selected on all of the user's leagues, then
            // mark the chosen league selected = true.
            try await supabase.setLeaguesUnselected(appUserId: appUserId, accessToken: accessToken)

            let leagueRowId = await supabase.existingLeagueRowId(
                appUserId: appUserId, platform: "sleeper", platformLeagueId: league.leagueId,
                accessToken: accessToken) ?? UUID().uuidString
            #if DEBUG
            print("🆔 Supabase league UUID: \(leagueRowId) (platform_league_id \(league.leagueId))")
            #endif

            try await supabase.upsert(
                table: "fantasy_leagues",
                rows: [LeagueRow(
                    id: leagueRowId, app_user_id: appUserId, platform: "sleeper",
                    platform_league_id: league.leagueId, name: league.name, season: acct.season,
                    total_rosters: league.totalRosters, scoring_settings: league.scoringSettings,
                    roster_positions: league.rosterPositions, status: league.status,
                    selected: true, synced_at: now)],
                onConflict: "app_user_id,platform,platform_league_id", accessToken: accessToken)

            let rosterRows = rosters.map { r in
                RosterRow(
                    id: UUID().uuidString, fantasy_league_id: leagueRowId, platform_roster_id: r.rosterId,
                    platform_owner_id: r.ownerId, is_user_roster: r.ownerId == acct.userId,
                    players: r.players, starters: r.starters, reserve: r.reserve, taxi: r.taxi, synced_at: now)
            }
            try await supabase.upsert(table: "fantasy_rosters", rows: rosterRows,
                                      onConflict: "fantasy_league_id,platform_roster_id", accessToken: accessToken)
            #if DEBUG
            print("💾 Supabase selected-league update success: \(leagueRowId) selected=true, \(rosterRows.count) rosters")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Supabase selected-league update failed (non-blocking): \(message(error))")
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
