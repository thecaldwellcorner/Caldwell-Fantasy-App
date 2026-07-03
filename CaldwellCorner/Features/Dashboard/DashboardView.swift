import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var games: GameCenterStore
    @Binding var showPaywall: Bool
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                if isLoading {
                    loadingState
                } else {
                    matchupCard.appear()
                    if games.hasLiveGames { liveSection.appear(delay: 0.04) }
                    insightsSection.appear(delay: 0.08)
                    quickActions.appear(delay: 0.12)
                    seasonScoring.appear(delay: 0.16)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            games.subscribe()
            guard isLoading else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(Theme.Anim.standard) { isLoading = false }
            }
        }
        .onDisappear { games.unsubscribe() }
    }

    // MARK: Header
    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            DiamondLogo(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                DSEyebrow(text: "Week \(state.selectedLeague?.currentWeek ?? 11) · 2024")
                Text("My Dashboard").dsScreenTitle()
            }
            Spacer()
            NavigationLink { PlayerDatabaseView().navigationTitle("Players").navigationBarTitleDisplayMode(.inline) } label: {
                CircleIcon(system: "magnifyingglass")
            }
            NavigationLink { NotificationsView() } label: {
                CircleIcon(system: "bell")
            }
            NavigationLink { ProfileView(showPaywall: $showPaywall) } label: {
                Text(state.profile.displayName.initials)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.accent.opacity(0.85), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            }
        }
    }

    // MARK: Current matchup
    private var matchup: MatchupSummary { MatchupSummary(state: state) }

    private var matchupCard: some View {
        let m = matchup
        return VStack(spacing: Theme.Spacing.lg) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(Theme.Colors.positive).frame(width: 7, height: 7)
                    DSEyebrow(text: "Current Matchup")
                }
                Spacer()
                Text("Week \(m.week)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .overlay(Capsule().strokeBorder(Theme.Colors.accent.opacity(0.5), lineWidth: 1))
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.userName).dsCallout()
                    BigScore(value: m.userScore, dimmed: false)
                    Text(m.userLine).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.positive)
                }
                Spacer()
                Text("vs").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.top, 26)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(m.oppName).dsCallout()
                    BigScore(value: m.oppScore, dimmed: true)
                    Text(m.oppLine).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            VStack(spacing: 8) {
                HStack {
                    DSEyebrow(text: "Win Probability")
                    Spacer()
                    Text("\(m.winProb)%").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.positive)
                }
                ProgressBar(fraction: Double(m.winProb) / 100, tint: Theme.Colors.accent)
            }

            HStack(spacing: 0) {
                statCell("AI Conf", m.aiConf, Theme.Colors.accent)
                statDivider
                statCell("Proj Δ", m.projDelta, Theme.Colors.positive)
                statDivider
                statCell("Injuries", m.injuriesLabel, Theme.Colors.accentSecondary)
                statDivider
                statCell("Weather", m.weather, Theme.Colors.info)
            }
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.background.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.Colors.stroke.opacity(0.7), lineWidth: 1))
        }
        .glassCard(radius: 22, hero: true)
    }

    private var statDivider: some View {
        Rectangle().fill(Theme.Colors.stroke).frame(width: 1, height: 30)
    }

    private func statCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            DSEyebrow(text: label)
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(color).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Live NFL
    private var liveSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            sectionHeader(dotColor: Theme.Colors.negative, title: "Live NFL", link: "All Games") {
                GameCenterView()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(games.liveGames) { game in
                        NavigationLink { GameDetailView(gameID: game.id) } label: { LiveGameChip(game: game) }
                    }
                }
            }
        }
    }

    // MARK: AI Insights
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            iconSectionHeader(icon: "sparkles", title: "AI Insights", link: "AI Coach") {
                AIAssistantView(showPaywall: $showPaywall)
            }
            VStack(spacing: Theme.Spacing.md) {
                ForEach(state.startSit.prefix(3)) { advice in
                    InsightCard(advice: advice)
                }
            }
        }
    }

    // MARK: Quick actions
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Quick Actions").dsSectionTitle()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md),
                                GridItem(.flexible(), spacing: Theme.Spacing.md),
                                GridItem(.flexible(), spacing: Theme.Spacing.md)],
                      spacing: Theme.Spacing.md) {
                NavigationLink { TradeAnalyzerView() } label: { QuickTile("Trade", "arrow.left.arrow.right", Theme.Colors.accent) }
                NavigationLink { StartSitView() } label: { QuickTile("Start/Sit", "target", Theme.Colors.positive) }
                NavigationLink { WaiverView() } label: { QuickTile("Waivers", "arrow.up.right", Theme.Colors.info) }
                NavigationLink { RankingsView() } label: { QuickTile("Rankings", "chart.bar.fill", Theme.Colors.accent) }
                NavigationLink { DraftCenterView() } label: { QuickTile("Mock Draft", "shield.lefthalf.filled", Theme.Colors.accent) }
                NavigationLink { AIAssistantView(showPaywall: $showPaywall) } label: { QuickTile("AI Coach", "sparkles", Theme.Colors.accent) }
            }
        }
    }

    // MARK: Season scoring
    private var seasonScoring: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Season Scoring").dsSectionTitle()
                Spacer()
                Text("Avg \(matchup.seasonAvg)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.accent)
            }
            SeasonChart(values: matchup.weeklySeries)
                .frame(height: 120)
                .glassCard(padding: Theme.Spacing.md, radius: 18)
        }
    }

    // MARK: Section header helpers
    private func sectionHeader<D: View>(dotColor: Color, title: String, link: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dotColor).frame(width: 7, height: 7)
            Text(title).dsSectionTitle()
            Spacer()
            NavigationLink { destination() } label: {
                Text("\(link) →").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.accent)
            }
        }
    }

    private func iconSectionHeader<D: View>(icon: String, title: String, link: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.accent)
            Text(title).dsSectionTitle()
            Spacer()
            NavigationLink { destination() } label: {
                Text("\(link) →").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.accent)
            }
        }
    }

    // MARK: Loading
    private var loadingState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SkeletonView(cornerRadius: Theme.Radius.card).frame(height: 230)
            SkeletonView().frame(width: 140, height: 16)
            SkeletonView(cornerRadius: Theme.Radius.card).frame(height: 96)
            SkeletonView(cornerRadius: Theme.Radius.card).frame(height: 96)
        }
    }
}

