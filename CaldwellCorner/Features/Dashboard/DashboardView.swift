import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var games: GameCenterStore
    @Binding var showPaywall: Bool
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if isLoading { loadingState } else { content }
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
                    Image(systemName: "person.crop.circle").foregroundStyle(Theme.Colors.textPrimary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { NotificationsView() } label: {
                    Image(systemName: "bell").foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            header.appear()
            if games.hasLiveGames { liveStrip.appear(delay: 0.03) }
            if let league = state.selectedLeague, let team = league.userTeam {
                teamSummary(league: league, team: team).appear(delay: 0.05)
            }
            quickActions.appear(delay: 0.08)
            breakingNews.appear(delay: 0.11)
            trendingPlayers.appear(delay: 0.14)
            if !state.isPremium { upsell.appear(delay: 0.17) }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SkeletonView().frame(width: 220, height: 24)
            SkeletonView(cornerRadius: Theme.Radius.card).frame(height: 148)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonView(cornerRadius: Theme.Radius.card).frame(height: 92)
                }
            }
            SkeletonCard(); SkeletonCard()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome back, \(state.profile.displayName)").dsScreenTitle()
            Text("Your fantasy football command center").dsBody()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func teamSummary(league: League, team: FantasyTeam) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(team.name).dsSectionTitle()
                    Label(league.name, systemImage: league.platform.systemImage).dsCaption()
                }
                Spacer()
                Text("\(team.wins)-\(team.losses)").dsNumeric(22, color: Theme.Colors.accent)
            }
            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "Power", value: "\(Int(team.powerScore))", tint: Theme.Colors.grade(team.powerScore))
                MetricChip(label: "Playoff", value: "\(Int(team.playoffOdds))%")
                MetricChip(label: "Title", value: "\(Int(team.championshipOdds))%")
                MetricChip(label: "PF", value: String(format: "%.0f", team.pointsFor))
            }
            NavigationLink { LeagueDashboardView() } label: {
                HStack {
                    Text("Team & League Dashboard")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .card()
    }

    private var liveStrip: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: 8) { LivePulse(); SectionHeader(title: "Live Now") }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(games.liveGames) { game in
                        NavigationLink { GameDetailView(gameID: game.id) } label: { MiniGameCard(game: game) }
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
                    QuickActionCard(title: "AI Coach", subtitle: "Ask anything", icon: "sparkles")
                }
                NavigationLink { TradeAnalyzerView() } label: {
                    QuickActionCard(title: "Trade Analyzer", subtitle: "Grade a deal", icon: "arrow.left.arrow.right")
                }
                NavigationLink { StartSitView() } label: {
                    QuickActionCard(title: "Start / Sit", subtitle: "Set your lineup", icon: "checklist")
                }
                NavigationLink { WaiverView() } label: {
                    QuickActionCard(title: "Waivers", subtitle: "Top adds", icon: "hand.raised")
                }
            }
        }
    }

    private var breakingNews: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "News")
            ForEach(state.news.prefix(3)) { item in
                NavigationLink { NewsDetailView(item: item) } label: { NewsRow(item: item) }
            }
        }
    }

    private var trendingPlayers: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Trending Up")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(state.players.filter { $0.rankTrend > 0 }.sorted { $0.rankTrend > $1.rankTrend }.prefix(6)) { p in
                        NavigationLink { PlayerDetailView(player: p) } label: { TrendingPlayerCard(player: p) }
                    }
                }
            }
        }
    }

    private var upsell: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: Theme.Spacing.md) {
                DSIconBadge(systemName: "crown.fill", tint: Theme.Colors.accentSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Go Premium").dsCardTitle()
                    Text("Unlimited AI, dynasty tools & no ads").dsCaption()
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.Colors.textTertiary)
            }
            .card(padding: Theme.Spacing.md)
        }
    }
}

// MARK: - Subcomponents
struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DSIconBadge(systemName: icon, size: 36)
            Text(title).dsCardTitle()
            Text(subtitle).dsCaption()
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
            Text(player.name).dsCardTitle().lineLimit(1)
            HStack(spacing: 6) {
                PositionBadge(position: player.position.rawValue, compact: true)
                Text(player.team).dsCaption()
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
