import SwiftUI

struct PlayersView: View {
    @EnvironmentObject var state: AppState
    @State private var mode: Mode = .database
    enum Mode: String, CaseIterable { case database = "Database", rankings = "Rankings" }

    var body: some View {
        VStack(spacing: 0) {
            DSSegmented(items: Mode.allCases, title: { $0.rawValue }, selection: $mode)
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
            searchField.dsScreenPadding()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    FilterChip(title: "All", selected: positionFilter == nil) { positionFilter = nil }
                    ForEach(Position.allCases) { pos in
                        FilterChip(title: pos.rawValue, selected: positionFilter == pos,
                                   color: Theme.Colors.position(pos.rawValue)) {
                            positionFilter = positionFilter == pos ? nil : pos
                        }
                    }
                }
                .dsScreenPadding()
            }

            HStack {
                Text("\(filtered.count) players").dsCaption()
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
            .dsScreenPadding()

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
                .dsScreenPadding()
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

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.textTertiary)
            TextField("Search players or teams", text: $search)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .background(Theme.Colors.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            .strokeBorder(Theme.Colors.stroke, lineWidth: 1))
    }
}

// MARK: - Standard player list row
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

    private var trailingColor: Color {
        sort == .trend ? (player.rankTrend >= 0 ? Theme.Colors.positive : Theme.Colors.negative) : Theme.Colors.textPrimary
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(player.positionRank)")
                .dsNumeric(13, color: Theme.Colors.position(player.position.rawValue))
                .frame(width: 22)
            PlayerAvatar(name: player.name, position: player.position.rawValue, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name).dsCardTitle().lineLimit(1)
                    if player.injuryStatus.isConcern {
                        Image(systemName: "cross.case.fill").font(.system(size: 10)).foregroundStyle(Theme.Colors.warning)
                    }
                }
                HStack(spacing: 6) {
                    PositionBadge(position: player.position.rawValue, compact: true)
                    Text("\(player.team) · Bye \(player.byeWeek)").dsCaption()
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(trailingValue).dsNumeric(16, color: trailingColor)
                DSEyebrow(text: sort.rawValue)
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}
