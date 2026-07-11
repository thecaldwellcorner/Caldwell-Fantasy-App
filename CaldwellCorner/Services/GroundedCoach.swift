import Foundation

/// Data-grounded AI Coach. Resolves the players a user mentions, pulls their
/// REAL data from Supabase (players, player_weekly_stats, player_advanced_stats,
/// games, player_projections), and produces a structured `AssistantAnswer` that
/// cites only retrieved data plus clearly-labeled football reasoning.
///
/// It never invents stats, injuries, projections, rankings, opponents or trends.
/// When data is missing it says so and lowers confidence. No secret keys are
/// used — reads go through the publishable key via `SupabaseService`.
actor GroundedCoach {
    static let shared = GroundedCoach()

    private let service: SupabaseService
    init(service: SupabaseService = .shared) { self.service = service }

    // MARK: Public entry point

    func answer(to question: String) async -> AssistantAnswer {
        let players = await resolvePlayers(in: question)
        #if DEBUG
        print("🧠 Coach entities detected: \(players.map(\.displayName))")
        #endif

        if players.isEmpty {
            return notIdentified(question)
        }
        if players.count > 3 {
            return ambiguous(players)
        }

        let intent = classify(question, playerCount: players.count)
        #if DEBUG
        print("🧠 Coach intent: \(intent)")
        #endif

        switch intent {
        case .trade where players.count >= 2:
            let a = await context(players[0])
            let b = await context(players[1])
            return tradeAnswer(a, b)
        case .startSit where players.count >= 2:
            let a = await context(players[0])
            let b = await context(players[1])
            return startSitAnswer(a, b)
        default:
            let c = await context(players[0])
            return profileAnswer(c)
        }
    }

    // MARK: Intent

    private enum Intent { case startSit, trade, profile }

    private func classify(_ q: String, playerCount: Int) -> Intent {
        let lower = q.lowercased()
        if lower.contains("trade") { return .trade }
        if playerCount >= 2 { return .startSit }  // "start X or Y", "X or Y", "better: X or Y"
        return .profile
    }

    // MARK: Entity resolution (tolerant of partial names)

    private static let stopWords: Set<String> = [
        "start", "sit", "or", "the", "a", "an", "better", "trade", "who", "is", "how",
        "has", "played", "playing", "recently", "what", "this", "player", "next", "matchup",
        "at", "vs", "should", "i", "my", "for", "with", "and", "to", "of", "in", "on",
        "week", "this", "asset", "value", "between", "them", "him", "best", "worse", "worst",
        "would", "you", "do", "does", "get", "add", "drop", "pick", "up", "against",
    ]

    private func resolvePlayers(in question: String) async -> [RankedPlayer] {
        let cleaned = question.replacingOccurrences(of: "[^A-Za-z .'-]", with: " ", options: .regularExpression)
        let tokens = cleaned.split(separator: " ").map(String.init)
            .filter { $0.count >= 2 && !Self.stopWords.contains($0.lowercased()) }

        var found: [String: RankedPlayer] = [:]
        var order: [String] = []
        func add(_ r: RankedPlayer) {
            if found[r.playerId] == nil { order.append(r.playerId) }
            found[r.playerId] = r
        }
        func nameContainsPhrase(_ full: String, _ phrase: String) -> Bool {
            full.lowercased().contains(phrase.lowercased())
        }
        func nameHasWord(_ full: String, _ word: String) -> Bool {
            full.lowercased().split(separator: " ").map(String.init).contains(word.lowercased())
        }

        // 1) Full-name bigrams (e.g. "Josh Jacobs") — specific, low false-positive.
        var bigrams: [String] = []
        if tokens.count >= 2 {
            for i in 0..<(tokens.count - 1) { bigrams.append("\(tokens[i]) \(tokens[i + 1])") }
        }
        for phrase in dedupe(bigrams).prefix(6) {
            #if DEBUG
            print("🔎 Coach query players ilike '\(phrase)'")
            #endif
            guard let rows = try? await service.findPlayers(nameLike: phrase, limit: 6) else { continue }
            for r in rows where nameContainsPhrase(r.fullName, phrase) { add(r) }
        }

        // 2) Single last-name tokens NOT already covered by a bigram match.
        var consumed = Set<String>()
        for p in found.values {
            for w in p.fullName.lowercased().split(separator: " ") { consumed.insert(String(w)) }
        }
        let singles = tokens.filter { $0.count >= 4 && !consumed.contains($0.lowercased()) }
        for token in dedupe(singles).prefix(4) {
            #if DEBUG
            print("🔎 Coach query players ilike '\(token)' (single)")
            #endif
            guard let rows = try? await service.findPlayers(nameLike: token, limit: 6) else { continue }
            for r in rows where nameHasWord(r.fullName, token) { add(r) }
        }

        return order.compactMap { found[$0] }
    }

    private func dedupe(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0.lowercased()).inserted }
    }

    // MARK: Player context (real data only)

    private struct Context {
        let player: RankedPlayer
        let season: Int?
        let seasonRows: [SupabaseWeeklyStat]   // week > 0, latest season, newest first
        let advanced: [AdvancedStat]
        let nextGame: SupabaseGame?
        let hasProjections: Bool
        let dataUpdated: Date?

        var games: Int { seasonRows.count }
        var totalPPR: Double { seasonRows.reduce(0) { $0 + ($1.fantasyPointsPpr ?? 0) } }
        var ppg: Double? { games > 0 ? totalPPR / Double(games) : nil }
        var recent: [SupabaseWeeklyStat] { Array(seasonRows.prefix(5)) }
        var recentAvg: Double? {
            let s = recent.compactMap { $0.fantasyPointsPpr }
            return s.isEmpty ? nil : s.reduce(0, +) / Double(s.count)
        }
        /// Season value used for comparisons; falls back to recent form.
        var value: Double? { ppg ?? recentAvg }
        var position: String { (player.position ?? "").uppercased() }
    }

    private func context(_ p: RankedPlayer) async -> Context {
        async let weeklyF = try? service.fetchWeeklyStats(playerId: p.playerId)
        async let advancedF = try? service.fetchAdvancedStats(playerId: p.playerId)
        async let scheduleF = try? service.fetchUpcomingGames(team: p.team ?? "", limit: 1)
        async let projF = service.hasProjections(playerId: p.playerId)

        let weekly = (await weeklyF) ?? []
        let advanced = (await advancedF) ?? []
        let schedule = (await scheduleF) ?? []
        let hasProj = await projF

        let season = weekly.compactMap(\.season).max()
        let seasonRows = weekly
            .filter { $0.season == season && ($0.week ?? 0) > 0 }
            .sorted { ($0.week ?? 0) > ($1.week ?? 0) }
        let advSeason = advanced.filter { $0.season == season }
        let updated = weekly.compactMap { parseDate($0.updatedAt) }.max()

        #if DEBUG
        print("📦 Coach context \(p.displayName): season=\(season.map(String.init) ?? "—") games=\(seasonRows.count) adv=\(advSeason.count) proj=\(hasProj)")
        #endif

        return Context(
            player: p, season: season, seasonRows: seasonRows, advanced: advSeason,
            nextGame: schedule.first, hasProjections: hasProj, dataUpdated: updated
        )
    }

    // MARK: Answers

    private func profileAnswer(_ c: Context) -> AssistantAnswer {
        guard c.games > 0 else {
            return .unavailable(
                for: c.player.displayName,
                warnings: ["No weekly stats found for \(c.player.displayName) in the stored data."]
            )
        }
        let name = c.player.displayName
        let metrics = playerMetrics(c)
        let warnings = missing(c)
        let conf = confidence(for: [c])

        let recentLine = c.recent.compactMap { $0.fantasyPointsPpr }.prefix(3)
            .map { String(format: "%.1f", $0) }.joined(separator: ", ")
        let oppLine = nextOpponentText(c)
        let explanation =
            "Grounded in stored \(c.season.map(String.init) ?? "") data: \(name) (\(c.position), \(c.player.team ?? "FA")) "
            + "has \(c.games) games, \(fmt(c.totalPPR)) total PPR, \(fmt(c.ppg)) PPG. "
            + "Last games (PPR): \(recentLine.isEmpty ? "—" : recentLine). "
            + oppLine
            + " Confidence: \(conf.label) — based on available data completeness."

        return AssistantAnswer(
            finalCall: "\(name) — \(c.position) · \(c.player.team ?? "FA")",
            verdictTag: c.position,
            dataAvailable: true,
            confidence: conf.score,
            dataLastUpdated: c.dataUpdated,
            modelScore: c.ppg.map { min(100, $0 * 4) },
            keyMetrics: metrics,
            riskFactors: warnings.isEmpty ? [] : warnings,
            aiExplanation: explanation,
            caldwellTake: AssistantAnswer.caldwellTakePlaceholder,
            missingDataWarnings: warnings,
            kind: nil
        )
    }

    private func startSitAnswer(_ a: Context, _ b: Context) -> AssistantAnswer {
        guard let va = a.value, let vb = b.value else {
            let who = a.value == nil ? a.player.displayName : b.player.displayName
            return .unavailable(for: who, warnings: ["Not enough stored stats to compare these players."])
        }
        let start = va >= vb ? a : b
        let bench = va >= vb ? b : a
        let gap = abs(va - vb)
        let conf = confidence(for: [a, b], separation: gap)

        let explanation =
            "Start \(start.player.displayName). Over \(start.season.map(String.init) ?? "") they average "
            + "\(fmt(start.ppg)) PPG (\(fmt(start.recentAvg)) over last \(start.recent.count)) vs "
            + "\(bench.player.displayName) at \(fmt(bench.ppg)) PPG (\(fmt(bench.recentAvg)) recent). "
            + nextOpponentText(start)
            + " No live projections are stored, so this is production-based. Confidence: \(conf.label)."

        return AssistantAnswer(
            finalCall: "Start \(start.player.displayName) over \(bench.player.displayName)",
            verdictTag: "START",
            dataAvailable: true,
            confidence: conf.score,
            dataLastUpdated: [a.dataUpdated, b.dataUpdated].compactMap { $0 }.max(),
            modelScore: min(100, va.magnitude * 4),
            keyMetrics: playerMetrics(a) + playerMetrics(b),
            riskFactors: gap < 2 ? ["Close call — both are within ~2 PPG; roster fit matters."] : [],
            aiExplanation: explanation,
            caldwellTake: AssistantAnswer.caldwellTakePlaceholder,
            missingDataWarnings: missing(a) + missing(b),
            kind: .startSit
        )
    }

    private func tradeAnswer(_ a: Context, _ b: Context) -> AssistantAnswer {
        guard let va = a.value, let vb = b.value else {
            return .unavailable(for: "\(a.player.displayName) / \(b.player.displayName)",
                                warnings: ["Not enough stored stats to compare trade value."])
        }
        let better = va >= vb ? a : b
        let other = va >= vb ? b : a
        let conf = confidence(for: [a, b], separation: abs(va - vb))
        let ageNote: String = {
            guard let ba = better.player.age, let oa = other.player.age else { return "" }
            return " Age: \(better.player.displayName) \(ba), \(other.player.displayName) \(oa)."
        }()
        let explanation =
            "Based on stored production (no live projections exist), \(better.player.displayName) is the stronger asset: "
            + "\(fmt(better.ppg)) PPG vs \(fmt(other.ppg)) PPG this season, "
            + "recent form \(fmt(better.recentAvg)) vs \(fmt(other.recentAvg))."
            + ageNote
            + " This weighs current production and usage only. Confidence: \(conf.label)."

        return AssistantAnswer(
            finalCall: "Prefer \(better.player.displayName)",
            verdictTag: "BUY",
            dataAvailable: true,
            confidence: conf.score,
            dataLastUpdated: [a.dataUpdated, b.dataUpdated].compactMap { $0 }.max(),
            modelScore: min(100, va.magnitude * 4),
            keyMetrics: playerMetrics(a) + playerMetrics(b),
            riskFactors: ["Projections are not stored — trade value is production-based, not forward-looking."],
            aiExplanation: explanation,
            caldwellTake: AssistantAnswer.caldwellTakePlaceholder,
            missingDataWarnings: missing(a) + missing(b),
            kind: .trade
        )
    }

    private func notIdentified(_ q: String) -> AssistantAnswer {
        AssistantAnswer(
            finalCall: "I couldn't identify a player in that question",
            verdictTag: "NO DATA",
            dataAvailable: false,
            confidence: 0,
            dataLastUpdated: nil,
            modelScore: nil,
            keyMetrics: [],
            riskFactors: [],
            aiExplanation:
                "I only answer using players I can find in the Caldwell IQ database. "
                + "Try a full name, e.g. \"Start Jordan Love or Josh Allen?\" or \"How has Josh Jacobs played recently?\".",
            caldwellTake: AssistantAnswer.caldwellTakePlaceholder,
            missingDataWarnings: ["No recognized active QB/RB/WR/TE in your question."],
            kind: nil
        )
    }

    private func ambiguous(_ players: [RankedPlayer]) -> AssistantAnswer {
        let names = players.prefix(6).map { "\($0.displayName) (\($0.position ?? "?"), \($0.team ?? "FA"))" }
        return AssistantAnswer(
            finalCall: "Which player did you mean?",
            verdictTag: nil,
            dataAvailable: false,
            confidence: 0,
            dataLastUpdated: nil,
            modelScore: nil,
            keyMetrics: [],
            riskFactors: [],
            aiExplanation: "Your question matched several players. Please pick one:\n• " + names.joined(separator: "\n• "),
            caldwellTake: AssistantAnswer.caldwellTakePlaceholder,
            missingDataWarnings: ["Multiple players matched — narrow it down for a grounded answer."],
            kind: nil
        )
    }

    // MARK: Evidence + confidence helpers

    private func playerMetrics(_ c: Context) -> [KeyMetric] {
        var metrics: [KeyMetric] = []
        let ppgGrade = FantasyGrade.weeklyPoints(c.ppg, position: c.position)
        metrics.append(KeyMetric(
            label: "\(c.player.displayName) PPG", value: fmt(c.ppg),
            note: gradeNote(ppgGrade), sentiment: sentiment(ppgGrade)))
        metrics.append(KeyMetric(
            label: "\(c.player.displayName) games", value: "\(c.games)",
            note: c.games >= 8 ? "Full sample" : "Small sample", sentiment: c.games >= 8 ? .neutral : .negative))
        if let last3 = lastNAvg(c, 3) {
            metrics.append(KeyMetric(
                label: "Last 3 avg", value: fmt(last3),
                note: gradeNote(FantasyGrade.weeklyPoints(last3, position: c.position)),
                sentiment: sentiment(FantasyGrade.weeklyPoints(last3, position: c.position))))
        }
        if let ts = c.advanced.compactMap({ $0.targetShare }).max(), ts > 0 {
            metrics.append(KeyMetric(
                label: "Target share", value: String(format: "%.0f%%", ts * 100),
                note: ts >= 0.25 ? "High" : "Moderate", sentiment: ts >= 0.25 ? .positive : .neutral))
        }
        return metrics
    }

    private func lastNAvg(_ c: Context, _ n: Int) -> Double? {
        let s = c.recent.prefix(n).compactMap { $0.fantasyPointsPpr }
        return s.isEmpty ? nil : s.reduce(0, +) / Double(s.count)
    }

    private func missing(_ c: Context) -> [String] {
        var w: [String] = []
        if c.advanced.allSatisfy({ $0.targetShare == nil && $0.airYardsShare == nil }) {
            w.append("No advanced metrics stored for \(c.player.displayName).")
        }
        if !c.hasProjections { w.append("No projections stored for \(c.player.displayName).") }
        if c.nextGame == nil { w.append("No upcoming game found for \(c.player.team ?? "team").") }
        return w
    }

    private enum Confidence { case high, medium, low
        var score: Double { switch self { case .high: 85; case .medium: 60; case .low: 35 } }
        var label: String { switch self { case .high: "High"; case .medium: "Medium"; case .low: "Low" } }
    }

    private func confidence(for contexts: [Context], separation: Double = 10) -> Confidence {
        let minGames = contexts.map(\.games).min() ?? 0
        if minGames == 0 { return .low }
        if minGames >= 8 && separation >= 2 { return .high }
        if minGames >= 4 { return .medium }
        return .low
    }

    private func nextOpponentText(_ c: Context) -> String {
        guard let g = c.nextGame, let opp = g.opponent(for: c.player.team ?? "") else {
            return "No upcoming opponent is stored."
        }
        let ha = g.isHome(for: c.player.team ?? "") ? "vs" : "@"
        return "Next up: \(ha) \(opp)."
    }

    private func gradeNote(_ g: StatGrade) -> String {
        switch g { case .strong: "Strong"; case .average: "Average"; case .poor: "Below avg"; case .neutral: "—" }
    }
    private func sentiment(_ g: StatGrade) -> KeyMetric.Sentiment {
        switch g { case .strong: .positive; case .average: .neutral; case .poor: .negative; case .neutral: .neutral }
    }

    private func fmt(_ v: Double?) -> String { v.map { String(format: "%.1f", $0) } ?? "—" }

    private func parseDate(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}
