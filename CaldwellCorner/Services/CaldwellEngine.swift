import Foundation

/// Deterministic recommendation engine. Given stored `PlayerMetrics` and league
/// context it produces fully-explained `Recommendation`s. There is no randomness
/// and no language generation here — the AI assistant only narrates this output.
enum CaldwellEngine {

    struct Context {
        var scoring: ScoringFormat
        var superflex: Bool
        var dynasty: Bool

        init(scoring: ScoringFormat = .ppr, superflex: Bool = false, dynasty: Bool = false) {
            self.scoring = scoring; self.superflex = superflex; self.dynasty = dynasty
        }
        init(league: League?) {
            scoring = league?.scoring ?? .ppr
            superflex = league?.isSuperflex ?? false
            dynasty = (league?.type == .dynasty) || (league?.type == .keeper)
        }
    }

    private enum Horizon { case week, season, dynasty }

    // MARK: - Public modes

    static func startSit(_ players: [PlayerMetrics], context: Context) -> Recommendation {
        rankAndCompare(.startSit, players, context, horizon: .week) { _, e in e.modelScore }
    }

    static func waiver(_ candidates: [PlayerMetrics], context: Context) -> Recommendation {
        rankAndCompare(.waiver, candidates, context, horizon: .season) { m, e in
            e.modelScore * 0.5 + m.breakoutScore * 0.35 + m.snapShare * 100 * 0.15
        }
    }

    static func dynasty(_ players: [PlayerMetrics], context: Context) -> Recommendation {
        rankAndCompare(.dynasty, players, context, horizon: .dynasty) { _, e in e.longTerm }
    }

    static func keeper(_ players: [PlayerMetrics], context: Context) -> Recommendation {
        rankAndCompare(.keeper, players, context, horizon: .season) { _, e in
            e.modelScore * 0.6 + e.longTerm * 0.4
        }
    }

    static func draft(_ available: [PlayerMetrics], context: Context) -> Recommendation {
        let scored = available
            .filter { $0.hasCurrentData }
            .map { ($0, evaluate($0, context, horizon: .season)) }
            .sorted { $0.1.modelScore > $1.1.modelScore }
        guard let best = scored.first else {
            return Recommendation(kind: .draft, recommendedPlayer: "—", comparedPlayer: nil,
                scoreDifference: 0, confidence: 0, modelScore: 0, shortTermValue: 0,
                longTermValue: 0, riskLevel: .high, keyMetricsUsed: [], reasoningBullets: [],
                missingDataWarnings: ["No current data for any available player."],
                dataLastUpdated: nil, dataSources: [])
        }
        // Replacement = roughly the last startable option in a standard league.
        let replIndex = min(scored.count - 1, 11)
        let replacement = scored[replIndex]
        let diff = best.1.modelScore - replacement.1.modelScore
        return assemble(.draft, best: best, compared: replIndex == 0 ? nil : replacement,
                        scoreDifference: diff, modelScore: best.1.modelScore, context: context,
                        comparePhrase: "value over a replacement-level \(best.0.position.rawValue)")
    }

