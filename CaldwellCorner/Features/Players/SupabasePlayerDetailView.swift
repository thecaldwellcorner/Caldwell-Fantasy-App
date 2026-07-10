import SwiftUI

/// Loads the async sections of the player card (season stats, advanced metrics,
/// recent games, upcoming schedule). Bio/header render instantly from the
/// tapped ranked row, so we never refetch the players list.
@MainActor
final class PlayerDetailStore: ObservableObject {
    @Published var weekly: LoadState<[SupabaseWeeklyStat]> = .idle
    @Published var advanced: LoadState<[AdvancedStat]> = .idle
    @Published var schedule: LoadState<[SupabaseGame]> = .idle

    private let service: SupabaseService

    init(service: SupabaseService = .shared) {
        self.service = service
    }

    func loadAll(playerId: String, team: String) async {
        async let w: Void = loadWeekly(playerId: playerId)
        async let a: Void = loadAdvanced(playerId: playerId)
        async let s: Void = loadSchedule(team: team)
        _ = await (w, a, s)
    }

    func loadWeekly(playerId: String) async {
        weekly = .loading
        do {
            let rows = try await service.fetchWeeklyStats(playerId: playerId)
            weekly = rows.isEmpty ? .empty : .loaded(rows)
        } catch { weekly = .failed(message(error)) }
    }

    func loadAdvanced(playerId: String) async {
        advanced = .loading
        do {
            let rows = try await service.fetchAdvancedStats(playerId: playerId)
            advanced = rows.isEmpty ? .empty : .loaded(rows)
        } catch { advanced = .failed(message(error)) }
    }

    func loadSchedule(team: String) async {
        schedule = .loading
        do {
            let games = try await service.fetchUpcomingGames(team: team, limit: 5)
            schedule = games.isEmpty ? .empty : .loaded(games)
        } catch { schedule = .failed(message(error)) }
    }

    private func message(_ error: Error) -> String {
        (error as? SupabaseService.ServiceError)?.errorDescription ?? error.localizedDescription
    }
}

struct SupabasePlayerDetailView: View {
    let player: RankedPlayer
    var rank: Int?

