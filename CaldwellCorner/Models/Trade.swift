import Foundation

/// Result produced by the Trade Analyzer engine (PRD §3).
struct TradeEvaluation: Identifiable, Hashable {
    let id = UUID()
    var sideAValue: Double
    var sideBValue: Double
    var tradeGrade: Double      // 0...100 for the user's side (side A)
    var fairnessScore: Double   // 0...100, 100 = perfectly even
    var winNowScore: Double     // 0...100
    var futureScore: Double     // 0...100
    var riskRating: String      // "Low" / "Medium" / "High"
    var verdict: String         // short headline
    var explanation: String     // AI explanation

    var favorsSideA: Bool { sideAValue >= sideBValue }
}

/// A simple chat message for the AI Fantasy Assistant (PRD §2).
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    var role: Role
    var text: String
    /// When present, the assistant message renders as a structured answer card
    /// instead of a plain text bubble.
    var answer: AssistantAnswer? = nil
    var timestamp: Date = Date()

    enum Role: String { case user, assistant }
}

/// Suggested prompts shown in the AI assistant.
struct SuggestedPrompt: Identifiable, Hashable {
    let id = UUID()
    var text: String
    var systemImage: String
}
