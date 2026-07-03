import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var state: AppState
    @Binding var showPaywall: Bool

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isThinking = false
    @FocusState private var focused: Bool

    private let askPrompts = [
        "Who should I start at WR2?",
        "Analyze my trade value",
        "Best waiver pickups",
        "Playoff schedule outlook",
    ]
    private let deepDives = [
        "Matchup-by-matchup playoff path analysis",
        "Full roster trade value index",
        "Waiver wire priority list, ranked by impact",
    ]

    var body: some View {
        VStack(spacing: 0) {
            header.padding(.horizontal, Theme.Spacing.lg).padding(.top, Theme.Spacing.sm)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        if messages.isEmpty {
                            analysisCard.appear()
                            askMeSection.appear(delay: 0.05)
                            deepDivesCard.appear(delay: 0.1)
                        } else {
                            ForEach(messages) { msg in messageView(msg).id(msg.id) }
                            if isThinking { TypingBubble().id("typing") }
                        }
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
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            DiamondLogo(size: 38)
            VStack(alignment: .leading, spacing: 2) {
                DSEyebrow(text: "AI Offensive Coordinator")
                Text("Caldwell IQ").dsScreenTitle()
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(Theme.Colors.positive).frame(width: 6, height: 6)
                Text("LIVE").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.Colors.positive)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .overlay(Capsule().strokeBorder(Theme.Colors.positive.opacity(0.5), lineWidth: 1))
        }
    }

    // MARK: Landing — week analysis + radar + recommendations
    private var analysisCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.accent)
                DSEyebrow(text: "Week \(coach.week) Analysis", color: Theme.Colors.accent)
            }
            Text(coach.analysis).dsBody().fixedSize(horizontal: false, vertical: true)

            DSEyebrow(text: "Team Comparison")
            RadarChart(labels: ["Offense", "Depth", "Consist.", "Ceiling", "Floor"],
                       seriesA: coach.userRadar, seriesB: coach.oppRadar)
                .frame(height: 190)
            HStack(spacing: Theme.Spacing.lg) {
                legend(color: Theme.Colors.accent, text: coach.userName)
                legend(color: Theme.Colors.info, text: coach.oppName)
                Spacer()
            }

            Divider().overlay(Theme.Colors.strokeSoft)
            ForEach(state.startSit.prefix(3)) { advice in CoachRecRow(advice: advice) }
        }
        .glassCard(radius: 20, hero: true)
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 14, height: 3)
            Text(text).dsCaption()
        }
    }

    private var askMeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DSEyebrow(text: "Ask Me Anything")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.sm),
                                GridItem(.flexible(), spacing: Theme.Spacing.sm)],
                      spacing: Theme.Spacing.sm) {
                ForEach(askPrompts, id: \.self) { prompt in
                    Button { send(prompt) } label: {
                        Text(prompt)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 8)
                            .background(Theme.Colors.surfaceElevated, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.Colors.stroke, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var deepDivesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.accent)
                DSEyebrow(text: "Suggested Deep Dives", color: Theme.Colors.accent)
            }
            ForEach(Array(deepDives.enumerated()), id: \.offset) { idx, dive in
                Button { send(dive) } label: {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        Text("\(idx + 1)").dsNumeric(14, color: Theme.Colors.accent).frame(width: 18)
                        Text(dive).dsBody().foregroundStyle(Theme.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .glassCard(radius: 18)
    }

    // MARK: Chat plumbing (preserved)
    @ViewBuilder
    private func messageView(_ msg: ChatMessage) -> some View {
        if let answer = msg.answer { AnswerCardView(answer: answer) } else { ChatBubble(message: msg) }
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
        .padding(.horizontal, Theme.Spacing.lg).padding(.vertical, Theme.Spacing.sm)
    }

    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(Theme.Colors.accent)
            TextField("Ask your AI coordinator…", text: $input, axis: .vertical)
                .focused($focused)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Colors.textPrimary)
            Button { send(input) } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty ? Theme.Colors.textTertiary : Theme.Colors.accent)
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .background(Theme.Colors.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).strokeBorder(Theme.Colors.stroke, lineWidth: 1))
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
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

    // MARK: Derived coach summary
    private var coach: CoachSummary { CoachSummary(state: state) }
}

// MARK: - Coach summary (derived from existing data)
private struct CoachSummary {
    let week: Int
    let analysis: String
    let userName: String
    let oppName: String
    let userRadar: [Double]
    let oppRadar: [Double]