    static func trade(give: [PlayerMetrics], get: [PlayerMetrics], context: Context) -> Recommendation {
        let giveE = give.filter { $0.hasCurrentData }.map { ($0, evaluate($0, context, horizon: .season)) }
        let getE = get.filter { $0.hasCurrentData }.map { ($0, evaluate($0, context, horizon: .season)) }

        let missing = (give + get).filter { !$0.hasCurrentData }.map { "No current data for \($0.name)." }
        let giveVal = giveE.map { $0.1.modelScore }.reduce(0, +)
        let getVal = getE.map { $0.1.modelScore }.reduce(0, +)

        let getHead = getE.max { $0.1.modelScore < $1.1.modelScore }
        let giveHead = giveE.max { $0.1.modelScore < $1.1.modelScore }

        let ratio = getVal / max(giveVal, 1)
        let grade = clamp(50 + (ratio - 1) * 70)
        let diff = getVal - giveVal

        let shortTerm = mean(getE.map { $0.1.shortTerm })
        let longTerm = mean(getE.map { $0.1.longTerm })

        let conf = clamp(0.6 * mean((giveE + getE).map { $0.0.confidenceScore }) + 0.4 * clamp(abs(grade - 50) * 2))
        let risk = riskLevel(for: getHead?.0)

        let verdict = grade >= 58 ? "Accept" : grade <= 43 ? "Decline" : "Fair"
        var bullets: [String] = []
        if let g = getHead {
            bullets.append("You'd land \(g.0.name) (model \(intStr(g.1.modelScore))/100) headlining the return.")
            bullets.append(contentsOf: g.1.bullets.prefix(2))
        }
        bullets.append(abs(diff) < 6
            ? "Total model value is nearly even (\(intStr(getVal)) vs \(intStr(giveVal))) — this comes down to roster fit."
            : diff > 0
                ? "You gain \(intStr(diff)) net model points, so the deal favors your side."
                : "You give up \(intStr(-diff)) net model points; the upside or fit must justify it.")
        bullets.append(longTerm > shortTerm
            ? "The return skews long-term (future \(intStr(longTerm)) > win-now \(intStr(shortTerm)))."
            : "The return skews win-now (win-now \(intStr(shortTerm)) ≥ future \(intStr(longTerm))).")

        return Recommendation(
            kind: .trade,
            recommendedPlayer: getHead?.0.name ?? "Their side",
            comparedPlayer: giveHead?.0.name ?? "Your side",
            scoreDifference: round1(diff),
            confidence: round1(conf),
            modelScore: round1(grade),
            shortTermValue: round1(shortTerm),
            longTermValue: round1(longTerm),
            riskLevel: risk,
            keyMetricsUsed: getHead?.1.key ?? [],
            reasoningBullets: ["Verdict: \(verdict.uppercased()) — trade grade \(intStr(grade))/100."] + bullets,
            missingDataWarnings: missing,
            dataLastUpdated: oldest((give + get)),
            dataSources: (give + get).first?.dataSources ?? [])
    }

    // MARK: - Ranking helper for compare-style modes
    private static func rankAndCompare(
        _ kind: RecommendationKind, _ list: [PlayerMetrics], _ ctx: Context,
        horizon: Horizon, rankBy: (PlayerMetrics, Eval) -> Double
    ) -> Recommendation {
        let scored = list
            .filter { $0.hasCurrentData }
            .map { ($0, evaluate($0, ctx, horizon: horizon)) }
            .sorted { rankBy($0.0, $0.1) > rankBy($1.0, $1.1) }

        guard let best = scored.first else {
            let names = list.map { $0.name }.joined(separator: ", ")
            return Recommendation(kind: kind, recommendedPlayer: "—", comparedPlayer: nil,
                scoreDifference: 0, confidence: 0, modelScore: 0, shortTermValue: 0, longTermValue: 0,
                riskLevel: .high, keyMetricsUsed: [], reasoningBullets: [],
                missingDataWarnings: ["No current data for \(names.isEmpty ? "the requested players" : names)."],
                dataLastUpdated: nil, dataSources: [])
        }
        let second = scored.count > 1 ? scored[1] : nil
        let diff = (rankBy(best.0, best.1)) - (second.map { rankBy($0.0, $0.1) } ?? (rankBy(best.0, best.1) - 12))
        return assemble(kind, best: best, compared: second, scoreDifference: diff,
                        modelScore: best.1.modelScore, context: ctx, comparePhrase: nil)
    }

    // MARK: - Assemble a Recommendation from evaluated players
    private static func assemble(
        _ kind: RecommendationKind, best: (PlayerMetrics, Eval), compared: (PlayerMetrics, Eval)?,
        scoreDifference: Double, modelScore: Double, context: Context, comparePhrase: String?
    ) -> Recommendation {
        let conf = confidence(best.0, decisiveness: scoreDifference)
        var bullets = best.1.bullets
        if let c = compared {
            if let phrase = comparePhrase {
                bullets.append("\(best.0.name) provides \(intStr(scoreDifference)) points of \(phrase) like \(c.0.name).")
            } else {
                bullets.append("Edges \(c.0.name) by \(intStr(abs(scoreDifference))) model points (\(intStr(best.1.modelScore)) vs \(intStr(c.1.modelScore))).")
            }
        }
        if conf < 60 || abs(scoreDifference) < 5 {
            bullets.append("This is a close call — confidence is only \(intStr(conf))%, so lean on your roster needs.")
        }
        return Recommendation(
            kind: kind,
            recommendedPlayer: best.0.name,
            comparedPlayer: compared?.0.name,
            scoreDifference: round1(scoreDifference),
            confidence: round1(conf),
            modelScore: round1(modelScore),
            shortTermValue: round1(best.1.shortTerm),
            longTermValue: round1(best.1.longTerm),
            riskLevel: riskLevel(for: best.0),
            keyMetricsUsed: best.1.key,
            reasoningBullets: bullets,
            missingDataWarnings: best.1.warnings,
            dataLastUpdated: compared.map { oldestDate(best.0.dataLastUpdated, $0.0.dataLastUpdated) } ?? best.0.dataLastUpdated,
            dataSources: best.0.dataSources)
    }