// MARK: - Matchup summary (derived from existing data)
private struct MatchupSummary {
    let week: Int
    let userName: String
    let oppName: String
    let userScore: Double
    let oppScore: Double
    let userLine: String
    let oppLine: String
    let winProb: Int
    let aiConf: String
    let projDelta: String
    let injuriesLabel: String
    let weather: String
    let seasonAvg: String
    let weeklySeries: [Double]

    @MainActor
    init(state: AppState) {
        let league = state.selectedLeague
        week = league?.currentWeek ?? 11
        let user = league?.userTeam
        let standings = league?.standings ?? []
        let opp = standings.first(where: { !$0.isUser })

        func avg(_ t: FantasyTeam?) -> Double {
            guard let t else { return 0 }
            return t.pointsFor / Double(max(1, t.wins + t.losses))
        }
        let us = avg(user)
        let them = avg(opp)
        userScore = (us * 10).rounded() / 10
        oppScore = (them * 10).rounded() / 10
        userName = user?.name ?? "My Team"
        oppName = opp?.name ?? "Opponent"

        let prob = max(1, min(99, Int((50 + (us - them) * 2.2).rounded())))
        winProb = prob
        userLine = "\(user?.wins ?? 0)-\(user?.losses ?? 0)-0 · \(prob >= 50 ? "Proj Win" : "Underdog")"
        let oppRank = (standings.firstIndex(where: { $0.id == opp?.id }) ?? 0) + 1
        oppLine = "\(opp?.wins ?? 0)-\(opp?.losses ?? 0)-0 · #\(oppRank) Seed"

        aiConf = prob >= 65 ? "HIGH" : prob >= 50 ? "LEAN" : "TOSS-UP"
        let delta = us - them
        projDelta = "\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta))"

        let injuries = user.map { state.rosterPlayers(for: $0).filter { $0.player.injuryStatus.isConcern }.count } ?? 0
        injuriesLabel = injuries > 0 ? "\(injuries) ⚠" : "0"
        weather = state.startSit.first?.weather ?? "Clear"

        seasonAvg = String(format: "%.1f", us)
        // Deterministic weekly series around the average for the season chart.
        var out: [Double] = []
        for w in 2...max(3, week) {
            let wobble = Double(((w * 53) % 34)) - 16   // -16…17
            out.append(max(60, us + wobble))
        }
        weeklySeries = out
    }
}

// MARK: - Home components
struct DiamondLogo: View {
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accentDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.72, height: size * 0.72)
                .rotationEffect(.degrees(45))
                .shadow(color: Theme.Colors.accent.opacity(0.55), radius: 9, y: 3)
            Text("IQ").font(.system(size: size * 0.3, weight: .heavy)).foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct CircleIcon: View {
    let system: String
    var body: some View {
        Image(systemName: system)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: 40, height: 40)
            .background(.ultraThinMaterial, in: Circle())
            .background(Theme.Colors.surface.opacity(0.55), in: Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }
}

