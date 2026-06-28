import Foundation

/// The AI Fantasy Coach. It does NOT invent rankings, stats or analysis.
/// It detects intent, asks `CaldwellEngine` for a deterministic `Recommendation`
/// grounded in stored `PlayerMetrics`, then narrates that output like an expert
/// fantasy GM. Guardrails: missing data → "Current data unavailable"; low
/// confidence → flagged as a close call; never fabricates advanced metrics.
enum AIAssistant {

    static func answer(to query: String,
                       metrics: [PlayerMetrics],
                       waiverPool: [PlayerMetrics],
                       context: CaldwellEngine.Context) -> AssistantAnswer {
        let q = query.lowercased()
        let mentioned = mentionedPlayers(in: query, metrics: metrics)

        // Guardrail: if the user named a player we track but have no current data for.
        if let stale = mentioned.first(where: { !$0.hasCurrentData }) {
            return .unavailable(for: stale.name,
                                warnings: ["No current data for \(stale.name) — data pipeline has not refreshed."])
        }

        // Intent routing
        if isTrade(q, mentioned: mentioned) {
            return tradeAnswer(query: query, q: q, metrics: metrics, context: context)
        }
        if q.contains("waiver") || q.contains("claim") || q.contains("pick up") || q.contains("faab") || q.contains("add ") {
            let rec = CaldwellEngine.waiver(waiverPool, context: context)
            return build(rec)
        }
        if q.contains("keeper") || q.contains(" keep") {
            return rankedAnswer(.keeper, query: query, mentioned: mentioned, metrics: metrics, context: context)
        }
        if q.contains("dynasty") || q.contains("rebuild") || q.contains("long term") || q.contains("long-term") {
            return rankedAnswer(.dynasty, query: query, mentioned: mentioned, metrics: metrics, context: context)
        }
        if q.contains("draft") && !q.contains("trade") {
            let pool = metrics.filter { $0.hasCurrentData }
            return build(CaldwellEngine.draft(pool, context: context))
        }
        if q.contains("start") || q.contains("sit") || q.contains("flex") || q.contains(" play ") || mentioned.count >= 1 {
            return rankedAnswer(.startSit, query: query, mentioned: mentioned, metrics: metrics, context: context)
        }

        return helpAnswer()
    }

    // MARK: - Routers
    private static func rankedAnswer(_ kind: RecommendationKind, query: String,
                                     mentioned: [PlayerMetrics], metrics: [PlayerMetrics],
                                     context: CaldwellEngine.Context) -> AssistantAnswer {
        var pool = mentioned.filter { $0.hasCurrentData }
        if pool.isEmpty {
            if let pos = detectPosition(query.lowercased()) {
                pool = metrics.filter { $0.position == pos && $0.hasCurrentData }
            } else {
                return helpAnswer()
            }
        }
        let rec: Recommendation
        switch kind {
        case .dynasty: rec = CaldwellEngine.dynasty(pool, context: context)
        case .keeper: rec = CaldwellEngine.keeper(pool, context: context)
        default: rec = CaldwellEngine.startSit(pool, context: context)
        }
        return build(rec)
    }

    private static func tradeAnswer(query: String, q: String, metrics: [PlayerMetrics],
                                    context: CaldwellEngine.Context) -> AssistantAnswer {
        var give: [PlayerMetrics] = []
        var get: [PlayerMetrics] = []
        if let range = q.range(of: " for ") {
            let lower = q
            let leftText = String(lower[..<range.lowerBound])
            let rightText = String(lower[range.upperBound...])
            give = mentionedPlayers(in: leftText, metrics: metrics)
            get = mentionedPlayers(in: rightText, metrics: metrics)
        } else {
            let all = mentionedPlayers(in: query, metrics: metrics)
            if all.count >= 2 { give = [all[0]]; get = Array(all[1...]) }
            else { get = all }
        }

        let named = give + get
        if let stale = named.first(where: { !$0.hasCurrentData }) {
            return .unavailable(for: stale.name, warnings: ["No current data for \(stale.name)."])
        }
        if give.isEmpty && get.isEmpty {
            return AssistantAnswer(
                finalCall: "Name both sides of the trade",
                verdictTag: nil, dataAvailable: true, confidence: 0, dataLastUpdated: nil,
                modelScore: nil, keyMetrics: [], riskFactors: [],
                aiExplanation: "Tell me who you'd give and who you'd get — e.g. \"Should I trade Travis Etienne for Ja'Marr Chase?\" — and I'll grade it on the model.",
                caldwellTake: AssistantAnswer.caldwellTakePlaceholder,
                missingDataWarnings: [], kind: .trade)
        }
        return build(CaldwellEngine.trade(give: give, get: get, context: context))
    }