    // MARK: - Core evaluation
    private struct Eval {
        var modelScore: Double
        var shortTerm: Double
        var longTerm: Double
        var key: [KeyMetric]
        var bullets: [String]
        var warnings: [String]
    }

    private static func evaluate(_ m: PlayerMetrics, _ ctx: Context, horizon: Horizon) -> Eval {
        let base = clamp(m.expectedFantasyPoints * 4)
        let isPassGame = m.position == .wr || m.position == .te || m.position == .qb

        // Position usage adjustment
        var usageAdj = 0.0
        switch m.position {
        case .wr, .te:
            usageAdj = (m.yardsPerRouteRun - 1.7) * 9
                + (m.targetsPerRouteRun - 0.20) * 70
                + (m.targetShare - 0.20) * 45
                + (m.airYardsShare - 0.20) * 18
                + (m.firstReadShare - 0.20) * 15
                + Double(m.redZoneTargets) * 0.8
                + Double(m.endZoneTargets) * 1.2
        case .rb:
            usageAdj = (m.rushShare - 0.5) * 35
                + (m.snapShare - 0.6) * 25
                + (m.goalLineShare - 0.4) * 22
                + (m.yardsAfterContact - 2.5) * 5
                + Double(m.missedTacklesForced) * 0.35
                + m.explosivePlayRate * 40
                + m.targetShare * 30
        case .qb:
            usageAdj = m.teamEPAperPlay * 120 + (m.impliedTeamTotal - 22) * 1.6
        case .k, .def:
            usageAdj = 0
        }

        let env = m.teamEPAperPlay * 20
            + m.teamPassRateOverExpected * (isPassGame ? 60 : -25)
            - Double(m.offensiveLineRank - 16) * 0.5
            + (m.impliedTeamTotal - 22) * 1.0
            + m.matchupEPAAllowed * 30
            - (m.scheduleDifficulty - 50) * 0.15
            - m.spread * 0.4

        let youth = m.age.map { clamp(Double(26 - $0) * 5, -15, 25) } ?? 5

        var nowScore = clamp(base + usageAdj * 0.6 + env * 1.0 + m.fantasyPointsOverExpected * 0.8 - m.regressionScore * 0.08)
        var seasonScore = clamp(base + usageAdj * 0.8 + env * 0.5 - m.regressionScore * 0.12 + m.breakoutScore * 0.12)
        var longScore = clamp(base * 0.55 + usageAdj * 0.7 + m.breakoutScore * 0.45 + youth - m.regressionScore * 0.18)

        // League context
        let fmt = formatWeight(m.position, ctx.scoring)
        nowScore = clamp(nowScore * fmt); seasonScore = clamp(seasonScore * fmt); longScore = clamp(longScore * fmt)
        if ctx.superflex && m.position == .qb {
            nowScore = clamp(nowScore + 8); seasonScore = clamp(seasonScore + 8); longScore = clamp(longScore + 10)
        }
        // Availability haircut
        let avail = availability(m.injuryStatus)
        nowScore = clamp(nowScore * avail)

        let model: Double
        switch horizon {
        case .week: model = nowScore
        case .season: model = seasonScore
        case .dynasty: model = longScore
        }

        return Eval(modelScore: model, shortTerm: nowScore, longTerm: longScore,
                    key: keyMetrics(m), bullets: bullets(m), warnings: warnings(m))
    }

