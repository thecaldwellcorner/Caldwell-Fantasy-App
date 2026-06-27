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
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Menu {
                        ForEach(ScoringFormat.allCases) { f in
                            Button(f.rawValue) { scoring = f }
                        }
                    } label: {
                        DropdownLabel(text: scoring.rawValue, icon: "scalemass")
                    }
                    Toggle("Dynasty", isOn: $dynasty)
                        .toggleStyle(.button)
                        .tint(Theme.Colors.accent)
                        .font(.system(size: 13, weight: .semibold))
                    Toggle("SF", isOn: $superflex)
                        .toggleStyle(.button)
                        .tint(Theme.Colors.info)
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    FilterChip(title: "ALL", selected: position == nil) { position = nil }
                    ForEach(Position.allCases) { pos in
                        FilterChip(title: pos.rawValue, selected: position == pos,
                                   color: Theme.Colors.position(pos.rawValue)) {
                            position = position == pos ? nil : pos
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            HStack {
                Text(rankingTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.accent)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { index, p in
                        NavigationLink { PlayerDetailView(player: p) } label: {
                            RankingRow(rank: index + 1, player: p, dynasty: dynasty)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
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

struct DropdownLabel: View {
    let text: String
    let icon: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
            Image(systemName: "chevron.down").font(.system(size: 10))
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Colors.stroke, lineWidth: 1))
    }
}

struct RankingRow: View {
    let rank: Int
    let player: Player
    let dynasty: Bool
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(rank <= 3 ? Theme.Colors.accentSecondary : Theme.Colors.textSecondary)
                .frame(width: 28)
            PlayerAvatar(name: player.name, position: player.position.rawValue, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    PositionBadge(position: player.position.rawValue, compact: true)
                    Text(player.team)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
            GradeRing(score: dynasty ? player.dynastyValue : player.redraftValue, size: 40)
        }
        .card(padding: Theme.Spacing.md)
    }
}