    @MainActor
    init(state: AppState) {
        let league = state.selectedLeague
        week = league?.currentWeek ?? 11
        let user = league?.userTeam
        let opp = league?.standings.first(where: { !$0.isUser })
        userName = user?.name ?? "My Team"
        oppName = opp?.name ?? "Opponent"

        func avg(_ t: FantasyTeam?) -> Double { guard let t else { return 0 }; return t.pointsFor / Double(max(1, t.wins + t.losses)) }
        let diff = avg(user) - avg(opp)
        let prob = max(1, min(99, Int((50 + diff * 2.2).rounded())))
        let decisions = state.startSit.count
        let verb = diff >= 0 ? "win" : "lose"
        analysis = "I've analyzed your Week \(week) roster. You're projected to \(verb) by \(String(format: "%.1f", abs(diff))) points with \(prob)% confidence. \(decisions) high-impact decisions need attention before Sunday's 1pm lock."

        func radar(_ t: FantasyTeam?) -> [Double] {
            guard let t else { return [0.5, 0.5, 0.5, 0.5, 0.5] }
            let offense = t.pointsFor / (Double(max(1, t.wins + t.losses)) * 160)
            let depth = t.dynastyValue / 100
            let consistency = t.powerScore / 100
            let ceiling = t.championshipOdds / 25
            let floor = t.playoffOdds / 100
            return [offense, depth, consistency, ceiling, floor].map { min(1, max(0.12, $0)) }
        }
        userRadar = radar(user)
        oppRadar = radar(opp)
    }
}

// MARK: - Recommendation row
struct CoachRecRow: View {
    let advice: StartSitAdvice
    private var pill: (String, Color) {
        switch advice.recommendation {
        case "Start": return ("START", Theme.Colors.accent)
        case "Sit": return ("BENCH", Theme.Colors.negative)
        default: return ("FLEX", Theme.Colors.info)
        }
    }
    private var pctColor: Color { advice.recommendation == "Sit" ? Theme.Colors.negative : Theme.Colors.positive }
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Tag(text: pill.0, color: pill.1, filled: true)
            Text(advice.playerName).dsCardTitle()
            Spacer()
            Text("\(Int(advice.confidence))%").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(pctColor)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Radar / pentagon chart
struct RadarChart: View {
    let labels: [String]
    let seriesA: [Double]
    let seriesB: [Double]
    var colorA: Color = Theme.Colors.accent
    var colorB: Color = Theme.Colors.info

    var body: some View {
        GeometryReader { geo in
            let n = max(3, labels.count)
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = side / 2 - 22

            ZStack {
                ForEach(1...3, id: \.self) { ring in
                    ringPath(center: c, radius: r * CGFloat(ring) / 3, n: n)
                        .stroke(Theme.Colors.stroke.opacity(0.55), lineWidth: 1)
                }
                ForEach(0..<n, id: \.self) { i in
                    Path { p in p.move(to: c); p.addLine(to: vertex(c, r, n, i, 1)) }
                        .stroke(Theme.Colors.stroke.opacity(0.45), lineWidth: 1)
                }
                seriesPath(center: c, radius: r, n: n, values: seriesB).fill(colorB.opacity(0.18))
                seriesPath(center: c, radius: r, n: n, values: seriesB).stroke(colorB, lineWidth: 1.5)
                seriesPath(center: c, radius: r, n: n, values: seriesA).fill(colorA.opacity(0.22))
                seriesPath(center: c, radius: r, n: n, values: seriesA).stroke(colorA, lineWidth: 1.5)
                ForEach(0..<n, id: \.self) { i in
                    Text(labels[i])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .position(vertex(c, r + 14, n, i, 1))
                }
            }
        }
    }

    private func vertex(_ center: CGPoint, _ radius: CGFloat, _ n: Int, _ i: Int, _ frac: Double) -> CGPoint {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(i) / Double(n)
        return CGPoint(x: center.x + cos(angle) * radius * CGFloat(frac),
                       y: center.y + sin(angle) * radius * CGFloat(frac))
    }
    private func ringPath(center: CGPoint, radius: CGFloat, n: Int) -> Path {
        Path { p in
            for i in 0..<n {
                let pt = vertex(center, radius, n, i, 1)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
    }
    private func seriesPath(center: CGPoint, radius: CGFloat, n: Int, values: [Double]) -> Path {
        Path { p in
            for i in 0..<n {
                let v = i < values.count ? values[i] : 0
                let pt = vertex(center, radius, n, i, max(0.05, min(1, v)))
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
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
                    VStack(alignment: .leading, spacing: 6) { ForEach(answer.riskFactors, id: \.self) { bulletLine($0) } }
                }
            }
            section("AI Explanation") {
                Text(answer.aiExplanation).dsBody().fixedSize(horizontal: false, vertical: true)
            }
            caldwellTake
        }
        .glassCard(radius: 18)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
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
            Tag(text: m.note, color: color, filled: m.sentiment != .neutral).frame(width: 78, alignment: .trailing)
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

// MARK: - Chat bubble
struct ChatBubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == .user }
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if isUser { Spacer(minLength: 40) }
            if !isUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 26, height: 26).background(Theme.Colors.accent).clipShape(Circle())
            }
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(isUser ? .white : Theme.Colors.textPrimary)
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
