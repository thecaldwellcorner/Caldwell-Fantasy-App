import Foundation

/// Mirror of the backend `PlayerMetrics` model (Sleeper + nflverse sourced,
/// stored server-side and served via the backend API). Reuses the app's
/// existing `Position` / `InjuryStatus` enums so it slots into the UI directly.
struct PlayerMetrics: Codable, Identifiable, Hashable {
    var playerId: String
    var name: String
    var position: Position
    var team: String
    var age: Int?

    var season: Int
    var week: Int

    // Usage / opportunity
    var targetShare: Double
    var airYards: Double
    var routesRun: Double
    var snapShare: Double
    var redZoneUsage: Double

    // Context
    var epaTeamContext: Double
    var matchupDifficulty: Double
    var injuryStatus: InjuryStatus

    // Derived outputs
    var projectedPoints: Double
    var regressionScore: Double
    var breakoutScore: Double
    var confidenceScore: Double

    var updatedAt: String

    var id: String { "\(playerId)-\(season)-\(week)" }
}

/// League settings payload sent to the backend recommendation endpoints.
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

    /// Build a payload from an in-app `League`.
    init(from league: League) {
        switch league.scoring {
        case .ppr: scoring = "ppr"
        case .halfPPR: scoring = "half_ppr"
        case .standard: scoring = "standard"
        }
        teamCount = league.teamCount
        superflex = league.isSuperflex
        dynasty = league.type == .dynasty || league.type == .keeper
        rosterSlots = ["QB": league.isSuperflex ? 1 : 1, "RB": 2, "WR": 2, "TE": 1, "FLEX": 1]
        if league.isSuperflex { rosterSlots["SUPERFLEX"] = 1 }
        faabBudget = 100
    }
}

// MARK: - Recommendation responses (mirror backend types)
struct StartSitRecommendation: Codable, Identifiable, Hashable {
    var playerId: String
    var name: String
    var position: Position
    var verdict: String          // "Start" | "Flex" | "Sit"
    var projectedPoints: Double
    var score: Double
    var confidence: Double
    var reasoning: String
    var id: String { playerId }
}

struct WaiverRecommendation: Codable, Identifiable, Hashable {
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

struct DraftRecommendation: Codable, Identifiable, Hashable {
    var playerId: String
    var name: String
    var position: Position
    var valueOverReplacement: Double
    var score: Double
    var confidence: Double
    var reasoning: String
    var id: String { playerId }
}

struct TradeRecommendation: Codable, Hashable {
    var verdict: String          // "Accept" | "Fair" | "Decline"
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