    // MARK: - Key metrics (position-aware)
    private static func keyMetrics(_ m: PlayerMetrics) -> [KeyMetric] {
        switch m.position {
        case .wr, .te:
            return [
                num("Yards / Route Run", m.yardsPerRouteRun, fmt: f2(m.yardsPerRouteRun), good: 2.2, ok: 1.6),
                pct("Target Share", m.targetShare, good: 0.26, ok: 0.18),
                num("Targets / Route Run", m.targetsPerRouteRun, fmt: f2(m.targetsPerRouteRun), good: 0.26, ok: 0.18),
                pct("Air Yards Share", m.airYardsShare, good: 0.32, ok: 0.20),
                int("Red Zone Targets", m.redZoneTargets, good: 12, ok: 6),
            ]
        case .rb:
            return [
                pct("Snap Share", m.snapShare, good: 0.70, ok: 0.50),
                pct("Rush Share", m.rushShare, good: 0.65, ok: 0.45),
                pct("Goal-Line Share", m.goalLineShare, good: 0.55, ok: 0.30),
                num("Yards After Contact", m.yardsAfterContact, fmt: f2(m.yardsAfterContact), good: 3.2, ok: 2.4),
                pct("Target Share", m.targetShare, good: 0.14, ok: 0.08),
            ]
        case .qb:
            return [
                num("Team EPA / Play", m.teamEPAperPlay, fmt: f2(m.teamEPAperPlay), good: 0.12, ok: 0.0),
                num("Implied Team Total", m.impliedTeamTotal, fmt: f1(m.impliedTeamTotal), good: 25, ok: 21),
                num("Pass Rate Over Exp.", m.teamPassRateOverExpected, fmt: pctStr(m.teamPassRateOverExpected), good: 0.03, ok: -0.02),
                num("FP Over Expected", m.fantasyPointsOverExpected, fmt: f1(m.fantasyPointsOverExpected), good: 2, ok: -2),
            ]
        default:
            return [num("Expected FP", m.expectedFantasyPoints, fmt: f1(m.expectedFantasyPoints), good: 12, ok: 8)]
        }
    }

    // MARK: - Reasoning bullets (data-grounded)
    private static func bullets(_ m: PlayerMetrics) -> [String] {
        var out: [String] = []
        let role: String
        switch m.position {
        case .wr, .te:
            role = m.targetShare >= 0.26 ? "an alpha target earner" : m.targetShare >= 0.18 ? "a solid every-down option" : "a rotational piece"
            out.append("\(m.name) profiles as \(role): \(f2(m.yardsPerRouteRun)) YPRR on a \(pctStr(m.targetShare)) target share and \(pctStr(m.airYardsShare)) air-yards share.")
            if m.redZoneTargets >= 8 { out.append("Real red-zone equity (\(m.redZoneTargets) RZ targets, \(m.endZoneTargets) end-zone looks) raises the touchdown floor.") }
        case .rb:
            role = m.snapShare >= 0.70 ? "a workhorse" : m.snapShare >= 0.50 ? "the lead back" : "a committee back"
            out.append("\(m.name) is \(role): \(pctStr(m.snapShare)) snap share, \(pctStr(m.rushShare)) rush share and \(pctStr(m.goalLineShare)) of goal-line work.")
            if m.yardsAfterContact >= 3.0 || m.missedTacklesForced >= 25 {
                out.append("Efficiency backs it up — \(f2(m.yardsAfterContact)) yards after contact and \(m.missedTacklesForced) forced missed tackles.")
            }
        case .qb:
            out.append("\(m.name)'s offense grades at \(f2(m.teamEPAperPlay)) EPA/play with a \(f1(m.impliedTeamTotal))-point implied total this week.")
        default:
            out.append("\(m.name) projects for \(f1(m.expectedFantasyPoints)) expected fantasy points.")
        }
        // Environment
        let matchupWord = m.matchupEPAAllowed >= 0.05 ? "a plus matchup" : m.matchupEPAAllowed <= -0.05 ? "a tough matchup" : "a neutral matchup"
        out.append("Environment: \(matchupWord) (opp allows \(f2(m.matchupEPAAllowed)) EPA/play), O-line ranked #\(m.offensiveLineRank), spread \(f1(m.spread)).")
        // Regression / breakout
        if m.fantasyPointsOverExpected >= 4 && m.regressionScore >= 60 {
            out.append("Caution: \(f1(m.fantasyPointsOverExpected)) points over expected with a \(intStr(m.regressionScore))/100 regression score — some pullback is likely.")
        } else if m.breakoutScore >= 65 {
            out.append("Arrow up: a \(intStr(m.breakoutScore))/100 breakout score signals the role is still expanding.")
        }
        return out
    }