    // MARK: - Build a structured answer from a Recommendation
    private static func build(_ rec: Recommendation) -> AssistantAnswer {
        let (finalCall, tag) = headline(for: rec)
        let noData = rec.missingDataWarnings.filter { $0.localizedCaseInsensitiveContains("no current data") }
        let riskWarns = rec.missingDataWarnings.filter { !$0.localizedCaseInsensitiveContains("no current data") }

        var riskFactors = ["Overall model risk: \(rec.riskLevel.rawValue)."]
        riskFactors.append(contentsOf: riskWarns)
        if rec.isCloseCall {
            riskFactors.append("Close call — model confidence is \(Int(rec.confidence.rounded()))%, so weigh your roster needs.")
        }

        return AssistantAnswer(
            finalCall: finalCall,
            verdictTag: tag,
            dataAvailable: rec.hasData,
            confidence: rec.confidence,
            dataLastUpdated: rec.dataLastUpdated,
            modelScore: rec.modelScore,
            keyMetrics: rec.keyMetricsUsed,
            riskFactors: riskFactors,
            aiExplanation: narrate(rec),
            caldwellTake: AssistantAnswer.caldwellTakePlaceholder,
            missingDataWarnings: noData,
            kind: rec.kind)
    }

    private static func headline(for rec: Recommendation) -> (String, String) {
        let p = rec.recommendedPlayer
        switch rec.kind {
        case .startSit:
            if let c = rec.comparedPlayer { return ("Start \(p) over \(c)", "START") }
            return ("Start \(p)", "START")
        case .trade:
            let verdict = rec.modelScore >= 58 ? "Accept" : rec.modelScore <= 43 ? "Decline" : "Fair value"
            return ("\(verdict): land \(p)", verdict.uppercased())
        case .waiver:
            return ("Add \(p)", "ADD")
        case .draft:
            return ("Draft \(p)", "DRAFT")
        case .dynasty:
            if let c = rec.comparedPlayer { return ("Prefer \(p) over \(c)", "BUY") }
            return ("Buy \(p)", "BUY")
        case .keeper:
            return ("Keep \(p)", "KEEP")
        }
    }

    private static func narrate(_ rec: Recommendation) -> String {
        let opener: String
        switch rec.kind {
        case .startSit: opener = "Here's the lineup call, GM."
        case .trade: opener = "Let's break down the trade."
        case .waiver: opener = "Here's your top waiver move this week."
        case .draft: opener = "You're on the clock — here's the value pick."
        case .dynasty: opener = "Thinking long term, here's the read."
        case .keeper: opener = "On the keeper decision —"
        }
        let body = rec.reasoningBullets.joined(separator: " ")
        return "\(opener) \(body)"
    }

    private static func helpAnswer() -> AssistantAnswer {
        AssistantAnswer(
            finalCall: "Ask me for a grounded call",
            verdictTag: nil, dataAvailable: true, confidence: 0, dataLastUpdated: nil,
            modelScore: nil, keyMetrics: [], riskFactors: [],
            aiExplanation:
                "I'm your fantasy GM coach. I only act on the Caldwell model and verified advanced metrics — I won't guess or make up stats. " +
                "Ask me to set a start/sit, grade a trade, find a waiver add, or evaluate a player, and I'll show the model score, the advanced metrics behind it, and the risks.",
            caldwellTake: AssistantAnswer.caldwellTakePlaceholder,
            missingDataWarnings: [], kind: nil)
    }

    // MARK: - Parsing helpers
    private static func isTrade(_ q: String, mentioned: [PlayerMetrics]) -> Bool {
        if q.contains("trade") { return true }
        if q.contains(" for ") && mentioned.count >= 2 { return true }
        return false
    }

    static func mentionedPlayers(in text: String, metrics: [PlayerMetrics]) -> [PlayerMetrics] {
        let lower = text.lowercased()
        var found: [(Int, PlayerMetrics)] = []
        for m in metrics {
            let name = m.name.lowercased()
            if let r = lower.range(of: name) {
                found.append((lower.distance(from: lower.startIndex, to: r.lowerBound), m))
            } else if let last = m.name.split(separator: " ").last, last.count > 3,
                      let r = lower.range(of: last.lowercased()) {
                found.append((lower.distance(from: lower.startIndex, to: r.lowerBound), m))
            }
        }
        // De-dupe by player id, keep earliest mention order.
        var seen = Set<String>()
        return found.sorted { $0.0 < $1.0 }.compactMap { (_, m) in
            seen.insert(m.playerId).inserted ? m : nil
        }
    }

    private static func detectPosition(_ q: String) -> Position? {
        if q.contains("qb") || q.contains("quarterback") { return .qb }
        if q.contains("rb") || q.contains("running back") { return .rb }
        if q.contains("wr") || q.contains("receiver") || q.contains("wideout") { return .wr }
        if q.contains("te") || q.contains("tight end") { return .te }
        return nil
    }
}
