import SwiftUI

struct GameCenterView: View {
    @EnvironmentObject var games: GameCenterStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg, pinnedViews: []) {
                if !games.liveGames.isEmpty {
                    sectionHeader("Live", count: games.liveGames.count, live: true)
                    ForEach(games.liveGames) { gameLink($0) }
                }
                if !games.upcomingGames.isEmpty {
                    sectionHeader("Upcoming", count: games.upcomingGames.count)
                    ForEach(games.upcomingGames) { gameLink($0) }
                }
                if !games.finalGames.isEmpty {
                    sectionHeader("Final", count: games.finalGames.count)
                    ForEach(games.finalGames) { gameLink($0) }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Game Center")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { games.subscribe() }
        .onDisappear { games.unsubscribe() }
    }

    private func gameLink(_ game: NFLGame) -> some View {
        NavigationLink { GameDetailView(gameID: game.id) } label: {
            ScoreboardCard(game: game)
        }
    }

    private func sectionHeader(_ title: String, count: Int, live: Bool = false) -> some View {
        HStack(spacing: 8) {
            if live { LivePulse() }
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
            Spacer()
        }
    }
}

// MARK: - Live pulse dot
struct LivePulse: View {
    @State private var on = false
    var body: some View {
        Circle()
            .fill(Theme.Colors.negative)
            .frame(width: 9, height: 9)
            .opacity(on ? 1 : 0.35)
            .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { on = true } }
    }
}

// MARK: - Scoreboard card
struct ScoreboardCard: View {
    let game: NFLGame

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            teamRow(game.away, side: .away)
            teamRow(game.home, side: .home)
            Divider().overlay(Theme.Colors.strokeSoft)
            footer
        }
        .card(padding: Theme.Spacing.md)
    }

    private func teamRow(_ team: GameTeam, side: GameSide) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            TeamLogo(abbr: team.abbr, colorHex: team.colorHex, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(team.abbr)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    if game.possession == side && game.status == .live {
                        Image(systemName: "football.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.accentSecondary)
                    }
                }
                Text(team.record)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            Text("\(team.score)")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(scoreColor(side))
                .contentTransition(.numericText())
                .animation(Theme.Anim.snappy, value: team.score)
        }
    }

    private func scoreColor(_ side: GameSide) -> Color {
        guard game.status == .final else { return Theme.Colors.textPrimary }
        let win = side == .home ? game.home.score > game.away.score : game.away.score > game.home.score
        return win ? Theme.Colors.textPrimary : Theme.Colors.textTertiary
    }

    @ViewBuilder private var footer: some View {
        HStack(spacing: 8) {
            switch game.status {
            case .live:
                LivePulse()
                Text("\(game.periodLabel) · \(game.clockLabel)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if game.isRedZone {
                    Text("RED ZONE")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.Colors.negative).clipShape(Capsule())
                }
                Spacer()
                if let dd = game.downDistanceLabel {
                    Text(dd).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.Colors.textSecondary)
                }
            case .pregame:
                Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
                Text(game.periodLabel).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
            case .final:
                Text(game.periodLabel).font(.system(size: 12, weight: .heavy)).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("View recap").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.Colors.accent)
            }
        }
    }
}

// MARK: - Compact live card (Dashboard strip)
struct MiniGameCard: View {
    let game: NFLGame
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 5) {
                LivePulse()
                Text("\(game.periodLabel) · \(game.clockLabel)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.negative)
                Spacer()
                if game.isRedZone {
                    Text("RZ").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Theme.Colors.negative).clipShape(Capsule())
                }
            }
            miniRow(game.away, side: .away)
            miniRow(game.home, side: .home)
        }
        .frame(width: 184)
        .card(padding: Theme.Spacing.md)
    }

    private func miniRow(_ team: GameTeam, side: GameSide) -> some View {
        HStack(spacing: 8) {
            TeamLogo(abbr: team.abbr, colorHex: team.colorHex, size: 24)
            Text(team.abbr).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
            if game.possession == side {
                Image(systemName: "football.fill").font(.system(size: 8)).foregroundStyle(Theme.Colors.accentSecondary)
            }
            Spacer()
            Text("\(team.score)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
                .animation(Theme.Anim.snappy, value: team.score)
        }
    }
}

// MARK: - Team logo (abbr in a team-colored rounded square)
struct TeamLogo: View {
    let abbr: String
    let colorHex: UInt
    var size: CGFloat = 34
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay(
                Text(abbr.prefix(3))
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
            .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}
