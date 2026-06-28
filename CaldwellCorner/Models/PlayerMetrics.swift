import Foundation

/// Canonical advanced-analytics model for a player at a point in time.
///
/// Every field is sourced from trusted providers (Sleeper + nflverse / nflfastR)
/// and normalized server-side. The app's `CaldwellEngine` scores players using
/// only these stored metrics, and the AI assistant only explains that output —
/// it never invents stats. `dataLastUpdated` / `dataSources` / `hasCurrentData`
/// power the guardrails.
struct PlayerMetrics: Codable, Identifiable, Hashable {
    var playerId: String
    var name: String
    var position: Position
    var team: String
    var age: Int?
    var season: Int
    var week: Int

    // MARK: Receiving usage
    var targetShare: Double          // 0…1
    var targetsPerRouteRun: Double   // TPRR
    var yardsPerRouteRun: Double     // YPRR
    var routeParticipation: Double   // 0…1
    var airYardsShare: Double        // 0…1
    var firstReadShare: Double       // 0…1
    var redZoneTargets: Int
    var endZoneTargets: Int

    // MARK: Rushing usage
    var rushShare: Double            // 0…1
    var goalLineShare: Double        // 0…1
    var explosivePlayRate: Double    // 0…1
    var missedTacklesForced: Int
    var yardsAfterContact: Double    // per attempt

    // MARK: Production / efficiency
    var expectedFantasyPoints: Double
    var fantasyPointsOverExpected: Double
    var snapShare: Double            // 0…1

    // MARK: Availability
    var injuryStatus: InjuryStatus

    // MARK: Team context
    var teamPassRateOverExpected: Double  // PROE, percentage points
    var teamEPAperPlay: Double
    var offensiveLineRank: Int            // 1 (best) … 32

    // MARK: Game environment
    var impliedTeamTotal: Double
    var spread: Double                    // negative = favored
    var matchupEPAAllowed: Double         // EPA/play opponent allows vs position (higher = easier)
    var scheduleDifficulty: Double        // 0 (easy) … 100 (hard)

    // MARK: Derived model scores
    var regressionScore: Double           // 0…100 (higher = more regression risk)
    var breakoutScore: Double             // 0…100
    var confidenceScore: Double           // 0…100 (data quality / sample)

    // MARK: Provenance & guardrails
    var dataLastUpdated: Date
    var dataSources: [String]
    /// False when metrics are stale or unavailable; the engine refuses to score it.
    var hasCurrentData: Bool

    var id: String { "\(playerId)-\(season)-\(week)" }

    /// True when the metrics are too old to be considered "current".
    var isStale: Bool {
        Date().timeIntervalSince(dataLastUpdated) > 7 * 24 * 3600
    }
}

// MARK: - Resilient decoding
// Defined in an extension so the synthesized memberwise initializer is preserved
// for local construction, while tolerating partial backend payloads.
extension PlayerMetrics {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func d(_ k: CodingKeys, _ fallback: Double) -> Double { (try? c.decode(Double.self, forKey: k)) ?? fallback }
        func i(_ k: CodingKeys, _ fallback: Int) -> Int { (try? c.decode(Int.self, forKey: k)) ?? fallback }

