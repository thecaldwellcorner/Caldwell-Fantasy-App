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
                watchlistSection
                achievementsSection
                settingsSection
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Profile")
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.info], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .overlay(Text(initials).font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(.black))
                if state.isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14)).foregroundStyle(.black)
                        .padding(6).background(Theme.Colors.accentSecondary).clipShape(Circle())
                }
            }
            Text(state.profile.displayName)
                .font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
            Text("\(state.profile.handle) · \(state.profile.favoriteTeam)")
                .font(.system(size: 13)).foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var initials: String { state.profile.displayName.initials }

    private var subscriptionCard: some View {
        Group {
            if state.isPremium {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "crown.fill").font(.system(size: 26)).foregroundStyle(Theme.Colors.accentSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium Member").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
                        Text("All features unlocked · Annual plan").font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                }
                .card()
            } else {
                Button { showPaywall = true } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "crown.fill").font(.system(size: 26)).foregroundStyle(.black)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Upgrade to Premium").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                            Text("Unlimited AI · Dynasty tools · Draft Guide").font(.system(size: 12, weight: .medium)).foregroundStyle(.black.opacity(0.75))
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.black)
                    }
                    .padding(Theme.Spacing.lg)
                    .background(LinearGradient(colors: [Theme.Colors.accent, Theme.Colors.accentSecondary], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
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
                MetricChip(label: "Level", value: "\(s.level)", tint: Theme.Colors.info)
                MetricChip(label: "Leagues", value: "\(state.profile.lifetimeLeagues)")
                MetricChip(label: "Titles", value: "\(state.profile.championships)", tint: Theme.Colors.accentSecondary)
            }
        }
    }

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Watchlist", subtitle: state.watchlist.isEmpty ? "Star players to track them" : nil)
            if state.watchlist.isEmpty {
                Text("No players yet — tap the star on any player profile.")
                    .font(.system(size: 13)).foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: Theme.Spacing.md)
            } else {
                ForEach(state.players.filter { state.watchlist.contains($0.id) }) { p in
                    NavigationLink { PlayerDetailView(player: p) } label: { PlayerRow(player: p) }
                }
            }
        }
    }

    private var achievementsSection: some View {
        let s = state.progression
        let badges = state.achievements
            .filter { $0.unlocked }
            .sorted { $0.rarity.order > $1.rarity.order }
            .prefix(8)
        let globalRank = state.leaderboard(.global).first(where: { $0.isUser })?.rank

        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Progression")

            NavigationLink { AchievementsView() } label: {
                HStack(spacing: Theme.Spacing.md) {
                    LevelBadge(level: s.level, size: 56)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text("\(s.totalAP) AP")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(s.levelTitle.uppercased())
                                .font(.system(size: 9, weight: .heavy)).foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.Colors.accent).clipShape(Capsule())
                        }
                        ProgressBar(fraction: s.progressInLevel)
                        Text("\(s.unlockedCount)/\(s.totalCount) unlocked · \(Int(s.completion * 100))% complete")
                            .font(.system(size: 11)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
                }
                .card()
            }

            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(badges)) { a in
                            ZStack {
                                Circle().fill(AchievementStyle.gradient(a.rarity)).frame(width: 46, height: 46)
                                Image(systemName: a.systemImage).font(.system(size: 18, weight: .bold)).foregroundStyle(.black)
                            }
                        }
                    }
                }
            }

            NavigationLink { LeaderboardView() } label: {
                HStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18)).foregroundStyle(.black)
                        .frame(width: 38, height: 38).background(Theme.Gradient.gold).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Leaderboards").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
                        Text(globalRank.map { "You're #\($0) globally" } ?? "See where you rank").font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
                }
                .card(padding: Theme.Spacing.md)
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Settings")
            VStack(spacing: 0) {
                settingRow("Notifications", "bell.fill")
                Divider().overlay(Theme.Colors.stroke)
                settingRow("Manage Subscription", "creditcard.fill")
                Divider().overlay(Theme.Colors.stroke)
                settingRow("Favorite Teams", "star.fill")
                Divider().overlay(Theme.Colors.stroke)
                settingRow("Help & Support", "questionmark.circle.fill")
            }
            .card(padding: 0)
            if state.isPremium {
                Button {
                    state.profile.tier = .free
                } label: {
                    Text("Switch to Free (demo)")
                        .font(.system(size: 13)).foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func settingRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon).foregroundStyle(Theme.Colors.accent).frame(width: 24)
            Text(title).font(.system(size: 15)).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(Theme.Spacing.md)
    }
}
