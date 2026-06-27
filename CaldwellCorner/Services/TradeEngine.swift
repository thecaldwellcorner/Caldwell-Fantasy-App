import Foundation

/// Deterministic, explainable trade-evaluation engine (PRD §3).
/// Weighs player value, age, win-now vs. future and league context.
enum TradeEngine {

    static func evaluate(sideA: [Player], sideB: [Player],
                         league: League?) -> TradeEvaluation {
        let dynasty = league?.type == .dynasty || league?.type == .keeper
        let superflex = league?.isSuperflex ?? false

        func value(_ p: Player) -> Double {
            var base = dynasty ? p.dynastyValue : p.redraftValue
            if superflex && p.position == .qb { base += 8 }
            return base
        }

        let aValue = sideA.map(value).reduce(0, +)
        let bValue = sideB.map(value).reduce(0, +)

        // Fairness: how close the two sides are (100 = even)
        let maxV = max(aValue, bValue, 1)
        let fairness = max(0, 100 - (abs(aValue - bValue) / maxV) * 100)

        // Trade grade for side A = how much value A receives (gets sideB)
        // We grade the package the user RECEIVES (sideB) relative to what they give (sideA).
        let received = bValue
        let given = max(aValue, 1)
        let ratio = received / given
        let tradeGrade = min(100, max(0, 50 + (ratio - 1) * 70))

        // Win-now: prioritizes proven points now (redraft value, lower age)
        func winNow(_ players: [Player]) -> Double {
            guard !players.isEmpty else { return 0 }
            return players.map { $0.redraftValue - Double(max(0, $0.age - 27)) * 2 }
                .reduce(0, +) / Double(players.count)
        }
        // Future: dynasty value + youth
        func future(_ players: [Player]) -> Double {
            guard !players.isEmpty else { return 0 }
            return players.map { $0.dynastyValue + Double(max(0, 27 - $0.age)) * 1.5 }
                .reduce(0, +) / Double(players.count)
        }

        let winNowScore = min(100, max(0, winNow(sideB)))
        let futureScore = min(100, max(0, future(sideB)))

        // Risk from injury + bust probability of received players
        let avgBust = sideB.isEmpty ? 0 : sideB.map { $0.bustProbability }.reduce(0, +) / Double(sideB.count)
        let injuryFlag = sideB.contains { $0.injuryStatus.isConcern }
        let risk: String
        switch avgBust + (injuryFlag ? 12 : 0) {
        case ..<12: risk = "Low"
        case 12..<22: risk = "Medium"
        default: risk = "High"
        }

        let verdict: String
        switch tradeGrade {
        case 60...: verdict = "You win this trade"
        case 45..<60: verdict = "Fair, balanced deal"
        default: verdict = "You're giving up too much"
        }

        let explanation = buildExplanation(
            sideA: sideA, sideB: sideB, aValue: aValue, bValue: bValue,
            dynasty: dynasty, superflex: superflex, winNowScore: winNowScore,
            futureScore: futureScore, risk: risk)

        return TradeEvaluation(
            sideAValue: aValue, sideBValue: bValue, tradeGrade: tradeGrade,
            fairnessScore: fairness, winNowScore: winNowScore, futureScore: futureScore,
            riskRating: risk, verdict: verdict, explanation: explanation)
    }

    private static func buildExplanation(sideA: [Player], sideB: [Player],
                                         aValue: Double, bValue: Double, dynasty: Bool,
                                         superflex: Bool, winNowScore: Double,
                                         futureScore: Double, risk: String) -> String {
        let give = sideA.map { $0.name }.joined(separator: ", ")
        let get = sideB.map { $0.name }.joined(separator: ", ")
        let context = dynasty ? "dynasty" : "redraft"
        let sfNote = superflex ? " In Superflex, quarterback value is boosted, which is reflected above." : ""
        let diff = bValue - aValue
        let lean: String
        if abs(diff) < 6 {
            lean = "The values are close to even, so this comes down to roster fit and timeline."
        } else if diff > 0 {
            lean = "You're acquiring more total \(context) value, so this projects as a win for your side."
        } else {
            lean = "You're sending out more \(context) value, so make sure the upside or roster fit justifies it."
        }
        let timeline = futureScore > winNowScore
            ? "The package you receive skews toward the future — ideal if you're building a long-term contender."
            : "The package you receive skews win-now — ideal if you're pushing for a title this season."
        return "You'd give \(give.isEmpty ? "nothing" : give) to receive \(get.isEmpty ? "nothing" : get). \(lean) \(timeline) Risk profile is rated \(risk) based on injury status and bust probability.\(sfNote)"
    }
}