struct BigScore: View {
    let value: Double
    let dimmed: Bool
    private var parts: (String, String) {
        let s = String(format: "%.1f", value)
        let comps = s.split(separator: ".")
        return (String(comps.first ?? "0"), "." + String(comps.count > 1 ? comps[1] : "0"))
    }
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(parts.0).font(.system(size: 44, weight: .heavy))
            Text(parts.1).font(.system(size: 22, weight: .heavy))
        }
        .foregroundStyle(dimmed ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
    }
}

struct LiveGameChip: View {
    let game: NFLGame
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 5) {
                Text("\(game.periodLabel) \(game.clockLabel)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.negative)
                Spacer()
                Circle().fill(Theme.Colors.negative).frame(width: 6, height: 6)
            }
            teamRow(game.away)
            teamRow(game.home)
        }
        .frame(width: 128)
        .glassCard(padding: Theme.Spacing.md, radius: 16)
    }
    private func teamRow(_ t: GameTeam) -> some View {
        HStack {
            Text(t.abbr).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Text("\(t.score)").dsNumeric(15)
        }
    }
}

struct InsightCard: View {
    let advice: StartSitAdvice
    private var pill: (String, Color) {
        switch advice.recommendation {
        case "Start": return ("START", Theme.Colors.accent)
        case "Sit": return ("BENCH", Theme.Colors.negative)
        default: return ("FLEX", Theme.Colors.info)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                Tag(text: pill.0, color: pill.1, filled: true)
                Text("\(advice.position.rawValue) · \(advice.team)").dsCaption()
                Spacer()
            }
            Text(advice.playerName).dsCardTitle()
            Text(advice.reasoning).dsCallout().lineLimit(2)
            HStack(spacing: Theme.Spacing.md) {
                ProgressBar(fraction: advice.confidence / 100, tint: pill.1)
                Text("\(Int(advice.confidence))%").font(.system(size: 13, weight: .bold)).foregroundStyle(pill.1)
            }
        }
        .glassCard(radius: 18)
    }
}

struct QuickTile: View {
    let title: String
    let icon: String
    let tint: Color
    init(_ title: String, _ icon: String, _ tint: Color) {
        self.title = title; self.icon = icon; self.tint = tint
    }
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 82)
        .glassCard(padding: Theme.Spacing.md, radius: 16)
    }
}

struct SeasonChart: View {
    let values: [Double]
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height - 20
            let minV = (values.min() ?? 0) - 6
            let maxV = (values.max() ?? 1) + 6
            let span = max(1, maxV - minV)
            let step = values.count > 1 ? w / CGFloat(values.count - 1) : w

            ZStack {
                // Line
                Path { p in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - CGFloat((v - minV) / span) * h
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                // Fill under line
                Path { p in
                    guard !values.isEmpty else { return }
                    p.move(to: CGPoint(x: 0, y: h))
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - CGFloat((v - minV) / span) * h
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: CGFloat(values.count - 1) * step, y: h))
                    p.closeSubpath()
                }
                .fill(Theme.Colors.accent.opacity(0.12))

                // Week labels
                VStack {
                    Spacer()
                    HStack {
                        ForEach(values.indices, id: \.self) { i in
                            Text("W\(i + 2)").font(.system(size: 8)).foregroundStyle(Theme.Colors.textTertiary)
                            if i < values.count - 1 { Spacer() }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - News row (shared with News Center)
struct NewsRow: View {
    let item: NewsItem
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: stockIcon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(stockColor)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 5) {
                if item.isBreaking { Tag(text: "Breaking", color: Theme.Colors.negative, filled: true) }
                Text(item.headline).dsCardTitle().multilineTextAlignment(.leading)
                Text("\(item.source) · \(item.timestamp.relativeShort)").dsCaption()
            }
            Spacer(minLength: 0)
        }
        .card(padding: Theme.Spacing.md)
    }
    private var stockColor: Color {
        switch item.fantasyImpact {
        case "Stock Up": return Theme.Colors.positive
        case "Stock Down": return Theme.Colors.negative
        default: return Theme.Colors.textSecondary
        }
    }
    private var stockIcon: String {
        switch item.fantasyImpact {
        case "Stock Up": return "chart.line.uptrend.xyaxis"
        case "Stock Down": return "chart.line.downtrend.xyaxis"
        default: return "minus"
        }
    }
}