    // MARK: - Warnings (guardrails)
    private static func warnings(_ m: PlayerMetrics) -> [String] {
        var w: [String] = []
        if m.isStale { w.append("Metrics are \(Int(Date().timeIntervalSince(m.dataLastUpdated) / 86400)) days old — treat as stale.") }
        if m.injuryStatus != .healthy { w.append("\(m.name) is \(m.injuryStatus.rawValue) — monitor availability before locking this in.") }
        if m.confidenceScore < 55 { w.append("Limited sample for \(m.name) (\(intStr(m.confidenceScore))/100 data confidence).") }
        return w
    }

    // MARK: - Shared scoring helpers
    private static func confidence(_ m: PlayerMetrics, decisiveness: Double) -> Double {
        var penalty = 0.0
        if m.isStale { penalty += 15 }
        if m.injuryStatus != .healthy { penalty += 8 }
        return clamp(0.65 * m.confidenceScore + 0.35 * clamp(abs(decisiveness) * 2.5) - penalty)
    }

    private static func riskLevel(for m: PlayerMetrics?) -> RiskLevel {
        guard let m else { return .medium }
        var score = m.regressionScore
        if m.injuryStatus != .healthy { score += 20 }
        if m.confidenceScore < 55 { score += 15 }
        if m.fantasyPointsOverExpected > 5 { score += 10 }
        return score < 35 ? .low : score < 60 ? .medium : .high
    }

    private static func availability(_ s: InjuryStatus) -> Double {
        switch s {
        case .healthy: return 1.0
        case .questionable: return 0.9
        case .doubtful: return 0.5
        case .out, .ir: return 0.1
        }
    }

    private static func formatWeight(_ pos: Position, _ scoring: ScoringFormat) -> Double {
        let passCatcher = pos == .wr || pos == .te
        switch scoring {
        case .ppr: return passCatcher ? 1.05 : 1.0
        case .standard: return passCatcher ? 0.95 : 1.03
        case .halfPPR: return 1.0
        }
    }

    // MARK: - Formatting
    private static func clamp(_ v: Double, _ lo: Double = 0, _ hi: Double = 100) -> Double { max(lo, min(hi, v)) }
    private static func mean(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count) }
    private static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
    private static func intStr(_ v: Double) -> String { String(Int(v.rounded())) }
    private static func f1(_ v: Double) -> String { String(format: "%.1f", v) }
    private static func f2(_ v: Double) -> String { String(format: "%.2f", v) }
    private static func pctStr(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }

    private static func pct(_ label: String, _ v: Double, good: Double, ok: Double) -> KeyMetric {
        let s: KeyMetric.Sentiment = v >= good ? .positive : v >= ok ? .neutral : .negative
        return KeyMetric(label: label, value: pctStr(v), note: note(s), sentiment: s)
    }
    private static func num(_ label: String, _ v: Double, fmt: String, good: Double, ok: Double) -> KeyMetric {
        let s: KeyMetric.Sentiment = v >= good ? .positive : v >= ok ? .neutral : .negative
        return KeyMetric(label: label, value: fmt, note: note(s), sentiment: s)
    }
    private static func int(_ label: String, _ v: Int, good: Int, ok: Int) -> KeyMetric {
        let s: KeyMetric.Sentiment = v >= good ? .positive : v >= ok ? .neutral : .negative
        return KeyMetric(label: label, value: String(v), note: note(s), sentiment: s)
    }
    private static func note(_ s: KeyMetric.Sentiment) -> String {
        switch s { case .positive: return "Elite"; case .neutral: return "Average"; case .negative: return "Below avg" }
    }

    private static func oldest(_ list: [PlayerMetrics]) -> Date? {
        list.map { $0.dataLastUpdated }.min()
    }
    private static func oldestDate(_ a: Date, _ b: Date) -> Date { a < b ? a : b }
}
