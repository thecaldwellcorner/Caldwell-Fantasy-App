import SwiftUI

struct LeagueDashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var tab: Tab = .roster
    enum Tab: String, CaseIterable { case roster = "My Team", standings = "Standings", power = "Power" }

    var body: some View {
        VStack(spacing: 0) {
            if state.leagues.count > 1 {
                Picker("League", selection: Binding(
                    get: { state.selectedLeagueID ?? state.leagues.first!.id },
                    set: { state.selectedLeagueID = $0 })) {
                    ForEach(state.leagues) { league in
                        Text(league.name).tag(league.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.Colors.accent)
                .padding(.top, Theme.Spacing.sm)
            }

            DSSegmented(items: Tab.allCases, title: { $0.rawValue }, selection: $tab)
                .padding(Theme.Spacing.lg)

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if let league = state.selectedLeague {
                        switch tab {
                        case .roster: rosterView(league)
                        case .standings: standingsView(league)
                        case .power: powerView(league)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .screenBackground()
        .navigationTitle("League")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func rosterView(_ league: League) -> some View {
        if let team = league.userTeam {
            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    MetricChip(label: "Record", value: "\(team.wins)-\(team.losses)")
                    MetricChip(label: "Power", value: "\(Int(team.powerScore))", tint: Theme.Colors.grade(team.powerScore))
                    MetricChip(label: "Dynasty", value: "\(Int(team.dynastyValue))")
                }
                let grouped = Dictionary(grouping: state.rosterPlayers(for: team), by: { slotGroup($0.slot) })
                ForEach(["Starters", "Bench", "Taxi", "IR"], id: \.self) { group in
                    if let items = grouped[group], !items.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            DSEyebrow(text: group)
                            ForEach(items, id: \.player.id) { entry in
                                NavigationLink { PlayerDetailView(player: entry.player) } label: {
                                    rosterRow(slot: entry.slot, player: entry.player)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !team.futurePicks.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        DSEyebrow(text: "Future Picks")
                        FlowChips(items: team.futurePicks)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func slotGroup(_ slot: String) -> String {
        switch slot {
        case "BENCH": return "Bench"
        case "TAXI": return "Taxi"
        case "IR": return "IR"
        default: return "Starters"
        }
    }

    private func rosterRow(slot: String, player: Player) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(slot)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 44, height: 24)
                .background(Theme.Colors.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            PlayerAvatar(name: player.name, position: player.position.rawValue, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name).dsCardTitle().lineLimit(1)
                Text("\(player.position.rawValue) · \(player.team)").dsCaption()
            }
            Spacer()
            Text(String(format: "%.1f", player.projWeekly)).dsNumeric(14, color: Theme.Colors.accent)
        }
        .card(padding: Theme.Spacing.md)
    }

    private func standingsView(_ league: League) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(league.standings.enumerated()), id: \.element.id) { index, team in
                HStack(spacing: Theme.Spacing.md) {
                    Text("\(index + 1)")
                        .dsNumeric(15, color: index < league.teamCount / 2 ? Theme.Colors.accent : Theme.Colors.textTertiary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.name).dsCardTitle()
                            .foregroundStyle(team.isUser ? Theme.Colors.accent : Theme.Colors.textPrimary)
                        Text(team.ownerName).dsCaption()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(team.wins)-\(team.losses)").dsNumeric(14)
                        Text(String(format: "%.0f PF", team.pointsFor)).font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .card(padding: Theme.Spacing.md)
            }
        }
    }

    private func powerView(_ league: League) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(league.teams.sorted { $0.powerScore > $1.powerScore }) { team in
                VStack(spacing: 6) {
                    HStack {
                        Text(team.name).dsCardTitle()
                            .foregroundStyle(team.isUser ? Theme.Colors.accent : Theme.Colors.textPrimary)
                        Spacer()
                        Text("\(Int(team.powerScore))").dsNumeric(15, color: Theme.Colors.grade(team.powerScore))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Colors.surfaceElevated).frame(height: 7)
                            Capsule().fill(Theme.Colors.grade(team.powerScore)).frame(width: geo.size.width * CGFloat(team.powerScore / 100), height: 7)
                        }
                    }.frame(height: 7)
                    HStack {
                        Text("Playoff \(Int(team.playoffOdds))%").font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
                        Spacer()
                        Text("Title \(Int(team.championshipOdds))%").font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                .card(padding: Theme.Spacing.md)
            }
        }
    }
}

struct FlowChips: View {
    let items: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.Colors.surfaceElevated)
                    .clipShape(Capsule())
            }
        }
    }
}
