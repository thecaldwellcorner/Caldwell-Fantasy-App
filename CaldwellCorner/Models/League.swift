import Foundation

enum LeaguePlatform: String, CaseIterable, Codable, Identifiable {
    case sleeper = "Sleeper"
    case espn = "ESPN"
    case yahoo = "Yahoo"
    case nfl = "NFL Fantasy"
    case cbs = "CBS"
    case fleaflicker = "Fleaflicker"
    case mfl = "MFL"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .sleeper: return "moon.stars.fill"
        case .espn: return "sportscourt.fill"
        case .yahoo: return "y.circle.fill"
        case .nfl: return "football.fill"
        case .cbs: return "tv.fill"
        case .fleaflicker: return "ant.fill"
        case .mfl: return "list.bullet.rectangle.fill"
        }
    }
}

enum ScoringFormat: String, CaseIterable, Codable, Identifiable {
    case ppr = "PPR"
    case halfPPR = "Half PPR"
    case standard = "Standard"
    var id: String { rawValue }
}

enum LeagueType: String, CaseIterable, Codable, Identifiable {
    case redraft = "Redraft"
    case dynasty = "Dynasty"
    case keeper = "Keeper"
    case bestBall = "Best Ball"
    var id: String { rawValue }
}

struct RosterSlot: Identifiable, Codable, Hashable {
    let id: UUID
    var playerID: UUID
    var slot: String          // "QB", "RB", "FLEX", "BENCH", "IR", "TAXI"
    init(id: UUID = UUID(), playerID: UUID, slot: String) {
        self.id = id; self.playerID = playerID; self.slot = slot
    }
}

struct FantasyTeam: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var ownerName: String
    var wins: Int
    var losses: Int
    var pointsFor: Double
    var pointsAgainst: Double
    var powerScore: Double          // 0...100
    var playoffOdds: Double         // 0...100
    var championshipOdds: Double    // 0...100
    var dynastyValue: Double        // 0...100
    var isUser: Bool
    var roster: [RosterSlot]
    var futurePicks: [String]       // e.g. "2026 1st"

    init(id: UUID = UUID(), name: String, ownerName: String, wins: Int, losses: Int,
         pointsFor: Double, pointsAgainst: Double, powerScore: Double, playoffOdds: Double,
         championshipOdds: Double, dynastyValue: Double, isUser: Bool = false,
         roster: [RosterSlot] = [], futurePicks: [String] = []) {
        self.id = id; self.name = name; self.ownerName = ownerName
        self.wins = wins; self.losses = losses
        self.pointsFor = pointsFor; self.pointsAgainst = pointsAgainst
        self.powerScore = powerScore; self.playoffOdds = playoffOdds
        self.championshipOdds = championshipOdds; self.dynastyValue = dynastyValue
        self.isUser = isUser; self.roster = roster; self.futurePicks = futurePicks
    }
}

struct League: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var platform: LeaguePlatform
    var scoring: ScoringFormat
    var type: LeagueType
    var teamCount: Int
    var isSuperflex: Bool
    var teams: [FantasyTeam]
    var currentWeek: Int

    init(id: UUID = UUID(), name: String, platform: LeaguePlatform, scoring: ScoringFormat,
         type: LeagueType, teamCount: Int, isSuperflex: Bool, teams: [FantasyTeam],
         currentWeek: Int = 6) {
        self.id = id; self.name = name; self.platform = platform; self.scoring = scoring
        self.type = type; self.teamCount = teamCount; self.isSuperflex = isSuperflex
        self.teams = teams; self.currentWeek = currentWeek
    }

    var userTeam: FantasyTeam? { teams.first(where: { $0.isUser }) }
    var standings: [FantasyTeam] {
        teams.sorted { ($0.wins, $0.pointsFor) > ($1.wins, $1.pointsFor) }
    }
}
