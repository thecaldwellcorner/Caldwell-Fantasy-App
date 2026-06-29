import Foundation

enum GameStatus: String, Codable, Hashable {
    case pregame, live, final
}

enum GameSide: String, Codable, Hashable {
    case home, away
}

struct GameTeam: Codable, Hashable {
    var abbr: String
    var name: String
    var record: String
    var colorHex: UInt
    var score: Int
}

enum StatGroup: String, Codable, Hashable {
    case passing = "Passing"
    case rushing = "Rushing"
    case receiving = "Receiving"
}

struct PlayerGameStat: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var position: Position
    var teamAbbr: String
    var group: StatGroup
    var isUserPlayer: Bool
    var projection: Double

    // Live counting stats
    var passYds: Int = 0
    var passTD: Int = 0
    var interceptions: Int = 0
    var rushYds: Int = 0
    var rushTD: Int = 0
    var receptions: Int = 0
    var recYds: Int = 0
    var recTD: Int = 0
    var carries: Int = 0
    var targets: Int = 0
    var completions: Int = 0
    var attempts: Int = 0

    init(id: UUID = UUID(), name: String, position: Position, teamAbbr: String,
         group: StatGroup, isUserPlayer: Bool = false, projection: Double,
         passYds: Int = 0, passTD: Int = 0, interceptions: Int = 0,
         rushYds: Int = 0, rushTD: Int = 0, carries: Int = 0,
         receptions: Int = 0, recYds: Int = 0, recTD: Int = 0, targets: Int = 0,
         completions: Int = 0, attempts: Int = 0) {
        self.id = id; self.name = name; self.position = position; self.teamAbbr = teamAbbr
        self.group = group; self.isUserPlayer = isUserPlayer; self.projection = projection
        self.passYds = passYds; self.passTD = passTD; self.interceptions = interceptions
        self.rushYds = rushYds; self.rushTD = rushTD; self.receptions = receptions
        self.recYds = recYds; self.recTD = recTD; self.carries = carries; self.targets = targets
        self.completions = completions; self.attempts = attempts
    }

    /// PPR fantasy points from the live line.
    var fantasyPoints: Double {
        let pts = Double(passYds) * 0.04 + Double(passTD) * 4 - Double(interceptions) * 2
            + Double(rushYds) * 0.1 + Double(rushTD) * 6
            + Double(receptions) * 1 + Double(recYds) * 0.1 + Double(recTD) * 6
        return (pts * 10).rounded() / 10
    }

    var statLine: String {
        switch group {
        case .passing:
            return "\(completions)/\(attempts), \(passYds) yds, \(passTD) TD\(interceptions > 0 ? ", \(interceptions) INT" : "")"
        case .rushing:
            return "\(carries) car, \(rushYds) yds\(rushTD > 0 ? ", \(rushTD) TD" : "")"
        case .receiving:
            return "\(receptions) rec, \(recYds) yds\(recTD > 0 ? ", \(recTD) TD" : "") (\(targets) tgt)"
        }
    }
}

struct ScoringPlay: Identifiable, Codable, Hashable {
    let id: UUID
    var quarter: Int
    var clock: String
    var teamAbbr: String
    var kind: String          // "TD", "FG", "Safety"
    var detail: String
    var awayScore: Int
    var homeScore: Int

    init(id: UUID = UUID(), quarter: Int, clock: String, teamAbbr: String, kind: String,
         detail: String, awayScore: Int, homeScore: Int) {
        self.id = id; self.quarter = quarter; self.clock = clock; self.teamAbbr = teamAbbr
        self.kind = kind; self.detail = detail; self.awayScore = awayScore; self.homeScore = homeScore
    }
}

struct GamePlay: Identifiable, Codable, Hashable {
    let id: UUID
    var quarter: Int
    var clock: String
    var teamAbbr: String
    var text: String
    var isScoring: Bool
    var isBig: Bool

    init(id: UUID = UUID(), quarter: Int, clock: String, teamAbbr: String, text: String,
         isScoring: Bool = false, isBig: Bool = false) {
        self.id = id; self.quarter = quarter; self.clock = clock; self.teamAbbr = teamAbbr
        self.text = text; self.isScoring = isScoring; self.isBig = isBig
    }
}

struct NFLGame: Identifiable, Codable, Hashable {
    let id: UUID
    var home: GameTeam
    var away: GameTeam
    var status: GameStatus
    var quarter: Int           // 1...4, 5 = OT
    var clockSeconds: Int      // remaining in the quarter
    var possession: GameSide?
    var isRedZone: Bool
    var down: Int
    var distance: Int
    var yardLine: String
    var kickoff: Date
    var scoringPlays: [ScoringPlay]
    var plays: [GamePlay]
    var stats: [PlayerGameStat]

    init(id: UUID = UUID(), home: GameTeam, away: GameTeam, status: GameStatus,
         quarter: Int = 1, clockSeconds: Int = 900, possession: GameSide? = nil,
         isRedZone: Bool = false, down: Int = 1, distance: Int = 10, yardLine: String = "",
         kickoff: Date, scoringPlays: [ScoringPlay] = [], plays: [GamePlay] = [],
         stats: [PlayerGameStat] = []) {
        self.id = id; self.home = home; self.away = away; self.status = status
        self.quarter = quarter; self.clockSeconds = clockSeconds; self.possession = possession
        self.isRedZone = isRedZone; self.down = down; self.distance = distance
        self.yardLine = yardLine; self.kickoff = kickoff; self.scoringPlays = scoringPlays
        self.plays = plays; self.stats = stats
    }

    var clockLabel: String {
        let m = clockSeconds / 60
        let s = clockSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var periodLabel: String {
        switch status {
        case .final: return quarter > 4 ? "FINAL/OT" : "FINAL"
        case .pregame:
            let f = DateFormatter(); f.dateFormat = "EEE h:mm a"
            return f.string(from: kickoff)
        case .live:
            if clockSeconds == 0 && quarter == 2 { return "HALF" }
            return quarter > 4 ? "OT" : "Q\(quarter)"
        }
    }

    var downDistanceLabel: String? {
        guard status == .live, possession != nil else { return nil }
        let ord = ["", "1st", "2nd", "3rd", "4th"]
        let d = down >= 1 && down <= 4 ? ord[down] : "\(down)th"
        return "\(d) & \(distance) · \(yardLine)"
    }

    func team(_ side: GameSide) -> GameTeam { side == .home ? home : away }
}
