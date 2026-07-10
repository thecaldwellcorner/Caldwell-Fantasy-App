import SwiftUI

/// Loads the async sections of the player card (schedule, projections, recent
/// stats). The player bio itself is passed in from the tapped row, so it renders
/// instantly and we never refetch the full players list.
@MainActor
final class PlayerDetailStore: ObservableObject {
    @Published var schedule: LoadState<[SupabaseGame]> = .idle
    @Published var projections: LoadState<[SupabaseProjection]> = .idle
    @Published var recent: LoadState<[SupabaseWeeklyStat]> = .idle

    private let service: SupabaseService

    init(service: SupabaseService = .shared) {
        self.service = service
    }

    func loadAll(player: SupabasePlayer) async {
        async let s: Void = loadSchedule(team: player.team ?? "")
        async let p: Void = loadProjections(playerId: player.sleeperId)
        async let r: Void = loadRecent(playerId: player.sleeperId)
        _ = await (s, p, r)
    }

    func loadSchedule(team: String) async {
        schedule = .loading
        do {
            let games = try await service.fetchUpcomingGames(team: team, limit: 5)
            schedule = games.isEmpty ? .empty : .loaded(games)
        } catch {
            schedule = .failed(message(error))
        }
    }

    func loadProjections(playerId: String) async {
        projections = .loading
        do {
            let rows = try await service.fetchProjection(playerId: playerId)
            projections = rows.isEmpty ? .empty : .loaded(rows)
        } catch {
            projections = .failed(message(error))
        }
    }

    func loadRecent(playerId: String) async {
        recent = .loading
        do {
            let rows = try await service.fetchRecentStats(playerId: playerId, limit: 5)
            recent = rows.isEmpty ? .empty : .loaded(rows)
        } catch {
            recent = .failed(message(error))
        }
    }

    private func message(_ error: Error) -> String {
        (error as? SupabaseService.ServiceError)?.errorDescription ?? error.localizedDescription
    }
}

/// Full player card for a Supabase-backed player. Bio renders immediately from
/// the tapped row; schedule / projections / recent stats load asynchronously and
/// each show their own loading / empty / error state (never fabricated data).
struct SupabasePlayerDetailView: View {
    let player: SupabasePlayer
    var rank: Int?

