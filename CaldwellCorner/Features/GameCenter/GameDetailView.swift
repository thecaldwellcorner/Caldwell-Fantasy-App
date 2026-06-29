import SwiftUI

struct GameDetailView: View {
    @EnvironmentObject var games: GameCenterStore
    let gameID: UUID
    @State private var tab: Tab = .summary

    enum Tab: String, CaseIterable { case summary = "Summary", plays = "Plays", stats = "Stats", fantasy = "Fantasy" }

    private var game: NFLGame? { games.game(gameID) }

    var body: some View {
        Group {
            if let game {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        DetailScoreboard(game: game)
                        DSSegmented(items: Tab.allCases, title: { $0.rawValue }, selection: $tab)

                        switch tab {
                        case .summary: SummaryTab(game: game)
                        case .plays: PlaysTab(game: game)
                        case .stats: StatsTab(game: game)
                        case .fantasy: FantasyTab(game: game)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            } else {
                ContentUnavailablePlaceholder()
            }
        }
        .screenBackground()
        .navigationTitle(game.map { "\($0.away.abbr) @ \($0.home.abbr)" } ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { games.subscribe() }
        .onDisappear { games.unsubscribe() }
    }
}

// MARK: - Scoreboard header
struct DetailScoreboard: View {
    let game: NFLGame
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                teamColumn(game.away, side: .away)
                VStack(spacing: 6) {
                    if game.status == .live {
                        HStack(spacing: 5) { LivePulse(); Text(game.periodLabel).font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.Colors.negative) }
                        Text(game.clockLabel)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .contentTransition(.numericText())
                            .animation(Theme.Anim.quick, value: game.clockSeconds)
                    } else {
                        Text(game.periodLabel)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    Text("vs").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                teamColumn(game.home, side: .home)
            }
            if game.status == .live, game.isRedZone {
                Text("🏈 RED ZONE")
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.Colors.negative).clipShape(Capsule())
            }
            if let dd = game.downDistanceLabel {
                Text(dd).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .card(elevated: true)
    }

    private func teamColumn(_ team: GameTeam, side: GameSide) -> some View {
        VStack(spacing: 6) {
            TeamLogo(abbr: team.abbr, colorHex: team.colorHex, size: 48)
            Text(team.abbr).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.textSecondary)
            Text("\(team.score)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .contentTransition(.numericText())
                .animation(Theme.Anim.snappy, value: team.score)
            if game.possession == side && game.status == .live {
                Image(systemName: "football.fill").font(.system(size: 11)).foregroundStyle(Theme.Colors.accentSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Summary tab
struct SummaryTab: View {
    let game: NFLGame
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            if game.status == .pregame {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "clock.badge").font(.system(size: 34)).foregroundStyle(Theme.Colors.accent)
                    Text("Kickoff \(game.periodLabel)")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.Colors.textPrimary)
                    Text("Scoring, play-by-play and live stats appear once the game starts.")
                        .font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).card()
            } else {
                SectionHeader(title: "Scoring Summary")
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(game.scoringPlays) { ScoringRow(play: $0, game: game) }
                }
            }
        }
    }
}

struct ScoringRow: View {
    let play: ScoringPlay
    let game: NFLGame
    private var color: Color {
        let hex = play.teamAbbr == game.home.abbr ? game.home.colorHex : game.away.colorHex
        return Color(hex: hex)
    }
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(play.kind)
                .font(.system(size: 11, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 38, height: 24)
                .background(color).clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(play.detail).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
                Text("Q\(play.quarter) · \(play.clock)").font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            Text("\(play.awayScore)-\(play.homeScore)")
                .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.Colors.textSecondary)
        }
        .card(padding: Theme.Spacing.md)
    }
}

// MARK: - Plays tab
struct PlaysTab: View {
    let game: NFLGame
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Play-by-Play")
            if game.plays.isEmpty {
                Text("Plays will stream here live.")
                    .font(.system(size: 13)).foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading).card(padding: Theme.Spacing.md)
            } else {
                ForEach(game.plays) { play in
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        VStack(spacing: 1) {
                            Text("Q\(play.quarter)").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.Colors.textTertiary)
                            Text(play.clock).font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
                        }
                        .frame(width: 40)
                        Text(play.text)
                            .font(.system(size: 13, weight: play.isScoring ? .bold : .regular))
                            .foregroundStyle(play.isScoring ? Theme.Colors.accent : Theme.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if play.isBig && !play.isScoring {
                            Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(Theme.Colors.accentSecondary)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(play.isScoring ? Theme.Colors.accent.opacity(0.08) : Theme.Colors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .strokeBorder(Theme.Colors.strokeSoft, lineWidth: 1))
                    .transition(.opacity)
                }
            }
        }
        .animation(Theme.Anim.quick, value: game.plays.count)
    }
}

