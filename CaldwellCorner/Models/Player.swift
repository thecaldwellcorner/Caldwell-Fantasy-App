import Foundation

enum Position: String, CaseIterable, Codable, Identifiable {
    case qb = "QB"
    case rb = "RB"
    case wr = "WR"
    case te = "TE"
    case k = "K"
    case def = "DEF"
    var id: String { rawValue }
}

enum InjuryStatus: String, Codable {
    case healthy = "Healthy"
    case questionable = "Questionable"
    case doubtful = "Doubtful"
    case out = "Out"
    case ir = "IR"

    var isConcern: Bool { self != .healthy }
}

/// Advanced metrics surfaced in the Player Database (per PRD §4).
struct AdvancedMetrics: Codable, Hashable {
    var snapPct: Double          // 0...100
    var targetShare: Double      // 0...100
    var routeParticipation: Double
    var yardsPerRouteRun: Double
    var targetsPerRouteRun: Double
    var redZoneShare: Double
    var epaPerPlay: Double
    var successRate: Double
    var expectedPoints: Double
    var ras: Double              // Relative Athletic Score 0...10
    var breakoutAge: Double
    var collegeDominator: Double // 0...100
}

struct Player: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var position: Position
    var team: String            // NFL team abbreviation
    var age: Int
    var college: String
    var draftCapital: String    // e.g. "Rd 1, Pick 8 (2022)"
    var byeWeek: Int
    var injuryStatus: InjuryStatus

    // Rankings / values
    var overallRank: Int
    var positionRank: Int
    var adp: Double             // average draft position
    var redraftValue: Double    // 0...100
    var dynastyValue: Double    // 0...100
    var keeperValue: Double     // 0...100
    var rankTrend: Double       // weekly movement (+/-)

    // Projections
    var projWeekly: Double
    var projSeason: Double
    var projRestOfSeason: Double
    var ceiling: Double
    var floor: Double
    var breakoutProbability: Double  // 0...100
    var regressionProbability: Double
    var bustProbability: Double

    // Season stats summary
    var fantasyPointsPPR: Double
    var gamesPlayed: Int

    var metrics: AdvancedMetrics
    var blurb: String

    init(id: UUID = UUID(), name: String, position: Position, team: String, age: Int,
         college: String, draftCapital: String, byeWeek: Int,
         injuryStatus: InjuryStatus = .healthy, overallRank: Int, positionRank: Int,
         adp: Double, redraftValue: Double, dynastyValue: Double, keeperValue: Double,
         rankTrend: Double, projWeekly: Double, projSeason: Double, projRestOfSeason: Double,
         ceiling: Double, floor: Double, breakoutProbability: Double,
         regressionProbability: Double, bustProbability: Double, fantasyPointsPPR: Double,
         gamesPlayed: Int, metrics: AdvancedMetrics, blurb: String) {
        self.id = id
        self.name = name
        self.position = position
        self.team = team
        self.age = age
        self.college = college
        self.draftCapital = draftCapital
        self.byeWeek = byeWeek
        self.injuryStatus = injuryStatus
        self.overallRank = overallRank
        self.positionRank = positionRank
        self.adp = adp
        self.redraftValue = redraftValue
        self.dynastyValue = dynastyValue
        self.keeperValue = keeperValue
        self.rankTrend = rankTrend
        self.projWeekly = projWeekly
        self.projSeason = projSeason
        self.projRestOfSeason = projRestOfSeason
        self.ceiling = ceiling
        self.floor = floor
        self.breakoutProbability = breakoutProbability
        self.regressionProbability = regressionProbability
        self.bustProbability = bustProbability
        self.fantasyPointsPPR = fantasyPointsPPR
        self.gamesPlayed = gamesPlayed
        self.metrics = metrics
        self.blurb = blurb
    }
}
