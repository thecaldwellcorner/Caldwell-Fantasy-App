import Foundation
import Combine

/// Drives the Live Game Center. A single shared timer advances only in-progress
/// games, so cost scales with live games (not total). The timer runs only while
/// at least one view is subscribed (ref-counted), which keeps it efficient and
/// avoids background work when the user leaves the feature.
final class GameCenterStore: ObservableObject {
    @Published private(set) var games: [NFLGame]

    private var timer: AnyCancellable?
    private var viewers = 0
    private var tickCount = 0

    init(games: [NFLGame] = MockGames.build()) {
        self.games = games
    }

    // MARK: - Accessors
    func game(_ id: UUID) -> NFLGame? { games.first { $0.id == id } }
    var liveGames: [NFLGame] { games.filter { $0.status == .live } }
    var upcomingGames: [NFLGame] { games.filter { $0.status == .pregame }.sorted { $0.kickoff < $1.kickoff } }
    var finalGames: [NFLGame] { games.filter { $0.status == .final } }
    var hasLiveGames: Bool { games.contains { $0.status == .live } }

    /// Fantasy players the user is tracking across all games (matchup tracking).
    var userPlayersAcrossGames: [(game: NFLGame, stat: PlayerGameStat)] {
        games.flatMap { g in g.stats.filter { $0.isUserPlayer }.map { (g, $0) } }
            .sorted { $0.stat.fantasyPoints > $1.stat.fantasyPoints }
    }

    // MARK: - Lifecycle (ref-counted)
    func subscribe() {
        viewers += 1
        ensureRunning()
    }

    func unsubscribe() {
        viewers = max(0, viewers - 1)
        if viewers == 0 {
            timer?.cancel()
            timer = nil
        }
    }

