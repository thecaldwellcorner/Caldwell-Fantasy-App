import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var state: AppState
    @Binding var showPaywall: Bool

    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, text: "Hey! I'm your Caldwell Corner AI assistant. I'm grounded in our player database, so I won't make up stats. Ask me to grade a trade, set your start/sit, find waiver adds, or evaluate any player.")
    ]
    @State private var input = ""
    @State private var isThinking = false
    @FocusState private var focused: Bool

    private let prompts = MockData.suggestedPrompts()

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg).id(msg.id)
                        }
                        if isThinking { TypingBubble().id("typing") }
                        if messages.count <= 1 { promptSuggestions }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }

            if !state.isPremium {
                usageBar
            }

            inputBar
        }
        .screenBackground()
        .navigationTitle("AI Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var promptSuggestions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Try asking")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
            ForEach(prompts) { p in
                Button { send(p.text) } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: p.systemImage)
                            .foregroundStyle(Theme.Colors.accent)
                        Text(p.text)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .card(padding: Theme.Spacing.md)
                }
            }
        }
    }

    private var usageBar: some View {
        HStack {
            Image(systemName: "bolt.fill").foregroundStyle(Theme.Colors.accentSecondary)
            Text("\(max(0, state.freeAIDailyLimit - state.aiMessagesUsedToday)) free messages left today")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Button("Go Unlimited") { showPaywall = true }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.Colors.accent)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.surface)
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("Ask anything…", text: $input, axis: .vertical)
                .focused($focused)
                .lineLimit(1...4)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
            Button { send(input) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
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

        guard state.canUseAI() else {
            showPaywall = true
            return
        }

        focused = false
        input = ""
        messages.append(ChatMessage(role: .user, text: trimmed))
        state.registerAIUsage()
        isThinking = true

        let snapshotPlayers = state.players
        let league = state.selectedLeague
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            let reply = AIAssistant.respond(to: trimmed, players: snapshotPlayers, league: league)
            isThinking = false
            messages.append(ChatMessage(role: .assistant, text: reply))
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == .user }
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if isUser { Spacer(minLength: 40) }
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(Theme.Colors.accent)
                    .clipShape(Circle())
            }
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(isUser ? .black : Theme.Colors.textPrimary)
                .padding(Theme.Spacing.md)
                .background(isUser ? Theme.Colors.accent : Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.Colors.stroke, lineWidth: isUser ? 0 : 1))
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
                    Circle()
                        .fill(Theme.Colors.textSecondary)
                        .frame(width: 7, height: 7)
                        .opacity(phase == Double(i) ? 1 : 0.3)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { phase = 2 }
        }
    }
}
