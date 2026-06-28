import Foundation

/// Async client for the Caldwell Corner backend (Node/TypeScript service).
///
/// The backend ingests trusted data (Sleeper public API + nflverse / nflfastR
/// datasets), stores normalized `PlayerMetrics`, and runs the AI
/// `RecommendationEngine`. This client lets the iOS app consume those metrics
/// and recommendations instead of computing them on-device.
///
/// Configure the base URL via the `CC_BACKEND_URL` environment variable /
/// Info.plist, or pass one explicitly. Defaults to a local dev server.
actor BackendClient {
    static let shared = BackendClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        let envURL = ProcessInfo.processInfo.environment["CC_BACKEND_URL"]
            .flatMap(URL.init(string:))
        self.baseURL = baseURL ?? envURL ?? URL(string: "http://localhost:8080")!
        self.session = session
        self.decoder = JSONDecoder()
    }

    enum BackendError: Error { case badResponse(Int), decoding(Error), transport(Error) }

    // MARK: - Player metrics
    func players(season: Int? = nil, week: Int = 0,
                 position: Position? = nil, limit: Int? = nil) async throws -> [PlayerMetrics] {
        var items = [URLQueryItem(name: "week", value: String(week))]
        if let season { items.append(.init(name: "season", value: String(season))) }
        if let position { items.append(.init(name: "position", value: position.rawValue)) }
        if let limit { items.append(.init(name: "limit", value: String(limit))) }
        let res: PlayersResponse = try await get("/api/players", query: items)
        return res.players
    }

    func metrics(for playerId: String, season: Int? = nil, week: Int = 0) async throws -> PlayerMetrics {
        var items = [URLQueryItem(name: "week", value: String(week))]
        if let season { items.append(.init(name: "season", value: String(season))) }
        let res: SinglePlayerResponse = try await get("/api/players/\(playerId)", query: items)
        return res.player
    }

    // MARK: - Recommendations
    func startSit(playerIds: [String], league: BackendLeagueSettings,
                  season: Int? = nil, week: Int = 0) async throws -> [BackendStartSitRecommendation] {
        let body = StartSitRequest(league: league, playerIds: playerIds, season: season, week: week)
        let res: StartSitResponse = try await post("/api/recommendations/start-sit", body: body)
        return res.recommendations
    }

    func waivers(league: BackendLeagueSettings, season: Int? = nil, week: Int = 0) async throws -> [BackendWaiverRecommendation] {
        let body = LeagueRequest(league: league, season: season, week: week)
        let res: WaiverResponse = try await post("/api/recommendations/waiver", body: body)
        return res.recommendations
    }

    func draft(league: BackendLeagueSettings, season: Int? = nil, week: Int = 0) async throws -> [BackendDraftRecommendation] {
        let body = LeagueRequest(league: league, season: season, week: week)
        let res: DraftResponse = try await post("/api/recommendations/draft", body: body)
        return res.recommendations
    }

    func trade(give: [String], get: [String], league: BackendLeagueSettings,
               season: Int? = nil, week: Int = 0) async throws -> BackendTradeRecommendation {
        let body = TradeRequest(league: league, give: give, get: get, season: season, week: week)
        let res: TradeResponse = try await post("/api/recommendations/trade", body: body)
        return res.recommendation
    }

    // MARK: - Transport
    private func get<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query
        var request = URLRequest(url: comps.url!)
        request.httpMethod = "GET"
        return try await send(request)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BackendError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw BackendError.badResponse(http.statusCode)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw BackendError.decoding(error)
        }
    }
}

// MARK: - Request / response envelopes
private struct PlayersResponse: Decodable { let players: [PlayerMetrics] }
private struct SinglePlayerResponse: Decodable { let player: PlayerMetrics }
private struct StartSitResponse: Decodable { let recommendations: [BackendStartSitRecommendation] }
private struct WaiverResponse: Decodable { let recommendations: [BackendWaiverRecommendation] }
private struct DraftResponse: Decodable { let recommendations: [BackendDraftRecommendation] }
private struct TradeResponse: Decodable { let recommendation: BackendTradeRecommendation }

private struct LeagueRequest: Encodable {
    let league: BackendLeagueSettings
    let season: Int?
    let week: Int
}
private struct StartSitRequest: Encodable {
    let league: BackendLeagueSettings
    let playerIds: [String]
    let season: Int?
    let week: Int
}
private struct TradeRequest: Encodable {
    let league: BackendLeagueSettings
    let give: [String]
    let get: [String]
    let season: Int?
    let week: Int
}
