import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var state: AppState
    @Binding var showPaywall: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                header
                subscriptionCard
                lifetimeStats
                progressionSection
                watchlistSection
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape").foregroundStyle(Theme.Colors.textPrimary)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.Colors.surfaceElevated)
                    .frame(width: 84, height: 84)
                    .overlay(Circle().strokeBorder(Theme.Colors.accent.opacity(0.6), lineWidth: 2))
                    .overlay(Text(state.profile.displayName.initials).font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.Colors.textPrimary))
                if state.isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12)).foregroundStyle(.black)
                        .padding(6).background(Theme.Colors.accentSecondary).clipShape(Circle())
                }
            }
            Text(state.profile.displayName).dsScreenTitle()
            Text("\(state.profile.handle) · \(state.profile.favoriteTeam)").dsBody()
        }
        .frame(maxWidth: .infinity)
    }

    private var subscriptionCard: some View {
        Group {
            if state.isPremium {
                HStack(spacing: Theme.Spacing.md) {
                    DSIconBadge(systemName: "crown.fill", tint: Theme.Colors.accentSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Member").dsCardTitle()
                        Text("All features unlocked · Annual plan").dsCaption()
                    }
                    Spacer()
                }
                .glassCard(radius: 18)
            } else {
                Button { showPaywall = true } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        DSIconBadge(systemName: "crown.fill", tint: Theme.Colors.accentSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium").dsCardTitle()
                            Text("Unlimited AI · Dynasty tools · Draft Guide").dsCaption()
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .glassCard(padding: Theme.Spacing.md, radius: 18)
                }
            }
        }
    }

    private var lifetimeStats: some View {
        let s = state.progression
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Lifetime Stats")
            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "Total AP", value: "\(s.totalAP)", tint: Theme.Colors.accent)
                MetricChip(label: "Level", value: "\(s.level)")
                MetricChip(label: "Leagues", value: "\(state.profile.lifetimeLeagues)")
                MetricChip(label: "Titles", value: "\(state.profile.championships)", tint: Theme.Colors.accentSecondary)
            }
        }
    }

    private var progressionSection: some View {
        let s = state.progression
        let badges = state.achievements.filter { $0.unlocked }.sorted { $0.rarity.order > $1.rarity.order }.prefix(8)
        let globalRank = state.leaderboard(.global).first(where: { $0.isUser })?.rank

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Progression")

            NavigationLink { AchievementsView() } label: {
                HStack(spacing: Theme.Spacing.md) {
                    LevelBadge(level: s.level, size: 54)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("\(s.totalAP) AP").dsCardTitle()
                            Tag(text: s.levelTitle, color: Theme.Colors.accent, filled: true)
                        }
                        ProgressBar(fraction: s.progressInLevel)
                        Text("\(s.unlockedCount)/\(s.totalCount) unlocked · \(Int(s.completion * 100))%").dsCaption()
                    }
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
                }
                .glassCard(radius: 18)
            }

            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(badges)) { a in
                            DSIconBadge(systemName: a.systemImage, tint: AchievementStyle.color(a.rarity), size: 44)
                        }
                    }
                }
            }

            NavigationLink { LeaderboardView() } label: {
                HStack(spacing: Theme.Spacing.md) {
                    DSIconBadge(systemName: "chart.bar.fill", tint: Theme.Colors.accentSecondary, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leaderboards").dsCardTitle()
                        Text(globalRank.map { "You're #\($0) globally" } ?? "See where you rank").dsCaption()
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
                }
                .glassCard(padding: Theme.Spacing.md, radius: 18)
            }
        }
    }

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Watchlist", subtitle: state.watchlist.isEmpty ? "Star players to track them" : nil)
            if state.watchlist.isEmpty {
                DSEmptyState(icon: "star", title: "No saved players",
                             message: "Tap the star on any player profile to track them here.")
                    .card(padding: Theme.Spacing.md)
            } else {
                ForEach(state.players.filter { state.watchlist.contains($0.id) }) { p in
                    NavigationLink { PlayerDetailView(player: p) } label: { PlayerRow(player: p) }
                }
            }
        }
    }
}