    @StateObject private var store = PlayerDetailStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header
                infoSection
                projectionSection
                scheduleSection
                recentSection
            }
            .padding(Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .screenBackground()
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadAll(player: player) }
    }

    // MARK: - Header

    private var nextProjection: SupabaseProjection? {
        guard let list = store.projections.value else { return nil }
        return list.first(where: { ($0.week ?? 0) > 0 }) ?? list.first
    }

    private var projLabel: String {
        if let pts = nextProjection?.projFantasyPointsPpr { return String(format: "%.1f", pts) }
        return "—"
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.lg) {
                ZStack(alignment: .bottomTrailing) {
                    PlayerAvatar(name: player.displayName, position: player.position ?? "", size: 76)
                    if let team = player.team, !team.isEmpty {
                        Text(team)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.surfaceHighlight)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Theme.Colors.stroke, lineWidth: 1))
                            .offset(x: 4, y: 4)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(player.displayName).dsScreenTitle().lineLimit(2)
                    HStack(spacing: 6) {
                        if let pos = player.position, !pos.isEmpty {
                            PositionBadge(position: pos)
                        }
                        Text(headerTeamLine).dsCallout()
                    }
                }
                Spacer()
            }

            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "IQ Rank", value: rank.map { "#\($0)" } ?? "—", tint: Theme.Colors.accent)
                MetricChip(label: "Proj Pts", value: projLabel, tint: Theme.Colors.accentSecondary)
                MetricChip(
                    label: "Status",
                    value: (player.active ?? false) ? "Active" : "Inactive",
                    tint: (player.active ?? false) ? Theme.Colors.positive : Theme.Colors.textSecondary
                )
            }
        }
        .card(elevated: true)
    }

    private var headerTeamLine: String {
        // `players` has no jersey_number column, so we don't show a jersey.
        player.team?.isEmpty == false ? player.team! : "Free Agent"
    }

    // MARK: - Player info

    private var infoSection: some View {
        DetailSection(title: "Player Info") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                InfoTile(label: "Age", value: player.age.map(String.init) ?? "—")
                InfoTile(label: "Experience", value: "—")
                InfoTile(label: "Height", value: player.height?.isEmpty == false ? player.height! : "—")
                InfoTile(label: "Weight", value: weightLabel)
                InfoTile(label: "Team", value: player.team?.isEmpty == false ? player.team! : "FA")
                InfoTile(label: "Position", value: player.position?.isEmpty == false ? player.position! : "—")
                InfoTile(label: "College", value: "—")
                InfoTile(label: "Status", value: (player.active ?? false) ? "Active" : "Inactive")
            }
            InfoTile(label: "Sleeper ID", value: player.sleeperId)
        }
    }

    private var weightLabel: String {
        guard let w = player.weight, !w.isEmpty else { return "—" }
        return w.contains("lb") ? w : "\(w) lb"
    }

    // MARK: - Fantasy projection

    private var projectionSection: some View {
        DetailSection(title: "Fantasy Projection") {
            switch store.projections {
            case .idle, .loading:
                SectionLoading()
            case .failed(let msg):
                SectionError(message: msg) { Task { await store.loadProjections(playerId: player.sleeperId) } }
            case .empty:
                ComingSoon(text: "Projection data coming soon.")
            case .loaded:
                projectionTiles
            }
        }
    }

    private var restOfSeasonProjection: SupabaseProjection? {
        store.projections.value?.first(where: { ($0.week ?? -1) == 0 })
    }

    private var projectionTiles: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                InfoTile(label: "Next Game", value: fmt(nextProjection?.projFantasyPointsPpr))
                InfoTile(label: "Rest of Season", value: fmt(restOfSeasonProjection?.projFantasyPointsPpr))
            }
            HStack(spacing: Theme.Spacing.sm) {
                InfoTile(label: "Floor", value: fmt(nextProjection?.floor))
                InfoTile(label: "Ceiling", value: fmt(nextProjection?.ceiling))
            }
            HStack(spacing: Theme.Spacing.sm) {
                InfoTile(label: "Confidence", value: "—")
                InfoTile(label: "Matchup", value: "—")
            }
        }
    }

    // MARK: - Upcoming schedule

    private var scheduleSection: some View {
        DetailSection(title: "Upcoming Schedule") {
            switch store.schedule {
            case .idle, .loading:
                SectionLoading()
            case .failed(let msg):
                SectionError(message: msg) { Task { await store.loadSchedule(team: player.team ?? "") } }
            case .empty:
                ComingSoon(text: "Schedule data coming soon.")
            case .loaded(let games):
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(games) { game in
                        ScheduleRow(game: game, team: player.team ?? "")
                    }
                }
            }
        }
    }

    // MARK: - Recent performance

    private var recentSection: some View {
        DetailSection(title: "Recent Performance") {
            switch store.recent {
            case .idle, .loading:
                SectionLoading()
            case .failed(let msg):
                SectionError(message: msg) { Task { await store.loadRecent(playerId: player.sleeperId) } }
            case .empty:
                ComingSoon(text: "Recent game data coming soon.")
            case .loaded(let games):
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(games) { stat in
                        RecentStatRow(stat: stat, position: player.position ?? "")
                    }
                }
            }
        }
    }

    private func fmt(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }
}

// MARK: - Reusable section building blocks

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title).dsSectionTitle()
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct InfoTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(value).dsCardTitle().lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
}

private struct SectionLoading: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView().tint(Theme.Colors.accent)
            Text("Loading…").dsCaption()
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

private struct SectionError: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Couldn't load. \(message)")
                .dsCallout()
                .foregroundStyle(Theme.Colors.negative)
            Button(action: retry) {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ComingSoon: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "clock.badge.questionmark")
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(text).dsCallout()
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

private struct ScheduleRow: View {
    let game: SupabaseGame
    let team: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("WK \(game.week.map(String.init) ?? "—")")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 44, alignment: .leading)
            Text(matchupText)
                .dsCardTitle()
            Spacer()
            if let date = kickoffText {
                Text(date).dsCaption()
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.md)
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private var matchupText: String {
        let opp = game.opponent(for: team) ?? "TBD"
        return game.isHome(for: team) ? "vs \(opp)" : "@ \(opp)"
    }

    private var kickoffText: String? {
        guard let iso = game.kickoff,
              let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

private struct RecentStatRow: View {
    let stat: SupabaseWeeklyStat
    let position: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("WK \(stat.week.map(String.init) ?? "—")")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(statLine).dsCallout().foregroundStyle(Theme.Colors.textPrimary)
                if let opp = stat.opponent, !opp.isEmpty {
                    Text("vs \(opp)").dsCaption()
                }
            }
            Spacer()
            Text(stat.fantasyPointsPpr.map { String(format: "%.1f", $0) } ?? "—")
                .dsNumeric(16, color: Theme.Colors.accent)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.md)
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    private var statLine: String {
        func i(_ v: Double?) -> Int { Int(v ?? 0) }
        switch position.uppercased() {
        case "QB":
            return "\(i(stat.passingYards)) pass yd · \(i(stat.passingTds)) TD · \(i(stat.rushingYards)) rush yd"
        case "RB":
            return "\(i(stat.rushingYards)) rush yd · \(i(stat.rushingTds)) TD · \(i(stat.receptions)) rec"
        default:
            return "\(i(stat.receptions)) rec · \(i(stat.receivingYards)) yd · \(i(stat.receivingTds)) TD"
        }
    }
}
