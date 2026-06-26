import Foundation

// MARK: - News
struct NewsItem: Identifiable, Codable, Hashable {
    let id: UUID
    var headline: String
    var source: String
    var timestamp: Date
    var playerName: String?
    var position: Position?
    var aiSummary: String
    var fantasyImpact: String      // "Stock Up" / "Stock Down" / "Neutral"
    var isBreaking: Bool

    init(id: UUID = UUID(), headline: String, source: String, timestamp: Date,
         playerName: String? = nil, position: Position? = nil, aiSummary: String,
         fantasyImpact: String, isBreaking: Bool = false) {
        self.id = id; self.headline = headline; self.source = source
        self.timestamp = timestamp; self.playerName = playerName; self.position = position
        self.aiSummary = aiSummary; self.fantasyImpact = fantasyImpact; self.isBreaking = isBreaking
    }
}

// MARK: - Injury
struct InjuryReport: Identifiable, Codable, Hashable {
    let id: UUID
    var playerName: String
    var position: Position
    var team: String
    var status: InjuryStatus
    var injury: String
    var practiceReport: String     // "DNP" / "Limited" / "Full"
    var expectedReturn: String
    var fantasyImpact: String
    var replacementSuggestion: String

    init(id: UUID = UUID(), playerName: String, position: Position, team: String,
         status: InjuryStatus, injury: String, practiceReport: String,
         expectedReturn: String, fantasyImpact: String, replacementSuggestion: String) {
        self.id = id; self.playerName = playerName; self.position = position; self.team = team
        self.status = status; self.injury = injury; self.practiceReport = practiceReport
        self.expectedReturn = expectedReturn; self.fantasyImpact = fantasyImpact
        self.replacementSuggestion = replacementSuggestion
    }
}

// MARK: - Waiver target
struct WaiverTarget: Identifiable, Codable, Hashable {
    let id: UUID
    var playerName: String
    var position: Position
    var team: String
    var rosteredPct: Double        // 0...100
    var faabBidPct: Int            // suggested % of budget
    var priority: Int
    var reason: String
    var isPremium: Bool

    init(id: UUID = UUID(), playerName: String, position: Position, team: String,
         rosteredPct: Double, faabBidPct: Int, priority: Int, reason: String,
         isPremium: Bool = false) {
        self.id = id; self.playerName = playerName; self.position = position; self.team = team
        self.rosteredPct = rosteredPct; self.faabBidPct = faabBidPct; self.priority = priority
        self.reason = reason; self.isPremium = isPremium
    }
}

// MARK: - Start/Sit
struct StartSitAdvice: Identifiable, Codable, Hashable {
    let id: UUID
    var playerName: String
    var position: Position
    var team: String
    var opponent: String
    var recommendation: String     // "Start" / "Sit" / "Flex"
    var confidence: Double         // 0...100
    var projection: Double
    var matchupGrade: String       // "A".."F"
    var vegasTotal: Double
    var weather: String
    var reasoning: String

    init(id: UUID = UUID(), playerName: String, position: Position, team: String,
         opponent: String, recommendation: String, confidence: Double, projection: Double,
         matchupGrade: String, vegasTotal: Double, weather: String, reasoning: String) {
        self.id = id; self.playerName = playerName; self.position = position; self.team = team
        self.opponent = opponent; self.recommendation = recommendation
        self.confidence = confidence; self.projection = projection
        self.matchupGrade = matchupGrade; self.vegasTotal = vegasTotal
        self.weather = weather; self.reasoning = reasoning
    }
}

// MARK: - Betting
struct BettingProp: Identifiable, Codable, Hashable {
    let id: UUID
    var playerName: String
    var position: Position
    var market: String             // "Receiving Yards", "Anytime TD"...
    var line: Double
    var overOdds: Int
    var underOdds: Int
    var aiPick: String             // "Over" / "Under"
    var expectedValue: Double      // % EV
    var confidence: Double
    var sportsbook: String

    init(id: UUID = UUID(), playerName: String, position: Position, market: String,
         line: Double, overOdds: Int, underOdds: Int, aiPick: String,
         expectedValue: Double, confidence: Double, sportsbook: String) {
        self.id = id; self.playerName = playerName; self.position = position; self.market = market
        self.line = line; self.overOdds = overOdds; self.underOdds = underOdds
        self.aiPick = aiPick; self.expectedValue = expectedValue
        self.confidence = confidence; self.sportsbook = sportsbook
    }
}

// MARK: - Draft Guide
struct DraftGuideArticle: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var category: String           // "Sleepers", "Busts", "Breakouts", "Strategy"...
    var author: String
    var readMinutes: Int
    var body: String
    var isPremium: Bool

    init(id: UUID = UUID(), title: String, category: String, author: String,
         readMinutes: Int, body: String, isPremium: Bool = true) {
        self.id = id; self.title = title; self.category = category; self.author = author
        self.readMinutes = readMinutes; self.body = body; self.isPremium = isPremium
    }
}

// MARK: - Premium content
struct PremiumContent: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var type: String               // "Article", "Film", "Video", "Livestream"
    var author: String
    var publishedAt: Date
    var summary: String

    init(id: UUID = UUID(), title: String, type: String, author: String,
         publishedAt: Date, summary: String) {
        self.id = id; self.title = title; self.type = type; self.author = author
        self.publishedAt = publishedAt; self.summary = summary
    }
}

// MARK: - Rookie / Draft pick value (Dynasty hub)
struct RookieProspect: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var position: Position
    var college: String
    var rookieRank: Int
    var projectedDraftCapital: String
    var dynastyValue: Double
    var comp: String               // pro comparison

    init(id: UUID = UUID(), name: String, position: Position, college: String,
         rookieRank: Int, projectedDraftCapital: String, dynastyValue: Double, comp: String) {
        self.id = id; self.name = name; self.position = position; self.college = college
        self.rookieRank = rookieRank; self.projectedDraftCapital = projectedDraftCapital
        self.dynastyValue = dynastyValue; self.comp = comp
    }
}

struct DraftPickValue: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String              // "2026 1st (Early)"
    var value: Double              // KTC-style points
    init(id: UUID = UUID(), label: String, value: Double) {
        self.id = id; self.label = label; self.value = value
    }
}