// MARK: - Stats tab
struct StatsTab: View {
    let game: NFLGame
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            teamBlock(game.away)
            teamBlock(game.home)
        }
    }
    private func teamBlock(_ team: GameTeam) -> some View {
        let stats = game.stats.filter { $0.teamAbbr == team.abbr }
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                TeamLogo(abbr: team.abbr, colorHex: team.colorHex, size: 26)
                Text(team.name).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
            }
            ForEach(stats) { StatRow(stat: $0) }
        }
    }
}

struct StatRow: View {
    let stat: PlayerGameStat
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PlayerAvatar(name: stat.name, position: stat.position.rawValue, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(stat.name).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
                    if stat.isUserPlayer {
                        Text("YOURS").font(.system(size: 8, weight: .heavy)).foregroundStyle(.black)
                            .padding(.horizontal, 5).padding(.vertical, 1).background(Theme.Colors.accent).clipShape(Capsule())
                    }
                }
                Text(stat.statLine).font(.system(size: 11)).foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f", stat.fantasyPoints))
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.accent)
                    .contentTransition(.numericText())
                    .animation(Theme.Anim.snappy, value: stat.fantasyPoints)
                Text("PTS").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}

// MARK: - Fantasy tab (matchup tracking)
struct FantasyTab: View {
    let game: NFLGame
    private var userStats: [PlayerGameStat] { game.stats.filter { $0.isUserPlayer } }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            SectionHeader(title: "Your Players", subtitle: userStats.isEmpty ? "None of your players are in this game" : "Live fantasy tracking")
            ForEach(userStats) { FantasyTrackRow(stat: $0) }

            SectionHeader(title: "All Players")
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(game.stats.sorted { $0.fantasyPoints > $1.fantasyPoints }) { StatRow(stat: $0) }
            }
        }
    }
}

struct FantasyTrackRow: View {
    let stat: PlayerGameStat
    private var pace: Double { stat.projection <= 0 ? 0 : min(1.4, stat.fantasyPoints / stat.projection) }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                PlayerAvatar(name: stat.name, position: stat.position.rawValue, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.name).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(stat.position.rawValue) · \(stat.teamAbbr) · \(stat.statLine)")
                        .font(.system(size: 11)).foregroundStyle(Theme.Colors.textSecondary).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "%.1f", stat.fantasyPoints))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.accent)
                        .contentTransition(.numericText())
                        .animation(Theme.Anim.snappy, value: stat.fantasyPoints)
                    Text("proj \(String(format: "%.1f", stat.projection))")
                        .font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            // Pace bar (live vs projection)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.surfaceElevated).frame(height: 8)
                    Capsule()
                        .fill(stat.fantasyPoints >= stat.projection ? Theme.Colors.positive : Theme.Colors.accent)
                        .frame(width: geo.size.width * CGFloat(min(1, pace)), height: 8)
                        .animation(Theme.Anim.standard, value: stat.fantasyPoints)
                    // Projection marker
                    Rectangle().fill(Theme.Colors.textTertiary)
                        .frame(width: 2, height: 12)
                        .offset(x: geo.size.width * CGFloat(min(1, stat.projection > 0 ? min(1, 1.0 / 1.4) : 1)))
                }
            }
            .frame(height: 12)
            HStack {
                Text(stat.fantasyPoints >= stat.projection ? "Beating projection" : "On pace: \(Int(pace * 100))%")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(stat.fantasyPoints >= stat.projection ? Theme.Colors.positive : Theme.Colors.textSecondary)
                Spacer()
            }
        }
        .card()
    }
}

struct ContentUnavailablePlaceholder: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sportscourt").font(.system(size: 40)).foregroundStyle(Theme.Colors.textTertiary)
            Text("Game unavailable").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity).padding(.top, 80)
    }
}
