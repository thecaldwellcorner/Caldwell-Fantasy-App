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
        case http(Int)
        case transport(Error)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase isn't configured. Add your project URL and anon key in SupabaseConfig."
            case .badURL:
                return "Could not build a valid Supabase request URL."
            case .http(let code):
                return "Supabase request failed (HTTP \(code))."
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

    // MARK: - Rankings (the `player_rankings` view)

    /// Fetch fantasy-relevant, active QB/RB/WR/TE ranked by relevance score.
    /// - When `search` is empty, only players with production this season are
    ///   returned (games_played > 0), sorted by relevance.
    /// - When `search` is set, the full eligible active-player pool is searched
    ///   (even players without stats), so any active QB/RB/WR/TE is findable.
    func fetchRankedPlayers(
        positions: [String]? = nil,
        search: String? = nil,
        limit: Int = 300
    ) async throws -> [RankedPlayer] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: "relevance_score.desc.nullslast"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let positions, !positions.isEmpty {
            query.append(URLQueryItem(name: "position", value: "in.(\(positions.joined(separator: ",")))"))
        }
        let term = (search ?? "").trimmingCharacters(in: .whitespaces)
        if term.isEmpty {
            query.append(URLQueryItem(name: "games_played", value: "gt.0"))
        } else {
            query.append(URLQueryItem(name: "full_name", value: "ilike.*\(term)*"))
        }
        return try await get(table: "player_rankings", query: query)
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
            if case .http(let code) = error, code == 404 { return [] }
            throw error
        }
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
            throw ServiceError.http(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ServiceError.decoding(error)
        }
    }
}
