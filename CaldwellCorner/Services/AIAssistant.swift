import Foundation

/// Rule-based stand-in for the OpenAI-powered AI Fantasy Assistant (PRD §2).
/// Grounds every response in the local player database (RAG-style) so it never
/// invents stats — matching the "AI Hallucinations" mitigation in the plan.
enum AIAssistant {

    static func respond(to query: String, players: [Player], league: League?) -> String {
        let q = query.lowercased()

        // Trade question: "trade X for Y" / "should I trade ..."
        if q.contains("trade") || (q.contains(" for ") && mentionedPlayers(in: query, players: players).count >= 2) {
            let mentioned = mentionedPlayers(in: query, players: players)
            if mentioned.count >= 2 {
                let a = mentioned[0]
                let b = mentioned[1]
                let eval = TradeEngine.evaluate(sideA: [a], sideB: [b], league: league)
                let dir = eval.tradeGrade >= 55 ? "I'd lean toward accepting." :
                          eval.tradeGrade <= 45 ? "I'd lean toward declining." : "It's roughly a coin flip."
                return "Trade grade: \(Int(eval.tradeGrade))/100 · Fairness \(Int(eval.fairnessScore))/100.\n\n\(eval.explanation)\n\n\(dir)"
            }
            return "Tell me both players (e.g. \"Should I trade Garrett Wilson for Drake London?\") and I'll grade it using your league's settings."
        }

        // Start/sit
        if q.contains("start") || q.contains("sit") || q.contains("play") {
            let pos = detectPosition(in: q)
            let candidates = players
                .filter { pos == nil || $0.position == pos }
                .sorted { $0.projWeekly > $1.projWeekly }
                .prefix(3)
            if let top = candidates.first {
                let list = candidates.map { "• \($0.name) (\($0.position.rawValue)) — proj \(String(format: "%.1f", $0.projWeekly)) pts" }.joined(separator: "\n")
                return "Based on this week's projections\(pos != nil ? " at \(pos!.rawValue)" : ""), start \(top.name). My top options:\n\n\(list)\n\nThese are grounded in matchup, usage and Vegas inputs."
            }
        }

        // Waivers
        if q.contains("waiver") || q.contains("claim") || q.contains("pick up") || q.contains("add") {
            let targets = MockData.buildWaivers().prefix(3)
            let list = targets.map { "• \($0.playerName) (\($0.position.rawValue)) — bid ~\($0.faabBidPct)% FAAB. \($0.reason)" }.joined(separator: "\n")
            return "Top waiver targets this week:\n\n\(list)"
        }

        // Rebuild / dynasty strategy
        if q.contains("rebuild") || q.contains("contend") || q.contains("dynasty") {
            return "For a rebuild, prioritize youth and draft capital: sell aging veterans (27+) for picks and ascending players under 24. Your young core and future firsts are the foundation — target proven players entering year two or three who are being undervalued. If you're closer to contention, flip those picks for established producers to win now."
        }

        // Player lookup
        if let p = mentionedPlayers(in: query, players: players).first {
            return "\(p.name) (\(p.position.rawValue), \(p.team)) — Overall #\(p.overallRank), \(p.position.rawValue)\(p.positionRank). " +
                "Redraft value \(Int(p.redraftValue))/100, dynasty \(Int(p.dynastyValue))/100. " +
                "Weekly projection \(String(format: "%.1f", p.projWeekly)) pts (floor \(Int(p.floor)), ceiling \(Int(p.ceiling))). " +
                "\(p.blurb)"
        }

        // Fallback
        return "I'm your AI fantasy assistant, grounded in the Caldwell Corner player database. Ask me to grade a trade, set your start/sit, find waiver adds, or evaluate any player. For example: \"Grade Bijan Robinson for Ja'Marr Chase\"."
    }

    static func mentionedPlayers(in text: String, players: [Player]) -> [Player] {
        let lower = text.lowercased()
        var found: [(Int, Player)] = []
        for p in players {
            if let range = lower.range(of: p.name.lowercased()) {
                found.append((lower.distance(from: lower.startIndex, to: range.lowerBound), p))
            } else {
                // last name match
                if let last = p.name.split(separator: " ").last,
                   lower.contains(last.lowercased()), last.count > 3,
                   let range = lower.range(of: last.lowercased()) {
                    found.append((lower.distance(from: lower.startIndex, to: range.lowerBound), p))
                }
            }
        }
        return found.sorted { $0.0 < $1.0 }.map { $0.1 }
    }

    private static func detectPosition(in q: String) -> Position? {
        if q.contains("qb") || q.contains("quarterback") { return .qb }
        if q.contains("rb") || q.contains("running back") { return .rb }
        if q.contains("wr") || q.contains("receiver") || q.contains("wideout") { return .wr }
        if q.contains("te") || q.contains("tight end") { return .te }
        return nil
    }
}