        playerId = (try? c.decode(String.self, forKey: .playerId)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? "Unknown"
        position = (try? c.decode(Position.self, forKey: .position)) ?? .wr
        team = (try? c.decode(String.self, forKey: .team)) ?? "FA"
        age = try? c.decode(Int.self, forKey: .age)
        season = i(.season, 0)
        week = i(.week, 0)

        targetShare = d(.targetShare, 0)
        targetsPerRouteRun = d(.targetsPerRouteRun, 0)
        yardsPerRouteRun = d(.yardsPerRouteRun, 0)
        routeParticipation = d(.routeParticipation, 0)
        airYardsShare = d(.airYardsShare, 0)
        firstReadShare = d(.firstReadShare, 0)
        redZoneTargets = i(.redZoneTargets, 0)
        endZoneTargets = i(.endZoneTargets, 0)

        rushShare = d(.rushShare, 0)
        goalLineShare = d(.goalLineShare, 0)
        explosivePlayRate = d(.explosivePlayRate, 0)
        missedTacklesForced = i(.missedTacklesForced, 0)
        yardsAfterContact = d(.yardsAfterContact, 0)

        expectedFantasyPoints = d(.expectedFantasyPoints, 0)
        fantasyPointsOverExpected = d(.fantasyPointsOverExpected, 0)
        snapShare = d(.snapShare, 0)

        injuryStatus = (try? c.decode(InjuryStatus.self, forKey: .injuryStatus)) ?? .healthy

        teamPassRateOverExpected = d(.teamPassRateOverExpected, 0)
        teamEPAperPlay = d(.teamEPAperPlay, 0)
        offensiveLineRank = i(.offensiveLineRank, 16)

        impliedTeamTotal = d(.impliedTeamTotal, 22)
        spread = d(.spread, 0)
        matchupEPAAllowed = d(.matchupEPAAllowed, 0)
        scheduleDifficulty = d(.scheduleDifficulty, 50)

        regressionScore = d(.regressionScore, 50)
        breakoutScore = d(.breakoutScore, 50)
        confidenceScore = d(.confidenceScore, 50)

        if let date = try? c.decode(Date.self, forKey: .dataLastUpdated) {
            dataLastUpdated = date
        } else if let iso = try? c.decode(String.self, forKey: .dataLastUpdated),
                  let parsed = ISO8601DateFormatter().date(from: iso) {
            dataLastUpdated = parsed
        } else {
            dataLastUpdated = Date()
        }
        dataSources = (try? c.decode([String].self, forKey: .dataSources)) ?? []
        hasCurrentData = (try? c.decode(Bool.self, forKey: .hasCurrentData)) ?? true
    }
}

// MARK: - Backend league settings payload (for the optional BackendClient)
struct BackendLeagueSettings: Codable, Hashable {
    var scoring: String          // "ppr" | "half_ppr" | "standard"
    var teamCount: Int
    var superflex: Bool
    var dynasty: Bool
    var rosterSlots: [String: Int]
    var faabBudget: Int

    static let standardPPR = BackendLeagueSettings(
        scoring: "ppr", teamCount: 12, superflex: false, dynasty: false,
        rosterSlots: ["QB": 1, "RB": 2, "WR": 2, "TE": 1, "FLEX": 1], faabBudget: 100)

    init(scoring: String, teamCount: Int, superflex: Bool, dynasty: Bool,
         rosterSlots: [String: Int], faabBudget: Int) {
        self.scoring = scoring; self.teamCount = teamCount; self.superflex = superflex
        self.dynasty = dynasty; self.rosterSlots = rosterSlots; self.faabBudget = faabBudget
    }

    init(from league: League) {
        switch league.scoring {
        case .ppr: scoring = "ppr"
        case .halfPPR: scoring = "half_ppr"
        case .standard: scoring = "standard"
        }
        teamCount = league.teamCount
        superflex = league.isSuperflex
        dynasty = league.type == .dynasty || league.type == .keeper
        rosterSlots = ["QB": 1, "RB": 2, "WR": 2, "TE": 1, "FLEX": 1]
        if league.isSuperflex { rosterSlots["SUPERFLEX"] = 1 }
        faabBudget = 100
    }
}

// MARK: - Backend recommendation responses (for the optional BackendClient)
struct BackendStartSitRecommendation: Codable, Identifiable, Hashable {
    var playerId: String
    var name: String
    var position: Position
    var verdict: String
    var projectedPoints: Double
    var score: Double
    var confidence: Double
    var reasoning: String
    var id: String { playerId }
}

struct BackendWaiverRecommendation: Codable, Identifiable, Hashable {
    var playerId: String
    var name: String
    var position: Position
    var priority: Int
    var faabBidPct: Double
    var score: Double
    var confidence: Double
    var reasoning: String
    var id: String { playerId }
}

struct BackendDraftRecommendation: Codable, Identifiable, Hashable {
    var playerId: String
    var name: String
    var position: Position
    var valueOverReplacement: Double
    var score: Double
    var confidence: Double
    var reasoning: String
    var id: String { playerId }
}

struct BackendTradeRecommendation: Codable, Hashable {
    var verdict: String
    var tradeGrade: Double
    var fairnessScore: Double
    var winNowScore: Double
    var futureScore: Double
    var riskRating: String
    var sideAValue: Double
    var sideBValue: Double
    var score: Double
    var confidence: Double
    var reasoning: String
}
