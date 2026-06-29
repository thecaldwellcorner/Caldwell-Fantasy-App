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
        VStack(spacing: Theme.Spacing.md) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(ScoringFormat.allCases) { f in
                        FilterChip(title: f.rawValue, selected: scoring == f) { scoring = f }
                    }
                    Divider().frame(height: 22).overlay(Theme.Colors.stroke)
                    FilterChip(title: "Dynasty", selected: dynasty) { dynasty.toggle() }
                    FilterChip(title: "Superflex", selected: superflex) { superflex.toggle() }
                }
                .dsScreenPadding()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    FilterChip(title: "All", selected: position == nil) { position = nil }
                    ForEach(Position.allCases) { pos in
                        FilterChip(title: pos.rawValue, selected: position == pos,
                                   color: Theme.Colors.position(pos.rawValue)) {
                            position = position == pos ? nil : pos
                        }
                    }
                }
                .dsScreenPadding()
            }

            HStack {
                DSEyebrow(text: rankingTitle, color: Theme.Colors.accent)
                Spacer()
            }
            .dsScreenPadding()

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, p in
                        NavigationLink { PlayerDetailView(player: p) } label: {
                            RankingRow(rank: index + 1, player: p, dynasty: dynasty)
                        }
                    }
                }
                .dsScreenPadding()
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }

    private var rankingTitle: String {
        var parts: [String] = []
        if superflex { parts.append("Superflex") }
        parts.append(dynasty ? "Dynasty" : scoring.rawValue)
        if let position { parts.append(position.rawValue) }
        parts.append("Rankings")
        return parts.joined(separator: " ")
    }
}

struct RankingRow: View {
    let rank: Int
    let player: Player
    let dynasty: Bool
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(rank)")
                .dsNumeric(15, color: rank <= 3 ? Theme.Colors.accentSecondary : Theme.Colors.textTertiary)
                .frame(width: 26)
            PlayerAvatar(name: player.name, position: player.position.rawValue, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.name).dsCardTitle().lineLimit(1)
                HStack(spacing: 6) {
                    PositionBadge(position: player.position.rawValue, compact: true)
                    Text(player.team).dsCaption()
                }
            }
            Spacer()
            GradeRing(score: dynasty ? player.dynastyValue : player.redraftValue, size: 40)
        }
        .card(padding: Theme.Spacing.md)
    }
}
