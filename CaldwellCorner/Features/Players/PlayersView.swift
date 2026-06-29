import SwiftUI

struct PlayersView: View {
    @EnvironmentObject var state: AppState
    @State private var mode: Mode = .database
    enum Mode: String, CaseIterable { case database = "Database", rankings = "Rankings" }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.lg)

            switch mode {
            case .database: PlayerDatabaseView()
            case .rankings: RankingsView()
            }
        }
        .screenBackground()
        .navigationTitle("Players")
    }
}

struct PlayerDatabaseView: View {
    @EnvironmentObject var state: AppState
    @State private var search = ""
    @State private var positionFilter: Position?
    @State private var sort: SortOption = .overall
    @State private var loaded = false

    enum SortOption: String, CaseIterable {
        case overall = "Overall", projection = "Proj", dynasty = "Dynasty", trend = "Trend"
    }

    private var filtered: [Player] {
        var list = state.players
        if let positionFilter { list = list.filter { $0.position == positionFilter } }
        if !search.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.team.localizedCaseInsensitiveContains(search) }
        }
        switch sort {
        case .overall: list.sort { $0.overallRank < $1.overallRank }
        case .projection: list.sort { $0.projWeekly > $1.projWeekly }
        case .dynasty: list.sort { $0.dynastyValue > $1.dynastyValue }
        case .trend: list.sort { $0.rankTrend > $1.rankTrend }
        }
        return list
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.textTertiary)
                TextField("Search players or teams", text: $search)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .autocorrectionDisabled()
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .padding(.horizontal, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    FilterChip(title: "ALL", selected: positionFilter == nil) { positionFilter = nil }
                    ForEach(Position.allCases) { pos in
                        FilterChip(title: pos.rawValue, selected: positionFilter == pos,
                                   color: Theme.Colors.position(pos.rawValue)) {
                            positionFilter = positionFilter == pos ? nil : pos
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }

            HStack {
                Text("\(filtered.count) players")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { opt in
                        Button(opt.rawValue) { sort = opt }
                    }
                } label: {
                    Label("Sort: \(sort.rawValue)", systemImage: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)

            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    if loaded {
                        ForEach(filtered) { p in
                            NavigationLink { PlayerDetailView(player: p) } label: {
                                PlayerRow(player: p, sort: sort)
                            }
                        }
                    } else {
                        ForEach(0..<8, id: \.self) { _ in SkeletonCard(lines: 2) }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .onAppear {
            guard !loaded else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(Theme.Anim.quick) { loaded = true }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let selected: Bool
    var color: Color = Theme.Colors.accent
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(selected ? .black : Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(selected ? color : Theme.Colors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.Colors.stroke, lineWidth: selected ? 0 : 1))
        }
    }
}

struct PlayerRow: View {
    let player: Player
    var sort: PlayerDatabaseView.SortOption = .overall

    private var trailingValue: String {
        switch sort {
        case .overall: return "#\(player.overallRank)"
        case .projection: return String(format: "%.1f", player.projWeekly)
        case .dynasty: return "\(Int(player.dynastyValue))"
        case .trend: return (player.rankTrend >= 0 ? "+" : "") + String(format: "%.0f", player.rankTrend)
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(player.positionRank)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.position(player.position.rawValue))
                .frame(width: 22)
            PlayerAvatar(name: player.name, position: player.position.rawValue, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(player.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if player.injuryStatus.isConcern {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.Colors.warning)
                    }
                }
                HStack(spacing: 6) {
                    PositionBadge(position: player.position.rawValue, compact: true)
                    Text("\(player.team) · Bye \(player.byeWeek)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(trailingValue)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(sort == .trend ? (player.rankTrend >= 0 ? Theme.Colors.positive : Theme.Colors.negative) : Theme.Colors.textPrimary)
                Text(sort.rawValue.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}