    private func ensureRunning() {
        guard timer == nil, hasLiveGames else { return }
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    // MARK: - Simulation
    private func tick() {
        tickCount += 1
        let heavy = tickCount % 3 == 0   // generate plays/scores every ~3s
        var updated = games
        var anyLive = false
        for i in updated.indices where updated[i].status == .live {
            anyLive = true
            advance(&updated[i], heavy: heavy)
        }
        games = updated
        if !anyLive { timer?.cancel(); timer = nil }
    }

    private func advance(_ game: inout NFLGame, heavy: Bool) {
        // Clock
        let step = Int.random(in: 12...28)
        game.clockSeconds -= step
        if game.clockSeconds <= 0 {
            if game.quarter >= 4 {
                game.clockSeconds = 0
                game.status = .final
                game.possession = nil
                game.isRedZone = false
                game.plays.insert(GamePlay(quarter: game.quarter, clock: "0:00",
                    teamAbbr: "", text: "End of game. Final score.", isBig: true), at: 0)
                return
            } else {
                game.quarter += 1
                game.clockSeconds = 900
                game.plays.insert(GamePlay(quarter: game.quarter, clock: "15:00",
                    teamAbbr: "", text: "Start of Q\(game.quarter)."), at: 0)
            }
        }

        guard heavy else { return }

        let offense: GameSide = game.possession ?? .away
        let team = game.team(offense)
        let clock = game.clockLabel
        let roll = Int.random(in: 0...100)

        if roll < 14 {
            // Scoring play
            let isTD = Int.random(in: 0...100) < 62
            if isTD {
                if offense == .home { game.home.score += 7 } else { game.away.score += 7 }
                let scorer = randomSkill(in: game, team: team.abbr)
                let detail = scorer.map { "\($0.name) touchdown" } ?? "\(team.abbr) touchdown"
                addScore(&game, team: team.abbr, kind: "TD", detail: detail, clock: clock)
                if let s = scorer { bumpTD(&game, playerID: s.id) }
            } else {
                if offense == .home { game.home.score += 3 } else { game.away.score += 3 }
                addScore(&game, team: team.abbr, kind: "FG", detail: "\(team.abbr) field goal", clock: clock)
            }
            game.possession = offense == .home ? .away : .home
            game.isRedZone = false
            game.down = 1; game.distance = 10; game.yardLine = "\(game.team(game.possession!).abbr) 25"
        } else if roll < 30 {
            // Turnover / punt → flip possession
            let next: GameSide = offense == .home ? .away : .home
            game.possession = next
            game.isRedZone = false
            game.down = 1; game.distance = 10; game.yardLine = "\(game.team(next).abbr) 30"
            game.plays.insert(GamePlay(quarter: game.quarter, clock: clock, teamAbbr: team.abbr,
                text: Bool.random() ? "\(team.abbr) punts." : "Turnover on downs."), at: 0)
        } else {
            // Regular gain
            let gain = Int.random(in: -2...24)
            let big = gain >= 18
            game.down = gain >= game.distance ? 1 : min(4, game.down + 1)
            game.distance = gain >= game.distance ? 10 : max(1, game.distance - gain)
            let yl = Int.random(in: 5...49)
            game.isRedZone = yl <= 20 && Bool.random()
            game.yardLine = "\(Bool.random() ? game.home.abbr : game.away.abbr) \(yl)"
            if let p = randomSkill(in: game, team: team.abbr) {
                bumpYards(&game, playerID: p.id, yards: max(0, gain))
                let verb = p.group == .rushing ? "rush for \(max(0, gain)) yards" : "reception for \(max(0, gain)) yards"
                game.plays.insert(GamePlay(quarter: game.quarter, clock: clock, teamAbbr: team.abbr,
                    text: "\(p.name) \(verb).", isBig: big), at: 0)
            }
        }

        if game.plays.count > 40 { game.plays = Array(game.plays.prefix(40)) }
    }

    private func addScore(_ game: inout NFLGame, team: String, kind: String, detail: String, clock: String) {
        game.scoringPlays.append(ScoringPlay(quarter: game.quarter, clock: clock, teamAbbr: team,
            kind: kind, detail: detail, awayScore: game.away.score, homeScore: game.home.score))
        game.plays.insert(GamePlay(quarter: game.quarter, clock: clock, teamAbbr: team,
            text: "\(kind): \(detail)", isScoring: true, isBig: true), at: 0)
    }

    private func randomSkill(in game: NFLGame, team: String) -> PlayerGameStat? {
        game.stats.filter { $0.teamAbbr == team && $0.group != .passing }.randomElement()
            ?? game.stats.filter { $0.teamAbbr == team }.randomElement()
    }

    private func bumpYards(_ game: inout NFLGame, playerID: UUID, yards: Int) {
        guard let i = game.stats.firstIndex(where: { $0.id == playerID }) else { return }
        switch game.stats[i].group {
        case .rushing:
            game.stats[i].rushYds += yards; game.stats[i].carries += 1
        case .receiving:
            game.stats[i].recYds += yards; game.stats[i].receptions += 1; game.stats[i].targets += 1
        case .passing:
            game.stats[i].passYds += yards
        }
        // Credit the QB on the same team for passing yards on receptions.
        if game.stats[i].group == .receiving,
           let qb = game.stats.firstIndex(where: { $0.teamAbbr == game.stats[i].teamAbbr && $0.group == .passing }) {
            game.stats[qb].passYds += yards
            game.stats[qb].completions += 1
            game.stats[qb].attempts += 1
        }
    }

    private func bumpTD(_ game: inout NFLGame, playerID: UUID) {
        guard let i = game.stats.firstIndex(where: { $0.id == playerID }) else { return }
        switch game.stats[i].group {
        case .rushing: game.stats[i].rushTD += 1
        case .receiving:
            game.stats[i].recTD += 1
            if let qb = game.stats.firstIndex(where: { $0.teamAbbr == game.stats[i].teamAbbr && $0.group == .passing }) {
                game.stats[qb].passTD += 1
            }
        case .passing: game.stats[i].passTD += 1
        }
    }
}
