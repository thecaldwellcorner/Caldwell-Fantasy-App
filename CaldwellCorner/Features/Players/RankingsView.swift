import SwiftUI

struct RankingsView: View {
    @EnvironmentObject var state: AppState
    @State private var scoring: ScoringFormat = .ppr
    @State private var dynasty = false
    @State private var superflex = false
    @State private var position: Position?

    private var ranked: [Player] {
        state.rankedPlayers(scoring: scoring, dynasty: dynasty, superflex: superflex, position: position)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                filterRow
                    .padding(.bottom, Theme.Spacing.xs)
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, p in
                    NavigationLink { PlayerDetailView(player: p) } label: {
                        RankingRow(rank: index + 1, player: p, dynasty: dynasty)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .screenBackground()
        .navigationTitle("Rankings")
    }

    private var filterRow: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    FilterChip(title: "All", selected: position == nil) { position = nil }
                    ForEach(Position.allCases) { pos in
                        FilterChip(title: pos.rawValue, selected: position == pos,
                                   color: Theme.Colors.position(pos.rawValue)) {
                            position = position == pos ? nil : pos
                        }
                    }
                    Menu {
                        Picker("Scoring", selection: $scoring) {
                            ForEach(ScoringFormat.allCases) { Text($0.rawValue).tag($0) }
                        }
                        Toggle("Dynasty", isOn: $dynasty)
                        Toggle("Superflex", isOn: $superflex)
                    } label: {
                        HStack(spacing: 5) {
                            Text(formatLabel)
                            Image(systemName: "slider.horizontal.3").font(.system(size: 11))
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 7)
                        .background(Theme.Colors.accent.opacity(0.14), in: Capsule())
                    }
                }
            }
        }
    }

    private var formatLabel: String {
        var s = dynasty ? "Dynasty" : scoring.rawValue
        if superflex { s += " · SF" }
        return s
    }
}

// MARK: - Ranking row
struct RankingRow: View {
    let rank: Int
    let player: Player
    let dynasty: Bool

    private var value: Double { dynasty ? player.dynastyValue : player.redraftValue }
    private var tier: String {
        switch value {
        case 92...: return "ELITE"
        case 82..<92: return "T1"
        case 72..<82: return "T2"
        default: return "T3"
        }
    }
    private var statusColor: Color { player.injuryStatus.isConcern ? Theme.Colors.warning : Theme.Colors.positive }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(rank)").dsNumeric(16, color: Theme.Colors.accent).frame(width: 26)
            PlayerAvatar(name: player.name, position: player.position.rawValue, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(player.name).dsCardTitle().lineLimit(1)
                    if player.rankTrend > 0 {
                        Image(systemName: "arrow.up").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.Colors.positive)
                    } else if player.rankTrend < 0 {
                        Image(systemName: "arrow.down").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.Colors.negative)
                    }
                }
                HStack(spacing: 6) {
                    Text("\(player.position.rawValue) · \(player.team)").dsCaption()
                    Tag(text: tier, color: Theme.Colors.accent)
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", player.ceiling)).dsNumeric(18)
                Text("proj \(String(format: "%.1f", player.projWeekly))").dsCaption()
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}
