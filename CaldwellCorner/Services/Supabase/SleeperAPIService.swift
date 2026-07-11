import Foundation

// MARK: - Sleeper models (read-only public API)

struct SleeperUser: Codable, Hashable {
    let userId: String
    let username: String?
    let displayName: String?
    let avatar: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case avatar
    }

    var avatarURL: URL? {
        guard let avatar, !avatar.isEmpty else { return nil }
        return URL(string: "https://sleepercdn.com/avatars/thumbs/\(avatar)")
    }
}

struct SleeperNFLState: Codable {
    let season: String?
    let leagueSeason: String?
    let previousSeason: String?

    enum CodingKeys: String, CodingKey {
        case season
        case leagueSeason = "league_season"
        case previousSeason = "previous_season"
    }
}

struct SleeperLeague: Codable, Identifiable, Hashable {
    let leagueId: String
    let name: String?
    let season: String?
    let totalRosters: Int?
    let status: String?
    let scoringSettings: [String: Double]?
    let rosterPositions: [String]?

    var id: String { leagueId }

    /// Human-readable scoring format derived from the reception value.
    var scoringFormat: String {
        let rec = scoringSettings?["rec"] ?? 0
        if rec >= 1 { return "PPR" }
        if rec >= 0.5 { return "Half PPR" }
        return "Standard"
    }

    enum CodingKeys: String, CodingKey {
        case leagueId = "league_id"
        case name
        case season
        case totalRosters = "total_rosters"
        case status
        case scoringSettings = "scoring_settings"
        case rosterPositions = "roster_positions"
    }
}

struct SleeperLeagueUser: Codable, Hashable {
    let userId: String
    let displayName: String?
    let metadata: Meta?

    struct Meta: Codable, Hashable {
        let teamName: String?
        enum CodingKeys: String, CodingKey { case teamName = "team_name" }
    }

    var teamName: String? { metadata?.teamName ?? displayName }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case metadata
    }
}

struct SleeperRoster: Codable, Identifiable, Hashable {
    let rosterId: Int
    let ownerId: String?
    let players: [String]?
    let starters: [String]?
    let reserve: [String]?
    let taxi: [String]?

    var id: Int { rosterId }

    enum CodingKeys: String, CodingKey {
        case rosterId = "roster_id"
        case ownerId = "owner_id"
        case players
        case starters
        case reserve
        case taxi
    }
}

// MARK: - Service

/// Read-only client for Sleeper's public API (no key, no password/email). Docs:
/// https://docs.sleeper.com/
actor SleeperAPIService {
    static let shared = SleeperAPIService()

    private let base = "https://api.sleeper.app/v1"
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) { self.session = session }

    enum SleeperError: LocalizedError {
        case userNotFound
        case noLeagues
        case http(Int)
        case transport(Error)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .userNotFound: return "That Sleeper username wasn't found. Check the spelling and try again."
            case .noLeagues: return "No NFL leagues found for this Sleeper account this season."
            case .http(let code): return "Sleeper request failed (HTTP \(code))."
            case .transport(let e): return "Network error: \(e.localizedDescription)"
            case .decoding: return "Sleeper returned data in an unexpected format."
            }
        }
    }

    /// GET /user/{username}
    func fetchUser(username: String) async throws -> SleeperUser {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else { throw SleeperError.userNotFound }
        // Sleeper returns `null` for an unknown username.
        guard let user: SleeperUser = try await getOptional("/user/\(encoded)") else {
            throw SleeperError.userNotFound
        }
        return user
    }

    /// Current + previous NFL season (offseason falls back to previous).
    func fetchState() async throws -> SleeperNFLState {
        try await get("/state/nfl")
    }

    /// GET /user/{user_id}/leagues/nfl/{season}
    func fetchLeagues(userId: String, season: String) async throws -> [SleeperLeague] {
        try await get("/user/\(userId)/leagues/nfl/\(season)")
    }

    /// GET /league/{league_id}/users
    func fetchLeagueUsers(leagueId: String) async throws -> [SleeperLeagueUser] {
        try await get("/league/\(leagueId)/users")
    }

    /// GET /league/{league_id}/rosters
    func fetchRosters(leagueId: String) async throws -> [SleeperRoster] {
        try await get("/league/\(leagueId)/rosters")
    }

    // MARK: Transport

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let value: T = try await getOptional(path) else {
            throw SleeperError.decoding(NSError(domain: "Sleeper", code: -1))
        }
        return value
    }

    private func getOptional<T: Decodable>(_ path: String) async throws -> T? {
        guard let url = URL(string: base + path) else { throw SleeperError.http(-1) }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw SleeperError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if http.statusCode == 404 { return nil }
            throw SleeperError.http(http.statusCode)
        }
        // Sleeper sends the literal `null` for empty results.
        if data.isEmpty || String(data: data, encoding: .utf8) == "null" { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw SleeperError.decoding(error)
        }
    }
}
