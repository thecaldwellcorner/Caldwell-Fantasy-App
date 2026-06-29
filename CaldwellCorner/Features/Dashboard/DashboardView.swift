import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var games: GameCenterStore
    @Binding var showPaywall: Bool
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if isLoading {
                    loadingState
                } else {
                    content
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .onAppear {
            games.subscribe()
            guard isLoading else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(Theme.Anim.standard) { isLoading = false }
            }
        }
        .onDisappear { games.unsubscribe() }
        .screenBackground()
        .navigationTitle("Caldwell Corner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink { ProfileView(showPaywall: $showPaywall) } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { NotificationsView() } label: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            header.appear(delay: 0.0)

            if games.hasLiveGames { liveStrip.appear(delay: 0.03) }

            if let league = state.selectedLeague, let team = league.userTeam {
                teamSummary(league: league, team: team).appear(delay: 0.05)
            }

            quickActions.appear(delay: 0.10)
            breakingNews.appear(delay: 0.15)
            trendingPlayers.appear(delay: 0.20)

            if !state.isPremium { upsell.appear(delay: 0.25) }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SkeletonView().frame(width: 220, height: 26)
            SkeletonView(cornerRadius: Theme.Radius.card).frame(height: 150)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonView(cornerRadius: Theme.Radius.card).frame(height: 92)
                }
            }
            SkeletonCard()
            SkeletonCard()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome back, \(state.profile.displayName)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Your fantasy football operating system")
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func teamSummary(league: League, team: FantasyTeam) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Label(league.name, systemImage: league.platform.systemImage)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Text("\(team.wins)-\(team.losses)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.accent)
            }
            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "Power", value: "\(Int(team.powerScore))", tint: Theme.Colors.grade(team.powerScore))
                MetricChip(label: "Playoff %", value: "\(Int(team.playoffOdds))%", tint: Theme.Colors.info)
                MetricChip(label: "Title %", value: "\(Int(team.championshipOdds))%", tint: Theme.Colors.accentSecondary)
                MetricChip(label: "PF", value: String(format: "%.0f", team.pointsFor))
            }
            NavigationLink {
                LeagueDashboardView()
            } label: {
                HStack {
                    Text("View Team & League Dashboard")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .card(elevated: true)
    }

    private var liveStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 8) {
                LivePulse()
                SectionHeader(title: "Live Now")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(games.liveGames) { game in
                        NavigationLink { GameDetailView(gameID: game.id) } label: {
                            MiniGameCard(game: game)
                        }
                    }
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Quick Actions")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                NavigationLink { AIAssistantView(showPaywall: $showPaywall) } label: {
                    QuickActionCard(title: "AI Assistant", subtitle: "Ask anything", icon: "sparkles", tint: Theme.Colors.accent)
                }
                NavigationLink { TradeAnalyzerView() } label: {
                    QuickActionCard(title: "Trade Analyzer", subtitle: "Grade a deal", icon: "arrow.left.arrow.right", tint: Theme.Colors.info)
                }
                NavigationLink { StartSitView() } label: {
                    QuickActionCard(title: "Start / Sit", subtitle: "Set lineup", icon: "checklist", tint: Theme.Colors.accentSecondary)
                }
                NavigationLink { WaiverView() } label: {
                    QuickActionCard(title: "Waivers", subtitle: "Top adds", icon: "hand.raised.fill", tint: Theme.Colors.positive)
                }
            }
        }
    }

    private var breakingNews: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Breaking News", actionLabel: "All") { }
            ForEach(state.news.prefix(3)) { item in
                NavigationLink { NewsDetailView(item: item) } label: {
                    NewsRow(item: item)
                }
            }
        }
    }

    private var trendingPlayers: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Trending Up")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(state.players.filter { $0.rankTrend > 0 }.sorted { $0.rankTrend > $1.rankTrend }.prefix(6)) { p in
                        NavigationLink { PlayerDetailView(player: p) } label: {
                            TrendingPlayerCard(player: p)
                        }
                    }
                }
            }
        }
    }

    private var upsell: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.black)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go Premium")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                    Text("Unlimited AI, dynasty tools, draft guide & no ads")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.black.opacity(0.7))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.black)
            }
            .padding(Theme.Spacing.lg)
            .background(
                LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accentSecondary],
                               startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }
}

// MARK: - Subcomponents
struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: Theme.Spacing.md)
    }
}

struct TrendingPlayerCard: View {
    let player: Player
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                PlayerAvatar(name: player.name, position: player.position.rawValue, size: 38)
                Spacer()
                TrendIndicator(value: player.rankTrend)
            }
            Text(player.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
            HStack(spacing: 6) {
                PositionBadge(position: player.position.rawValue, compact: true)
                Text(player.team)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .frame(width: 150, alignment: .leading)
        .card(padding: Theme.Spacing.md)
    }
}

struct NewsRow: View {
    let item: NewsItem
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack {
                Image(systemName: stockIcon)
                    .foregroundStyle(stockColor)
                    .font(.system(size: 18, weight: .bold))
            }
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                if item.isBreaking {
                    Text("BREAKING")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.Colors.negative)
                        .clipShape(Capsule())
                }
                Text(item.headline)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(item.source + " · " + item.timestamp.relativeShort)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textTertiary)
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