    @StateObject private var store = PlayerDetailStore()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header
                infoSection
                seasonStatsSection
                advancedSection
                recentSection
                scheduleSection
            }
            .padding(Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .screenBackground()
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadAll(playerId: player.playerId, team: player.team ?? "") }
    }

    // MARK: - Header

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
                        Text(player.team?.isEmpty == false ? player.team! : "Free Agent").dsCallout()
                    }
                }
                Spacer()
            }

            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "IQ Rank", value: rank.map { "#\($0)" } ?? "—", tint: Theme.Colors.accent)
                MetricChip(label: "Total Pts", value: fmt0(player.totalFantasyPointsPpr), tint: Theme.Colors.accentSecondary)
                MetricChip(label: "PPG", value: fmt1(player.fantasyPointsPerGame), tint: Theme.Colors.positive)
            }
        }
        .card(elevated: true)
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
                InfoTile(label: "Season", value: player.latestSeason.map(String.init) ?? "—")
            }
            InfoTile(label: "Sleeper ID", value: player.sleeperId ?? "—")
        }
    }

    private var weightLabel: String {
        guard let w = player.weight, !w.isEmpty else { return "—" }
        return w.contains("lb") ? w : "\(w) lb"
    }

    // MARK: - Season stats (latest completed season)

    private var latestWeeklyRows: [SupabaseWeeklyStat] {
        guard let rows = store.weekly.value, let season = rows.compactMap(\.season).max() else { return [] }
        return rows.filter { $0.season == season }
    }

    private var seasonStatsSection: some View {
        DetailSection(title: "Season Stats") {
            switch store.weekly {
            case .idle, .loading:
                SectionLoading()
            case .failed(let msg):
                SectionError(message: msg) { Task { await store.loadWeekly(playerId: player.playerId) } }
            case .empty:
                ComingSoon(text: "Season stats coming soon.")
            case .loaded:
                seasonTiles(latestWeeklyRows)
            }
        }
    }

    private func seasonTiles(_ rows: [SupabaseWeeklyStat]) -> some View {
        func sum(_ kp: (SupabaseWeeklyStat) -> Double?) -> Double {
            rows.reduce(0) { $0 + (kp($1) ?? 0) }
        }
        let games = rows.count
        let totalPpr = rows.reduce(0.0) { $0 + ($1.fantasyPointsPpr ?? 0) }
        let ppg = games > 0 ? totalPpr / Double(games) : 0
        let pos = (player.position ?? "").uppercased()

        var tiles: [(String, String)] = [
            ("Games", String(games)),
            ("Total PPR", String(format: "%.1f", totalPpr)),
            ("PPG", String(format: "%.1f", ppg)),
        ]
        switch pos {
        case "QB":
            tiles += [
                ("Pass Yds", fmt0(sum { $0.passingYards })),
                ("Pass TD", fmt0(sum { $0.passingTouchdowns })),
                ("INT", fmt0(sum { $0.interceptions })),
                ("Rush Yds", fmt0(sum { $0.rushingYards })),
                ("Rush TD", fmt0(sum { $0.rushingTouchdowns })),
            ]
        case "RB":
            tiles += [
                ("Rush Yds", fmt0(sum { $0.rushingYards })),
                ("Rush TD", fmt0(sum { $0.rushingTouchdowns })),
                ("Rec", fmt0(sum { $0.receptions })),
                ("Rec Yds", fmt0(sum { $0.receivingYards })),
                ("Rec TD", fmt0(sum { $0.receivingTouchdowns })),
            ]
        default:
            tiles += [
                ("Rec", fmt0(sum { $0.receptions })),
                ("Targets", fmt0(sum { $0.targets })),
                ("Rec Yds", fmt0(sum { $0.receivingYards })),
                ("Rec TD", fmt0(sum { $0.receivingTouchdowns })),
            ]
        }

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            ForEach(tiles, id: \.0) { tile in
                InfoTile(label: tile.0, value: tile.1)
            }
        }
    }

    // MARK: - Advanced metrics (only show fields with real values)

    private var advancedSection: some View {
        DetailSection(title: "Advanced Metrics") {
            switch store.advanced {
            case .idle, .loading:
                SectionLoading()
            case .failed(let msg):
                SectionError(message: msg) { Task { await store.loadAdvanced(playerId: player.playerId) } }
            case .empty:
                ComingSoon(text: "Advanced metrics coming soon.")
            case .loaded(let rows):
                advancedTiles(rows)
            }
        }
    }

    @ViewBuilder
    private func advancedTiles(_ rows: [AdvancedStat]) -> some View {
        let present = presentAdvancedMetrics(rows)
        if present.isEmpty {
            ComingSoon(text: "Advanced metrics coming soon.")
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                ForEach(present, id: \.label) { metric in
                    InfoTile(label: metric.label, value: metric.value)
                }
            }
        }
    }

    /// Averages advanced metrics over the latest season and returns only those
    /// with real (non-null) values, formatted for display. Kept out of the
    /// `@ViewBuilder` above so its `return`s don't disable the result builder.
    private func presentAdvancedMetrics(_ rows: [AdvancedStat]) -> [(label: String, value: String)] {
        let latest = rows.compactMap(\.season).max()
        let seasonRows = latest == nil ? rows : rows.filter { $0.season == latest }
        func avg(_ kp: (AdvancedStat) -> Double?) -> Double? {
            let vals = seasonRows.compactMap(kp)
            return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
        }
        let metrics: [(String, Double?, Bool)] = [
            ("Target Share", avg { $0.targetShare }, true),
            ("Air Yards Share", avg { $0.airYardsShare }, true),
            ("Route Part.", avg { $0.routeParticipation }, true),
            ("YPRR", avg { $0.yardsPerRouteRun }, false),
            ("EPA/Play", avg { $0.epaPerPlay }, false),
            ("Success Rate", avg { $0.successRate }, true),
            ("xFP", avg { $0.expectedFantasyPoints }, false),
            ("FPOE", avg { $0.fantasyPointsOverExpected }, false),
        ]
        return metrics.compactMap { metric in
            guard let value = metric.1 else { return nil }
            return (metric.0, metric.2 ? pct(value) : fmt2(value))
        }
    }

    // MARK: - Recent performance (last 5 games)

    private var recentSection: some View {
        DetailSection(title: "Recent Performance") {
            switch store.weekly {
            case .idle, .loading:
                SectionLoading()
            case .failed(let msg):
                SectionError(message: msg) { Task { await store.loadWeekly(playerId: player.playerId) } }
            case .empty:
                ComingSoon(text: "Recent game data coming soon.")
            case .loaded(let rows):
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(rows.prefix(5)) { stat in
                        RecentStatRow(stat: stat, position: player.position ?? "")
                    }
                }
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

    // MARK: - Formatting

    private func fmt0(_ v: Double?) -> String { v.map { String(format: "%.0f", $0) } ?? "—" }
    private func fmt1(_ v: Double?) -> String { v.map { String(format: "%.1f", $0) } ?? "—" }
    private func fmt2(_ v: Double?) -> String { v.map { String(format: "%.2f", $0) } ?? "—" }
    private func pct(_ v: Double?) -> String { v.map { String(format: "%.0f%%", $0 * 100) } ?? "—" }
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
            Text(matchupText).dsCardTitle()
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
        guard let iso = game.kickoffAt else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
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
            return "\(i(stat.passingYards)) pass yd · \(i(stat.passingTouchdowns)) TD · \(i(stat.rushingYards)) rush yd"
        case "RB":
            return "\(i(stat.rushingYards)) rush yd · \(i(stat.rushingTouchdowns)) TD · \(i(stat.receptions)) rec"
        default:
            return "\(i(stat.receptions)) rec · \(i(stat.receivingYards)) yd · \(i(stat.receivingTouchdowns)) TD"
        }
    }
}
