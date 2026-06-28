import Foundation

enum RecommendationKind: String, Codable, Hashable {
    case startSit = "Start / Sit"
    case trade = "Trade"
    case waiver = "Waiver"
    case draft = "Draft"
    case dynasty = "Dynasty"
    case keeper = "Keeper"
}

enum RiskLevel: String, Codable, Hashable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

/// One advanced metric that contributed to a decision, with a qualitative note.
struct KeyMetric: Identifiable, Codable, Hashable {
    var id = UUID()
    var label: String
    var value: String
    var note: String       // e.g. "Elite", "Above average", "Concern"
    var sentiment: Sentiment

    enum Sentiment: String, Codable, Hashable { case positive, neutral, negative }
}

/// Deterministic output of `CaldwellEngine`. The AI assistant may only explain
/// these values — it never produces its own rankings or stats.
struct Recommendation: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: RecommendationKind
    var recommendedPlayer: String
    var comparedPlayer: String?
    var scoreDifference: Double
    var confidence: Double          // 0…100
    var modelScore: Double          // 0…100 for the recommended player
    var shortTermValue: Double      // 0…100
    var longTermValue: Double       // 0…100
    var riskLevel: RiskLevel
    var keyMetricsUsed: [KeyMetric]
    var reasoningBullets: [String]
    var missingDataWarnings: [String]
    var dataLastUpdated: Date?
    var dataSources: [String]

    var isCloseCall: Bool { confidence < 60 || abs(scoreDifference) < 5 }
    var hasData: Bool { dataLastUpdated != nil }
}

/// Structured payload the AI Coach screen renders. Assembled by the assistant
/// from a `Recommendation` (or a "data unavailable" state).
struct AssistantAnswer: Identifiable, Codable, Hashable {
    var id = UUID()
    var finalCall: String
    var verdictTag: String?          // short pill, e.g. "START", "ACCEPT"
    var dataAvailable: Bool
    var confidence: Double
    var dataLastUpdated: Date?
    var modelScore: Double?
    var keyMetrics: [KeyMetric]
    var riskFactors: [String]
    var aiExplanation: String        // GM-coach narration of the engine output
    var caldwellTake: String         // placeholder for editorial content
    var missingDataWarnings: [String]
    var kind: RecommendationKind?

    static let caldwellTakePlaceholder =
        "Caldwell Take coming soon — Carson's editorial spin on this call will appear here once published."

    /// Guardrail answer used when current data is unavailable.
    static func unavailable(for subject: String, warnings: [String]) -> AssistantAnswer {
        AssistantAnswer(
            finalCall: "Current data unavailable",
            verdictTag: "NO DATA",
            dataAvailable: false,
            confidence: 0,
            dataLastUpdated: nil,
            modelScore: nil,
            keyMetrics: [],
            riskFactors: [],
            aiExplanation:
                "I don't have current, verified metrics for \(subject), so I won't guess. " +
                "Once the data pipeline refreshes from our trusted sources, I'll grade this with full advanced analytics.",
            caldwellTake: caldwellTakePlaceholder,
            missingDataWarnings: warnings.isEmpty ? ["No current data for \(subject)."] : warnings,
            kind: nil)
    }
}
