import Foundation

/// Read-only service layer for Supabase, backed by its auto-generated PostgREST
/// API. The app calls Supabase directly for reads using ONLY the public anon /
/// publishable key (never the service_role key).
///
/// All methods are read-only `GET` requests against the `players` and `teams`
/// tables that already exist in the database.
actor SupabaseService {
    static let shared = SupabaseService()

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    enum ServiceError: LocalizedError {
        case notConfigured
        case badURL
        case http(status: Int, resource: String, body: String)
        case transport(Error)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase isn't configured. Add your project URL and anon key in SupabaseConfig."
            case .badURL:
                return "Could not build a valid Supabase request URL."
            case .http(let status, let resource, let body):
                let detail = body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)
                return "Supabase request failed (HTTP \(status)) for \(resource).\(detail.isEmpty ? "" : " \(detail)")"
            case .transport(let error):
                return "Network error: \(error.localizedDescription)"
            case .decoding:
                return "Received data in an unexpected format."
            }
        }
    }

    // MARK: - Players

    /// Fetch players with optional name search and team/position filters.
    /// - Parameters:
    ///   - search: case-insensitive substring match on `full_name`.
    ///   - team: NFL team abbreviation (matches the `team` column).
    ///   - position: a single position code such as `QB`, `RB`, `WR`, `TE`.
    ///   - positions: a set of position codes (e.g. FLEX = `["RB","WR","TE"]`).
    ///     Takes precedence over `position` when non-empty.
    ///   - activeOnly: when true, returns only active players.
    ///   - limit: maximum rows to return (high by default so a position filter
    ///     returns *all* matching players, not just a handful).
    func fetchPlayers(
        search: String? = nil,
        team: String? = nil,
        position: String? = nil,
        positions: [String]? = nil,
        activeOnly: Bool = true,
        limit: Int = 1000
    ) async throws -> [SupabasePlayer] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "full_name.asc"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        if let search, !search.trimmingCharacters(in: .whitespaces).isEmpty {
            let term = search.trimmingCharacters(in: .whitespaces)
            // PostgREST: case-insensitive LIKE with `*` wildcards.
            query.append(URLQueryItem(name: "full_name", value: "ilike.*\(term)*"))
        }
        if let team, !team.isEmpty {
            query.append(URLQueryItem(name: "team", value: "eq.\(team)"))
        }
        if let positions, !positions.isEmpty {
            // PostgREST `in` filter, e.g. position=in.(QB,RB,WR,TE). Also excludes
            // rows with a null position, keeping the list fantasy-relevant.
            query.append(URLQueryItem(name: "position", value: "in.(\(positions.joined(separator: ",")))"))
        } else if let position, !position.isEmpty {
            query.append(URLQueryItem(name: "position", value: "eq.\(position)"))
        }
        if activeOnly {
            query.append(URLQueryItem(name: "active", value: "eq.true"))
        }

        return try await get(table: "players", query: query)
    }

    /// Convenience: search players by (partial) name.
    func searchPlayers(name: String, limit: Int = 200) async throws -> [SupabasePlayer] {
        try await fetchPlayers(search: name, limit: limit)
    }

    /// Convenience: all players on a given team.
    func players(team: String, limit: Int = 200) async throws -> [SupabasePlayer] {
        try await fetchPlayers(team: team, limit: limit)
    }

    /// Convenience: all players at a given position.
    func players(position: String, limit: Int = 200) async throws -> [SupabasePlayer] {
        try await fetchPlayers(position: position, limit: limit)
    }

    /// Fetch a single player by its Sleeper id.
    func fetchPlayer(id: String) async throws -> SupabasePlayer? {
        let rows: [SupabasePlayer] = try await get(
            table: "players",
            query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "sleeper_id", value: "eq.\(id)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        return rows.first
    }

    // MARK: - Rankings (computed on-device from players + player_weekly_stats)

    private static let fantasyPositions = ["QB", "RB", "WR", "TE"]

    /// Fetch fantasy-relevant, active QB/RB/WR/TE ranked by a relevance score
    /// computed on-device from the EXISTING tables (`players` +
    /// `player_weekly_stats`) — no SQL view or RPC required.
    /// - When `search` is empty, only players with production in the latest
    ///   season are returned, sorted by relevance.
    /// - When `search` is set, the full eligible active-player pool is searched
    ///   (even players without stats), so any active QB/RB/WR/TE is findable.
    func fetchRankedPlayers(
        positions: [String]? = nil,
        search: String? = nil,
        limit: Int = 300
    ) async throws -> [RankedPlayer] {
        let term = (search ?? "").trimmingCharacters(in: .whitespaces)
        let requested = (positions?.isEmpty == false) ? Set(positions!) : Set(Self.fantasyPositions)

        // 1) Latest season that actually has weekly stats.
        let latestSeason = try await latestStatsSeason()

        // 2) Eligible active fantasy players (QB/RB/WR/TE, real team). Two `team`
        //    filters are AND-ed by PostgREST.
        var playerQuery: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "id,sleeper_id,full_name,position,team,age,height,weight"),
            URLQueryItem(name: "active", value: "eq.true"),
            URLQueryItem(name: "team", value: "not.is.null"),
            URLQueryItem(name: "team", value: "neq.FA"),
            URLQueryItem(name: "position", value: "in.(\(Self.fantasyPositions.joined(separator: ",")))"),
            URLQueryItem(name: "order", value: "id.asc"),
        ]
        if !term.isEmpty {
            playerQuery.append(URLQueryItem(name: "full_name", value: "ilike.*\(term)*"))
        }
        let players: [RankPlayerRow] = try await getAllPages(table: "players", query: playerQuery)

        // 3) Aggregate latest-season weekly stats per player.
        var totals: [String: (ppr: Double, games: Int, usage: Double)] = [:]
        if let season = latestSeason {
            let stats: [RankWeeklyRow] = try await getAllPages(
                table: "player_weekly_stats",
                query: [
                    URLQueryItem(name: "select", value: "id,player_id,fantasy_points_ppr,rushing_attempts,targets,receptions"),
                    URLQueryItem(name: "season", value: "eq.\(season)"),
                    URLQueryItem(name: "order", value: "id.asc"),
                ]
            )
            for s in stats {
                guard let pid = s.playerId else { continue }
                var t = totals[pid] ?? (0, 0, 0)
                t.ppr += s.fantasyPointsPpr ?? 0
                t.games += 1
                t.usage += (s.rushingAttempts ?? 0) + (s.targets ?? 0) + (s.receptions ?? 0)
                totals[pid] = t
            }
        }

        // 4) Combine, normalize across the pool, and score.
        struct Scored { let p: RankPlayerRow; let ppr: Double; let games: Int; let ppg: Double; let usage: Double }
        let combined: [Scored] = players.map { p in
            let t = totals[p.id] ?? (0, 0, 0)
            return Scored(p: p, ppr: t.ppr, games: t.games, ppg: t.games > 0 ? t.ppr / Double(t.games) : 0, usage: t.usage)
        }
        let maxPpr = combined.map(\.ppr).max() ?? 0
        let maxPpg = combined.map(\.ppg).max() ?? 0
        let maxGames = Double(combined.map(\.games).max() ?? 0)
        let maxUsage = combined.map(\.usage).max() ?? 0
        func norm(_ value: Double, _ maxValue: Double) -> Double { maxValue > 0 ? value / maxValue : 0 }

        var ranked: [RankedPlayer] = combined.map { s in
            let score = (0.5 * norm(s.ppr, maxPpr)
                + 0.2 * norm(s.ppg, maxPpg)
                + 0.1 * norm(Double(s.games), maxGames)
                + 0.1 * norm(s.usage, maxUsage)
                + 0.1) * 100
            return RankedPlayer(
                playerId: s.p.id,
                sleeperId: s.p.sleeperId,
                fullName: s.p.fullName ?? "",
                position: s.p.position,
                team: s.p.team,
                age: s.p.age,
                height: s.p.height,
                weight: s.p.weight,
                latestSeason: latestSeason,
                totalFantasyPointsPpr: (s.ppr * 10).rounded() / 10,
                gamesPlayed: s.games,
                fantasyPointsPerGame: (s.ppg * 10).rounded() / 10,
                recentUsage: s.usage,
                relevanceScore: (score * 100).rounded() / 100
            )
        }

        // 5) Apply the requested position filter, then the default-pool rule.
        if requested.count != Self.fantasyPositions.count {
            ranked = ranked.filter { requested.contains(($0.position ?? "").uppercased()) }
        }
        if term.isEmpty {
            ranked = ranked.filter { ($0.gamesPlayed ?? 0) > 0 }
        }
        ranked.sort { ($0.relevanceScore ?? 0) > ($1.relevanceScore ?? 0) }
        return Array(ranked.prefix(limit))
    }

    /// The most recent season that has any weekly stats.
    private func latestStatsSeason() async throws -> Int? {
        let rows: [RankSeasonRow] = try await get(
            table: "player_weekly_stats",
            query: [
                URLQueryItem(name: "select", value: "season"),
                URLQueryItem(name: "order", value: "season.desc"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        return rows.first?.season
    }

    // MARK: - Detail data (keyed by the player's uuid `player_id`)

    /// Weekly box scores for a player, newest first (used for season totals +
    /// recent games). Empty if the table isn't populated yet.
    func fetchWeeklyStats(playerId: String, limit: Int = 40) async throws -> [SupabaseWeeklyStat] {
        try await optionalTable(
            table: "player_weekly_stats",
            query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "player_id", value: "eq.\(playerId)"),
                URLQueryItem(name: "order", value: "season.desc,week.desc"),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        )
    }

    /// Advanced usage metrics for a player, newest first.
    func fetchAdvancedStats(playerId: String, limit: Int = 40) async throws -> [AdvancedStat] {
        try await optionalTable(
            table: "player_advanced_stats",
            query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "player_id", value: "eq.\(playerId)"),
                URLQueryItem(name: "order", value: "season.desc,week.desc"),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        )
    }

    /// Next scheduled games for a team, ordered by kickoff. Empty if the `games`
    /// table isn't populated yet (UI shows "coming soon" rather than fabricating).
    func fetchUpcomingGames(team: String, limit: Int = 5) async throws -> [SupabaseGame] {
        guard !team.isEmpty else { return [] }
        return try await optionalTable(
            table: "games",
            query: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "or", value: "(home_team.eq.\(team),away_team.eq.\(team))"),
                URLQueryItem(name: "status", value: "eq.scheduled"),
                URLQueryItem(name: "order", value: "kickoff_at.asc.nullslast"),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        )
    }

    // MARK: - Teams

    func fetchTeams() async throws -> [SupabaseTeam] {
        let query = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "name.asc"),
        ]
        return try await get(table: "teams", query: query)
    }

    // MARK: - Transport

    /// Query a table that may not exist yet. A 404 (table not found) is treated
    /// as "no data" (empty) so optional features degrade to a "coming soon"
    /// state instead of surfacing an error.
    private func optionalTable<Element: Decodable>(
        table: String,
        query: [URLQueryItem]
    ) async throws -> [Element] {
        do {
            return try await get(table: table, query: query)
        } catch let error as ServiceError {
            if case .http(let status, _, _) = error, status == 404 { return [] }
            throw error
        }
    }

    /// Fetch every row of a query by paging past Supabase's per-request row cap
    /// (1000). Requires a stable `order` in `query` for correct paging.
    private func getAllPages<Element: Decodable>(
        table: String,
        query: [URLQueryItem],
        pageSize: Int = 1000,
        maxPages: Int = 60
    ) async throws -> [Element] {
        var all: [Element] = []
        var offset = 0
        for _ in 0..<maxPages {
            var paged = query
            paged.append(URLQueryItem(name: "limit", value: String(pageSize)))
            paged.append(URLQueryItem(name: "offset", value: String(offset)))
            let page: [Element] = try await get(table: table, query: paged)
            all.append(contentsOf: page)
            if page.count < pageSize { break }
            offset += pageSize
        }
        return all
    }

    private func get<T: Decodable>(table: String, query: [URLQueryItem]) async throws -> T {
        guard SupabaseConfig.isConfigured, let restURL = SupabaseConfig.restURL else {
            throw ServiceError.notConfigured
        }
        guard var comps = URLComponents(
            url: restURL.appendingPathComponent(table),
            resolvingAgainstBaseURL: false
        ) else {
            throw ServiceError.badURL
        }
        comps.queryItems = query
        guard let url = comps.url else { throw ServiceError.badURL }

        #if DEBUG
        print("➡️ Supabase GET table=\(table) path=/rest/v1/\(table) url=\(url.absoluteString)")
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let key = SupabaseConfig.anonKey
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ServiceError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            #if DEBUG
            print("❌ Supabase HTTP \(http.statusCode) for resource=\(table)\n   body=\(body.prefix(300))")
            #endif
            throw ServiceError.http(status: http.statusCode, resource: table, body: body)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ServiceError.decoding(error)
        }
    }
}

// MARK: - Lightweight decode rows for client-side ranking aggregation

private struct RankPlayerRow: Decodable {
    let id: String
    let sleeperId: String?
    let fullName: String?
    let position: String?
    let team: String?
    let age: Int?
    let height: String?
    let weight: String?

    enum CodingKeys: String, CodingKey {
        case id, position, team, age, height, weight
        case sleeperId = "sleeper_id"
        case fullName = "full_name"
    }
}

private struct RankWeeklyRow: Decodable {
    let playerId: String?
    let fantasyPointsPpr: Double?
    let rushingAttempts: Double?
    let targets: Double?
    let receptions: Double?

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case fantasyPointsPpr = "fantasy_points_ppr"
        case rushingAttempts = "rushing_attempts"
        case targets, receptions
    }
}

private struct RankSeasonRow: Decodable { let season: Int? }
