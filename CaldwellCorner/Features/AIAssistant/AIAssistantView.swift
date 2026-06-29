import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var state: AppState
    @Binding var showPaywall: Bool

    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hey GM — I'm your AI Fantasy Coach. I only act on the Caldwell model and verified advanced metrics, so I won't guess or invent stats. Ask me to set a start/sit, grade a trade, find a waiver add, or evaluate a player.")
    ]
    @State private var input = ""
    @State private var isThinking = false
    @FocusState private var focused: Bool

    private let prompts: [SuggestedPrompt] = [
        .init(text: "Should I start Puka Nacua or Garrett Wilson?", systemImage: "checklist"),
        .init(text: "Grade Travis Etienne for Ja'Marr Chase", systemImage: "arrow.left.arrow.right"),
        .init(text: "Who's the top waiver add this week?", systemImage: "hand.raised"),
        .init(text: "Best dynasty buy right now?", systemImage: "building.columns"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(messages) { msg in messageView(msg).id(msg.id) }
                        if isThinking { TypingBubble().id("typing") }
                        if messages.count <= 1 { promptSuggestions }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }
            if !state.isPremium { usageBar }
            inputBar
        }
        .screenBackground()
        .navigationTitle("AI Coach")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func messageView(_ msg: ChatMessage) -> some View {
        if let answer = msg.answer { AnswerCardView(answer: answer) } else { ChatBubble(message: msg) }
    }

    private var promptSuggestions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DSEyebrow(text: "Try asking")
            ForEach(prompts) { p in
                Button { send(p.text) } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: p.systemImage).font(.system(size: 15)).foregroundStyle(Theme.Colors.accent).frame(width: 22)
                        Text(p.text).dsBody().foregroundStyle(Theme.Colors.textPrimary).multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .card(padding: Theme.Spacing.md)
                }
            }
        }
    }

    private var usageBar: some View {
        HStack {
            Image(systemName: "bolt.fill").font(.system(size: 12)).foregroundStyle(Theme.Colors.accentSecondary)
            Text("\(max(0, state.freeAIDailyLimit - state.aiMessagesUsedToday)) free questions left today").dsCaption()
            Spacer()
            Button("Go Unlimited") { showPaywall = true }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.surface)
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Ask your coach…", text: $input, axis: .vertical)
                .focused($focused)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 11)
                .background(Theme.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Theme.Colors.strokeSoft, lineWidth: 1))
            Button { send(input) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.textTertiary : Theme.Colors.accent)
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.background)
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard state.canUseAI() else { showPaywall = true; return }

        focused = false
        input = ""
        messages.append(ChatMessage(role: .user, text: trimmed))
        state.registerAIUsage()
        isThinking = true

        let metrics = state.playerMetrics
        let pool = state.metricsForWaiverPool()
        let ctx = state.engineContext
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let answer = AIAssistant.answer(to: trimmed, metrics: metrics, waiverPool: pool, context: ctx)
            isThinking = false
            messages.append(ChatMessage(role: .assistant, text: answer.finalCall, answer: answer))
        }
    }
}

// MARK: - Structured answer card
struct AnswerCardView: View {
    let answer: AssistantAnswer

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header
            if !answer.dataAvailable {
                unavailableBanner
            } else if answer.modelScore != nil {
                scoreRow
            }
            if !answer.missingDataWarnings.isEmpty { warningsBanner }
            dataUpdatedRow

