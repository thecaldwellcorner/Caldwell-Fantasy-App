import SwiftUI

struct LeagueDashboardView: View {
    @EnvironmentObject var state: AppState

    private var league: League? { state.selectedLeague }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("League").dsScreenTitle()

                if state.leagues.count > 1 { leaguePicker }

                if let league {
                    standingsSection(league).appear()
                    powerSection(league).appear(delay: 0.05)
                    awardsSection(league).appear(delay: 0.1)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var leaguePicker: some View {
        Menu {
            ForEach(state.leagues) { lg in
                Button(lg.name) { state.selectedLeagueID = lg.id }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: league?.platform.systemImage ?? "sportscourt.fill")
                Text(league?.name ?? "League")
                Image(systemName: "chevron.down").font(.system(size: 10))
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 8)
            .background(Theme.Colors.surfaceElevated, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.Colors.stroke, lineWidth: 1))
        }
    }

    // MARK: Standings
    private func standingsSection(_ league: League) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DSEyebrow(text: "Standings")
            ForEach(Array(league.standings.enumerated()), id: \.element.id) { index, team in
                StandingRow(rank: index + 1, team: team)
            }
        }
    }

    // MARK: Power rankings
    private func powerSection(_ league: League) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DSEyebrow(text: "Power Rankings")
            VStack(spacing: Theme.Spacing.md) {
                ForEach(Array(league.teams.sorted { $0.powerScore > $1.powerScore }.prefix(3).enumerated()), id: \.element.id) { idx, team in
                    HStack(spacing: Theme.Spacing.md) {
                        Text("#\(idx + 1)").dsNumeric(14, color: Theme.Colors.accent).frame(width: 30, alignment: .leading)
                        Text(team.name).dsCardTitle()
                        Spacer()
                        DotMeter(score: team.powerScore)
                    }
                }
            }
            .glassCard(radius: 18)
        }
    }

    // MARK: Weekly awards
    private func awardsSection(_ league: League) -> some View {
        let awards = LeagueAwards(league: league)
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DSEyebrow(text: "Week \(max(1, league.currentWeek - 1)) Awards")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md),
                                GridItem(.flexible(), spacing: Theme.Spacing.md)],
                      spacing: Theme.Spacing.md) {
                ForEach(awards.items) { AwardCard(award: $0) }
            }
        }
    }
}

// MARK: - Standings row
struct StandingRow: View {
    let rank: Int
    let team: FantasyTeam

    private var rankColor: Color {
        switch rank {
        case 1: return Theme.Colors.accentSecondary
        case 2: return Theme.Colors.accent
        case 3: return Color(hex: 0xCD7F32)
        default: return Theme.Colors.textTertiary
        }
    }
    private var grade: String {
        switch team.powerScore {
        case 88...: return "A+"
        case 80..<88: return "A"
        case 72..<80: return "B+"
        case 64..<72: return "B"
        case 56..<64: return "C+"
        default: return "C"
        }
    }
    private var gradeColor: Color {
        switch team.powerScore {
        case 80...: return Theme.Colors.positive
        case 64..<80: return Theme.Colors.accent
        default: return Theme.Colors.warning
        }
    }
    private var movement: Int {
        if team.powerScore >= 78 { return 1 }
        if team.powerScore < 56 { return -1 }
        return 0
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(rank)").dsNumeric(16, color: rankColor).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(team.name).dsCardTitle().foregroundStyle(team.isUser ? Theme.Colors.accent : Theme.Colors.textPrimary)
                Text("\(Int(team.pointsFor).formatted()) pts").dsCaption()
            }
            Spacer()
            Tag(text: grade, color: gradeColor)
            HStack(spacing: 5) {
                if movement > 0 { Image(systemName: "arrow.up").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.Colors.positive) }
                else if movement < 0 { Image(systemName: "arrow.down").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.Colors.negative) }
                Text("\(team.wins)-\(team.losses)").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(team.isUser ? Theme.Colors.accent.opacity(0.10) : Theme.Colors.surface,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .strokeBorder(team.isUser ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.stroke, lineWidth: 1))
    }
}

// MARK: - Dot strength meter
struct DotMeter: View {
    let score: Double
    private var filled: Int { max(1, min(5, Int((score / 20).rounded()))) }
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < filled ? Theme.Colors.accent : Color.clear)
                    .overlay(Circle().strokeBorder(i < filled ? Color.clear : Theme.Colors.stroke, lineWidth: 1))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Award card
struct LeagueAward: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String
    let subtitle: String
}

private struct LeagueAwards {
    let items: [LeagueAward]
    init(league: League) {
        let byPoints = league.teams.sorted { $0.pointsFor > $1.pointsFor }
        let high = byPoints.first
        let dynasty = league.teams.sorted { $0.dynastyValue > $1.dynastyValue }.first
        let lucky = league.teams.min(by: { $0.pointsFor < $1.pointsFor })
        let waiver = league.teams.sorted { $0.playoffOdds > $1.playoffOdds }.dropFirst().first
        items = [
            LeagueAward(icon: "rosette", title: "High Score",
                        value: "\(String(format: "%.1f", (high?.pointsFor ?? 0) / Double(max(1, (high?.wins ?? 0) + (high?.losses ?? 1))) + 20)) pts",
                        subtitle: high?.name ?? "—"),
            LeagueAward(icon: "waveform.path", title: "Best Trade",
                        value: "+\(Int((dynasty?.dynastyValue ?? 0) / 4)) val", subtitle: dynasty?.name ?? "—"),
            LeagueAward(icon: "star.fill", title: "Luckiest Win",
                        value: "Upset", subtitle: lucky?.name ?? "—"),
            LeagueAward(icon: "arrow.up.right", title: "Top Waiver",
                        value: "Hot add", subtitle: waiver?.name ?? "—"),
        ]
    }
}

struct AwardCard: View {
    let award: LeagueAward
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: award.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.Colors.accentSecondary)
            DSEyebrow(text: award.title)
            Text(award.value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
            Text(award.subtitle).dsCaption().lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .card(padding: Theme.Spacing.md)
    }
}
