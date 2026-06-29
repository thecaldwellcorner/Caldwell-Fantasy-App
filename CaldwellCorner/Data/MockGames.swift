import Foundation

enum MockGames {
    private static func team(_ abbr: String, _ name: String, _ rec: String, _ hex: UInt, _ score: Int = 0) -> GameTeam {
        GameTeam(abbr: abbr, name: name, record: rec, colorHex: hex, score: score)
    }

    static var all: [NFLGame] { build() }

    static func build() -> [NFLGame] {
        let now = Date()

        // ---- LIVE: CIN @ BAL ----
        let cinBal = NFLGame(
            home: team("BAL", "Ravens", "5-2", 0x241773, 17),
            away: team("CIN", "Bengals", "4-3", 0xFB4F14, 14),
            status: .live, quarter: 3, clockSeconds: 512, possession: .away, isRedZone: true,
            down: 2, distance: 6, yardLine: "BAL 14", kickoff: now.addingTimeInterval(-7200),
            scoringPlays: [
                ScoringPlay(quarter: 1, clock: "8:42", teamAbbr: "CIN", kind: "TD", detail: "Ja'Marr Chase 24 yd pass from Joe Burrow", awayScore: 7, homeScore: 0),
                ScoringPlay(quarter: 2, clock: "3:10", teamAbbr: "BAL", kind: "TD", detail: "Derrick Henry 3 yd run", awayScore: 7, homeScore: 7),
                ScoringPlay(quarter: 2, clock: "0:32", teamAbbr: "BAL", kind: "FG", detail: "Justin Tucker 41 yd field goal", awayScore: 7, homeScore: 10),
                ScoringPlay(quarter: 3, clock: "9:58", teamAbbr: "CIN", kind: "TD", detail: "Chase Brown 6 yd run", awayScore: 14, homeScore: 10),
                ScoringPlay(quarter: 3, clock: "6:20", teamAbbr: "BAL", kind: "TD", detail: "Mark Andrews 12 yd pass from Lamar Jackson", awayScore: 14, homeScore: 17),
            ],
            plays: [
                GamePlay(quarter: 3, clock: "6:05", teamAbbr: "CIN", text: "J.Burrow pass complete to T.Higgins for 18 yards.", isBig: true),
                GamePlay(quarter: 3, clock: "5:40", teamAbbr: "CIN", text: "C.Brown rush for 7 yards."),
            ],
            stats: [
                PlayerGameStat(name: "Joe Burrow", position: .qb, teamAbbr: "CIN", group: .passing, projection: 22.5, passYds: 245, passTD: 1, completions: 19, attempts: 27),
                PlayerGameStat(name: "Ja'Marr Chase", position: .wr, teamAbbr: "CIN", group: .receiving, isUserPlayer: true, projection: 20.1, receptions: 7, recYds: 96, recTD: 1, targets: 10),
                PlayerGameStat(name: "Lamar Jackson", position: .qb, teamAbbr: "BAL", group: .passing, projection: 24.0, passYds: 188, passTD: 1, rushYds: 47, completions: 14, attempts: 21),
                PlayerGameStat(name: "Derrick Henry", position: .rb, teamAbbr: "BAL", group: .rushing, isUserPlayer: true, projection: 18.0, rushYds: 84, rushTD: 1, carries: 16),
                PlayerGameStat(name: "Mark Andrews", position: .te, teamAbbr: "BAL", group: .receiving, projection: 11.5, receptions: 4, recYds: 41, recTD: 1, targets: 6),
            ])

        // ---- LIVE: DET @ GB ----
        let detGb = NFLGame(
            home: team("GB", "Packers", "5-2", 0x203731, 20),
            away: team("DET", "Lions", "6-1", 0x0076B6, 27),
            status: .live, quarter: 4, clockSeconds: 433, possession: .home, isRedZone: false,
            down: 1, distance: 10, yardLine: "GB 35", kickoff: now.addingTimeInterval(-8000),
            scoringPlays: [
                ScoringPlay(quarter: 2, clock: "11:20", teamAbbr: "DET", kind: "TD", detail: "Jahmyr Gibbs 18 yd run", awayScore: 7, homeScore: 0),
                ScoringPlay(quarter: 2, clock: "4:02", teamAbbr: "GB", kind: "TD", detail: "Josh Jacobs 2 yd run", awayScore: 7, homeScore: 7),
                ScoringPlay(quarter: 3, clock: "7:45", teamAbbr: "DET", kind: "TD", detail: "Amon-Ra St. Brown 9 yd pass from Jared Goff", awayScore: 14, homeScore: 7),
                ScoringPlay(quarter: 3, clock: "2:11", teamAbbr: "DET", kind: "FG", detail: "Jake Bates 38 yd field goal", awayScore: 17, homeScore: 7),
                ScoringPlay(quarter: 4, clock: "12:30", teamAbbr: "GB", kind: "TD", detail: "Jayden Reed 22 yd pass from Jordan Love", awayScore: 17, homeScore: 14),
                ScoringPlay(quarter: 4, clock: "9:15", teamAbbr: "DET", kind: "TD", detail: "Jahmyr Gibbs 4 yd run", awayScore: 24, homeScore: 14),
                ScoringPlay(quarter: 4, clock: "8:40", teamAbbr: "GB", kind: "FG", detail: "Brandon McManus 45 yd field goal", awayScore: 24, homeScore: 17),
                ScoringPlay(quarter: 4, clock: "7:33", teamAbbr: "DET", kind: "FG", detail: "Jake Bates 29 yd field goal", awayScore: 27, homeScore: 17),
                ScoringPlay(quarter: 4, clock: "7:25", teamAbbr: "GB", kind: "FG", detail: "Brandon McManus 52 yd field goal", awayScore: 27, homeScore: 20),
            ],
            plays: [
                GamePlay(quarter: 4, clock: "7:13", teamAbbr: "GB", text: "J.Love pass complete to C.Watson for 31 yards.", isBig: true),
            ],
            stats: [
                PlayerGameStat(name: "Jared Goff", position: .qb, teamAbbr: "DET", group: .passing, projection: 19.5, passYds: 268, passTD: 1, completions: 22, attempts: 30),
                PlayerGameStat(name: "Jahmyr Gibbs", position: .rb, teamAbbr: "DET", group: .rushing, isUserPlayer: true, projection: 17.8, rushYds: 96, rushTD: 2, carries: 17, receptions: 3, recYds: 24),
                PlayerGameStat(name: "Amon-Ra St. Brown", position: .wr, teamAbbr: "DET", group: .receiving, isUserPlayer: true, projection: 18.0, receptions: 8, recYds: 79, recTD: 1, targets: 10),
                PlayerGameStat(name: "Jordan Love", position: .qb, teamAbbr: "GB", group: .passing, projection: 18.5, passYds: 231, passTD: 2, completions: 18, attempts: 29),
                PlayerGameStat(name: "Josh Jacobs", position: .rb, teamAbbr: "GB", group: .rushing, projection: 16.0, rushYds: 71, rushTD: 1, carries: 15),
            ])

        // ---- LIVE: SF @ SEA ----
        let sfSea = NFLGame(
            home: team("SEA", "Seahawks", "4-3", 0x002244, 10),
            away: team("SF", "49ers", "3-4", 0xAA0000, 13),
            status: .live, quarter: 2, clockSeconds: 247, possession: .away, isRedZone: false,
            down: 3, distance: 4, yardLine: "SF 48", kickoff: now.addingTimeInterval(-5400),
            scoringPlays: [
                ScoringPlay(quarter: 1, clock: "5:30", teamAbbr: "SF", kind: "FG", detail: "Jake Moody 47 yd field goal", awayScore: 3, homeScore: 0),
                ScoringPlay(quarter: 1, clock: "1:12", teamAbbr: "SEA", kind: "TD", detail: "Kenneth Walker III 11 yd run", awayScore: 3, homeScore: 7),
                ScoringPlay(quarter: 2, clock: "8:05", teamAbbr: "SF", kind: "TD", detail: "George Kittle 14 yd pass from Brock Purdy", awayScore: 10, homeScore: 7),
                ScoringPlay(quarter: 2, clock: "5:48", teamAbbr: "SEA", kind: "FG", detail: "Jason Myers 33 yd field goal", awayScore: 10, homeScore: 10),
                ScoringPlay(quarter: 2, clock: "3:01", teamAbbr: "SF", kind: "FG", detail: "Jake Moody 25 yd field goal", awayScore: 13, homeScore: 10),
            ],
            plays: [
                GamePlay(quarter: 2, clock: "2:55", teamAbbr: "SF", text: "B.Purdy pass complete to D.Samuel for 12 yards."),
            ],
            stats: [
                PlayerGameStat(name: "Brock Purdy", position: .qb, teamAbbr: "SF", group: .passing, projection: 18.0, passYds: 161, passTD: 1, completions: 13, attempts: 19),
                PlayerGameStat(name: "George Kittle", position: .te, teamAbbr: "SF", group: .receiving, isUserPlayer: true, projection: 13.0, receptions: 4, recYds: 58, recTD: 1, targets: 5),
                PlayerGameStat(name: "Geno Smith", position: .qb, teamAbbr: "SEA", group: .passing, projection: 17.5, passYds: 142, completions: 12, attempts: 18),
                PlayerGameStat(name: "Kenneth Walker III", position: .rb, teamAbbr: "SEA", group: .rushing, projection: 15.5, rushYds: 52, rushTD: 1, carries: 11),
            ])

        // ---- UPCOMING ----
        let kcBuf = NFLGame(
            home: team("BUF", "Bills", "5-2", 0x00338D),
            away: team("KC", "Chiefs", "6-1", 0xE31837),
            status: .pregame, kickoff: now.addingTimeInterval(2 * 3600),
            stats: [
                PlayerGameStat(name: "Josh Allen", position: .qb, teamAbbr: "BUF", group: .passing, isUserPlayer: true, projection: 24.8),
                PlayerGameStat(name: "Patrick Mahomes", position: .qb, teamAbbr: "KC", group: .passing, projection: 23.5),
            ])
        let dalPhi = NFLGame(
            home: team("PHI", "Eagles", "5-2", 0x004C54),
            away: team("DAL", "Cowboys", "3-4", 0x041E42),
            status: .pregame, kickoff: now.addingTimeInterval(5 * 3600),
            stats: [
                PlayerGameStat(name: "Saquon Barkley", position: .rb, teamAbbr: "PHI", group: .rushing, projection: 18.5),
                PlayerGameStat(name: "CeeDee Lamb", position: .wr, teamAbbr: "DAL", group: .receiving, isUserPlayer: true, projection: 19.1),
            ])

        // ---- FINAL ----
        let miaNyj = NFLGame(
            home: team("NYJ", "Jets", "3-4", 0x125740, 17),
            away: team("MIA", "Dolphins", "4-3", 0x008E97, 24),
            status: .final, quarter: 4, clockSeconds: 0, kickoff: now.addingTimeInterval(-3 * 3600),
            scoringPlays: [
                ScoringPlay(quarter: 4, clock: "1:55", teamAbbr: "MIA", kind: "TD", detail: "De'Von Achane 8 yd run", awayScore: 24, homeScore: 17),
            ],
            stats: [
                PlayerGameStat(name: "De'Von Achane", position: .rb, teamAbbr: "MIA", group: .rushing, isUserPlayer: true, projection: 16.5, rushYds: 102, rushTD: 1, carries: 18, receptions: 5, recYds: 41),
                PlayerGameStat(name: "Tyreek Hill", position: .wr, teamAbbr: "MIA", group: .receiving, projection: 19.8, receptions: 6, recYds: 88, targets: 9),
            ])
        let atlCar = NFLGame(
            home: team("CAR", "Panthers", "1-6", 0x0085CA, 13),
            away: team("ATL", "Falcons", "5-2", 0xA71930, 30),
            status: .final, quarter: 4, clockSeconds: 0, kickoff: now.addingTimeInterval(-3 * 3600),
            scoringPlays: [
                ScoringPlay(quarter: 4, clock: "4:20", teamAbbr: "ATL", kind: "TD", detail: "Bijan Robinson 12 yd run", awayScore: 30, homeScore: 13),
            ],
            stats: [
                PlayerGameStat(name: "Bijan Robinson", position: .rb, teamAbbr: "ATL", group: .rushing, isUserPlayer: true, projection: 18.9, rushYds: 128, rushTD: 1, carries: 22, receptions: 4, recYds: 33),
                PlayerGameStat(name: "Drake London", position: .wr, teamAbbr: "ATL", group: .receiving, projection: 15.4, receptions: 7, recYds: 91, recTD: 1, targets: 9),
            ])

        return [cinBal, detGb, sfSea, kcBuf, dalPhi, miaNyj, atlCar]
    }
}