            if !answer.keyMetrics.isEmpty {
                section("Key Metrics") {
                    VStack(spacing: 0) { ForEach(answer.keyMetrics) { metricRow($0) } }
                }
            }
            if !answer.riskFactors.isEmpty {
                section("Risk Factors") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(answer.riskFactors, id: \.self) { bulletLine($0) }
                    }
                }
            }
            section("AI Explanation") {
                Text(answer.aiExplanation).dsBody().fixedSize(horizontal: false, vertical: true)
            }
            caldwellTake
        }
        .card()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 24, height: 24).background(Theme.Colors.accent).clipShape(Circle())
                DSEyebrow(text: answer.kind?.rawValue ?? "AI Coach")
                Spacer()
                if let tag = answer.verdictTag { Tag(text: tag, color: verdictColor(tag), filled: true) }
            }
            Text(answer.finalCall).dsSectionTitle().fixedSize(horizontal: false, vertical: true)
        }
    }

    private func verdictColor(_ tag: String) -> Color {
        switch tag {
        case "START", "ADD", "DRAFT", "BUY", "KEEP", "ACCEPT": return Theme.Colors.accent
        case "DECLINE": return Theme.Colors.negative
        case "NO DATA": return Theme.Colors.textTertiary
        default: return Theme.Colors.accentSecondary
        }
    }

    private var scoreRow: some View {
        HStack(spacing: Theme.Spacing.lg) {
            if let score = answer.modelScore { GradeRing(score: score, size: 64, label: "MODEL") }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Confidence").dsCallout()
                    Spacer()
                    Text("\(Int(answer.confidence.rounded()))%").dsNumeric(14, color: Theme.Colors.grade(answer.confidence))
                }
                ProgressBar(fraction: answer.confidence / 100, tint: Theme.Colors.grade(answer.confidence))
                if answer.confidence < 60 {
                    Text("Close call — lean on roster needs").dsCaption().foregroundStyle(Theme.Colors.warning)
                }
            }
        }
    }

    private var unavailableBanner: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.Colors.warning)
            Text("Current data unavailable — no guess provided.").dsCallout().foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.warning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private var warningsBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(answer.missingDataWarnings, id: \.self) { w in
                Label(w, systemImage: "exclamationmark.circle.fill").dsCaption().foregroundStyle(Theme.Colors.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private var dataUpdatedRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
            Text("Data last updated: \(dataUpdatedString)").dsCaption()
            Spacer()
        }
    }

    private var dataUpdatedString: String {
        if !answer.dataAvailable { return "Current data unavailable" }
        guard let d = answer.dataLastUpdated else { return "—" }
        let f = DateFormatter(); f.dateFormat = "MMM d, h:mm a"
        return f.string(from: d)
    }

    private func metricRow(_ m: KeyMetric) -> some View {
        let color: Color
        switch m.sentiment {
        case .positive: color = Theme.Colors.positive
        case .neutral: color = Theme.Colors.textSecondary
        case .negative: color = Theme.Colors.negative
        }
        return HStack(spacing: Theme.Spacing.sm) {
            Text(m.label).dsCallout()
            Spacer()
            Text(m.value).dsNumeric(14)
            Tag(text: m.note, color: color, filled: m.sentiment != .neutral)
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.vertical, 9)
        .overlay(Divider().overlay(Theme.Colors.strokeSoft), alignment: .bottom)
    }

    private func bulletLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(Theme.Colors.warning).frame(width: 5, height: 5).padding(.top, 6)
            Text(text).dsCallout().fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var caldwellTake: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                DSEyebrow(text: "Caldwell Take", color: Theme.Colors.accentSecondary)
                Spacer()
                Tag(text: "Soon", color: Theme.Colors.accentSecondary)
            }
            Text(answer.caldwellTake).dsCallout().fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DSEyebrow(text: title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chat bubble (intro / guidance)
struct ChatBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == .user }
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if isUser { Spacer(minLength: 40) }
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 26, height: 26).background(Theme.Colors.accent).clipShape(Circle())
            }
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(isUser ? .black : Theme.Colors.textPrimary)
                .padding(Theme.Spacing.md)
                .background(isUser ? Theme.Colors.accent : Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.Colors.stroke, lineWidth: isUser ? 0 : 1))
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

struct TypingBubble: View {
    @State private var phase = 0.0
    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle().fill(Theme.Colors.textSecondary).frame(width: 7, height: 7)
                        .opacity(phase == Double(i) ? 1 : 0.3)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            Spacer()
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever()) { phase = 2 } }
    }
}
