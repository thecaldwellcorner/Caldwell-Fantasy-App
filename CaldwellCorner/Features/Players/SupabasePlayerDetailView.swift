import SwiftUI

// MARK: - Store

/// Loads the async sections of the player card. Bio/header render instantly from
/// the tapped ranked row; weekly stats, advanced stats, upcoming schedule, and
/// the season's games (for home/away) load asynchronously and are cached for the
/// lifetime of this screen (@StateObject).
@MainActor
final class PlayerDetailStore: ObservableObject {
    @Published var weekly: LoadState<[SupabaseWeeklyStat]> = .idle
    @Published var advanced: LoadState<[AdvancedStat]> = .idle
    @Published var schedule: LoadState<[SupabaseGame]> = .idle
    @Published var seasonGames: [SupabaseGame] = []

    private let service: SupabaseService

    init(service: SupabaseService = .shared) {
        self.service = service
    }

    func loadAll(playerId: String, team: String) async {
        async let a: Void = loadAdvanced(playerId: playerId)
        async let s: Void = loadSchedule(team: team)
        await loadWeekly(playerId: playerId)
        _ = await (a, s)

        if let season = latestSeason, !team.isEmpty {
            seasonGames = (try? await service.fetchSeasonGames(team: team, season: season)) ?? []
        }
    }

    var latestSeason: Int? { weekly.value?.compactMap(\.season).max() }

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
        let msg = (error as? SupabaseService.ServiceError)?.errorDescription ?? error.localizedDescription
        #if DEBUG
        print("❌ Player detail load error: \(msg)")
        #endif
        return msg
    }
}

// MARK: - Local enums

private enum DetailSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case gameLog = "Game Log"
    case advanced = "Advanced"
    case schedule = "Schedule"
    var id: String { rawValue }
}

private enum DetailScoring: String, CaseIterable, Identifiable {
    case ppr = "PPR"
    case half = "Half"
    case standard = "Std"
    var id: String { rawValue }

    func points(_ s: SupabaseWeeklyStat) -> Double? {
        switch self {
        case .ppr: return s.fantasyPointsPpr
        case .half: return s.fantasyPointsHalfPpr
        case .standard: return s.fantasyPointsStandard
        }
    }
}

// MARK: - Detail view

struct SupabasePlayerDetailView: View {
    let player: RankedPlayer
    var rank: Int?

    @StateObject private var store = PlayerDetailStore()
    @State private var section: DetailSection = .overview
    @State private var scoring: DetailScoring = .ppr
    @State private var expandedWeek: SupabaseWeeklyStat?

    private var position: String { (player.position ?? "").uppercased() }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                header
                DSSegmented(items: DetailSection.allCases, title: { $0.rawValue }, selection: $section)
                sectionContent
            }
            .padding(Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .screenBackground()
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadAll(playerId: player.playerId, team: player.team ?? "") }
        .sheet(item: $expandedWeek) { stat in
            WeeklyBreakdownView(
                stat: stat,
                position: position,
                scoring: scoring,
                advanced: advancedByWeek[stat.week ?? -1],
                game: gameByWeek[stat.week ?? -1],
                team: player.team ?? ""
            )
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .overview: overviewSection
        case .gameLog: gameLogSection
        case .advanced: advancedSection
        case .schedule: scheduleSection
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.lg) {
                PlayerAvatar(name: player.displayName, position: position, size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text(player.displayName).dsScreenTitle().lineLimit(2)
                    HStack(spacing: 6) {
                        if !position.isEmpty { PositionBadge(position: position) }
                        Text(player.team?.isEmpty == false ? player.team! : "Free Agent").dsCallout()
                        Circle().fill(Theme.Colors.positive).frame(width: 6, height: 6)
                        Text("Active").dsCaption()
                    }
                }
                Spacer()
            }
            bioFacts
        }
        .card(elevated: true)
    }

    private var bioFacts: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            fact("Age", player.age.map(String.init) ?? "—")
            fact("Height", PlayerFormat.height(player.height))
            fact("Weight", PlayerFormat.weight(player.weight))
            fact("Exp", "—")
            fact("College", "—")
            fact("Season", player.latestSeason.map(String.init) ?? "—")
        }
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold)).tracking(0.4)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(value).dsCallout().foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scoringToggle: some View {
        HStack {
            Text("Scoring").dsCaption()
            Spacer()
            DSSegmented(items: DetailScoring.allCases, title: { $0.rawValue }, selection: $scoring)
                .frame(width: 190)
        }
    }

    // MARK: Derived data

    private var latestRows: [SupabaseWeeklyStat] {
        guard let rows = store.weekly.value, let season = store.latestSeason else { return [] }
        return rows.filter { $0.season == season && ($0.week ?? 0) > 0 }
    }

    private var advancedByWeek: [Int: AdvancedStat] {
        guard let rows = store.advanced.value, let season = store.latestSeason else { return [:] }
        var map: [Int: AdvancedStat] = [:]
        for r in rows where r.season == season { if let w = r.week { map[w] = r } }
        return map
    }

    private var gameByWeek: [Int: SupabaseGame] {
        var map: [Int: SupabaseGame] = [:]
        for g in store.seasonGames { if let w = g.week { map[w] = g } }
        return map
    }

    // MARK: Overview

    @ViewBuilder
    private var overviewSection: some View {
        switch store.weekly {
        case .idle, .loading:
            DetailSectionCard(title: "Season Summary") { SectionLoading() }
        case .failed(let msg):
            DetailSectionCard(title: "Season Summary") {
                SectionError(message: msg) { Task { await store.loadWeekly(playerId: player.playerId) } }
            }
        case .empty:
            DetailSectionCard(title: "Season Summary") { ComingSoon(text: "Season stats coming soon.") }
        case .loaded:
            VStack(spacing: Theme.Spacing.lg) {
                scoringToggle
                seasonSummaryCard
                recentFormCard
                freshnessFooter(rows: latestRows.map { ($0.source, $0.updatedAt) }, season: store.latestSeason)
            }
        }
    }

    private var seasonSummaryCard: some View {
        let rows = latestRows
        let scores = rows.compactMap { scoring.points($0) }
        let games = rows.count
        let total = scores.reduce(0, +)
        let ppg = games > 0 ? total / Double(games) : nil
        let totalTd = rows.reduce(0.0) {
            $0 + ($1.passingTouchdowns ?? 0) + ($1.rushingTouchdowns ?? 0) + ($1.receivingTouchdowns ?? 0)
        }
        let tiles: [(String, String)] = [
            ("Games", String(games)),
            ("Total \(scoring.rawValue)", PlayerFormat.num(total, digits: 1)),
            ("PPG", PlayerFormat.num(ppg, digits: 1)),
            ("Pos Rank", "—"),
            ("Best Wk", PlayerFormat.num(scores.max(), digits: 1, applicable: !scores.isEmpty)),
            ("Worst Wk", PlayerFormat.num(scores.min(), digits: 1, applicable: !scores.isEmpty)),
            ("Total TD", PlayerFormat.num(totalTd, digits: 0)),
            ("Volume", volumeSummary(rows)),
        ]
        return DetailSectionCard(title: "Season Summary") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                ForEach(tiles, id: \.0) { StatTile(label: $0.0, value: $0.1) }
            }
        }
    }

    private func volumeSummary(_ rows: [SupabaseWeeklyStat]) -> String {
        switch position {
        case "QB":
            return "—"  // pass attempts are not stored in player_weekly_stats yet
        case "RB":
            let v = rows.reduce(0.0) { $0 + ($1.rushingAttempts ?? 0) + ($1.targets ?? 0) }
            return PlayerFormat.num(v, digits: 0)
        default:
            let v = rows.reduce(0.0) { $0 + ($1.targets ?? 0) }
            return PlayerFormat.num(v, digits: 0)
        }
    }

    private var recentFormCard: some View {
        let recent = Array(latestRows.sorted { ($0.week ?? 0) < ($1.week ?? 0) }.suffix(5))
        let scores = recent.compactMap { scoring.points($0) }
        let avg = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        let trend: StatGrade = {
            guard let first = scores.first, let last = scores.last, scores.count >= 2 else { return .neutral }
            if last > first + 1 { return .strong }
            if last < first - 1 { return .poor }
            return .average
        }()
        let trendIcon = trend == .strong ? "arrow.up.right" : trend == .poor ? "arrow.down.right" : "arrow.right"
        return DetailSectionCard(title: "Recent Form (last \(recent.count))") {
            if scores.isEmpty {
                ComingSoon(text: "No recent games.")
            } else {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, s in
                        let g = FantasyGrade.weeklyPoints(scoring.points(s), position: position)
                        Text(PlayerFormat.points(scoring.points(s)))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(g.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(g.fill)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    }
                    VStack(spacing: 2) {
                        Image(systemName: trendIcon).foregroundStyle(trend.text)
                        Text(PlayerFormat.num(avg, digits: 1)).dsCaption()
                    }
                    .frame(width: 52)
                }
            }
        }
    }

    // MARK: Game Log

    @ViewBuilder
    private var gameLogSection: some View {
        switch store.weekly {
        case .idle, .loading:
            DetailSectionCard(title: "Game Log") { SectionLoading() }
        case .failed(let msg):
            DetailSectionCard(title: "Game Log") {
                SectionError(message: msg) { Task { await store.loadWeekly(playerId: player.playerId) } }
            }
        case .empty:
            DetailSectionCard(title: "Game Log") { ComingSoon(text: "Game log coming soon.") }
        case .loaded:
            VStack(spacing: Theme.Spacing.lg) {
                scoringToggle
                gameLogTable
                gradeLegend
                freshnessFooter(rows: latestRows.map { ($0.source, $0.updatedAt) }, season: store.latestSeason)
            }
        }
    }

    private var gameLogTable: some View {
        let rows = GameLogBuilder.rows(from: latestRows)
        let headers = GameLogBuilder.statHeaders(position)
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("\(player.latestSeason.map(String.init) ?? "") Season").dsCaption()
            HStack(alignment: .top, spacing: 0) {
                // Frozen columns: week + opponent
                VStack(spacing: 1) {
                    frozenHeader
                    ForEach(rows) { row in frozenCell(row) }
                }
                // Horizontally scrollable stat columns
                ScrollView(.horizontal, showsIndicators: true) {
                    VStack(spacing: 1) {
                        HStack(spacing: 1) {
                            ForEach(headers, id: \.self) { h in cellText(h, grade: .neutral, header: true) }
                        }
                        ForEach(rows) { row in statRow(row, headers: headers) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
    }

    private var frozenHeader: some View {
        HStack(spacing: 1) {
            cellText("WK", grade: .neutral, header: true, width: 34)
            cellText("OPP", grade: .neutral, header: true, width: 62)
        }
    }

    @ViewBuilder
    private func frozenCell(_ row: GameLogBuilder.Row) -> some View {
        switch row {
        case .bye(let wk):
            HStack(spacing: 1) {
                cellText("\(wk)", grade: .neutral, width: 34)
                cellText("BYE", grade: .neutral, width: 62)
            }
        case .game(let s):
            Button { expandedWeek = s } label: {
                HStack(spacing: 1) {
                    cellText("\(s.week ?? 0)", grade: .neutral, width: 34)
                    cellText(opponentLabel(s), grade: .neutral, width: 62)
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func statRow(_ row: GameLogBuilder.Row, headers: [String]) -> some View {
        switch row {
        case .bye:
            HStack(spacing: 1) {
                ForEach(headers, id: \.self) { _ in cellText("—", grade: .neutral) }
            }
        case .game(let s):
            let cells = GameLogBuilder.statCells(s, position: position, points: scoring.points(s), advanced: advancedByWeek[s.week ?? -1])
            Button { expandedWeek = s } label: {
                HStack(spacing: 1) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        cellText(cell.0, grade: cell.1)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func opponentLabel(_ s: SupabaseWeeklyStat) -> String {
        let opp = s.opponent?.isEmpty == false ? s.opponent! : (gameByWeek[s.week ?? -1]?.opponent(for: player.team ?? "") ?? "—")
        if let g = gameByWeek[s.week ?? -1] {
            return (g.isHome(for: player.team ?? "") ? "" : "@") + opp
        }
        return opp
    }

    private func cellText(_ text: String, grade: StatGrade, header: Bool = false, width: CGFloat = 52) -> some View {
        Text(text)
            .font(.system(size: header ? 10 : 12, weight: header ? .semibold : .medium, design: .rounded))
            .foregroundStyle(header ? Theme.Colors.textTertiary : grade.text)
            .frame(width: width, height: 34)
            .background(header ? Theme.Colors.surfaceHighlight : grade.fill)
    }

    private var gradeLegend: some View {
        HStack(spacing: Theme.Spacing.md) {
            legendDot(.strong, "Strong")
            legendDot(.average, "Avg")
            legendDot(.poor, "Poor")
            legendDot(.neutral, "N/A")
            Spacer()
        }
    }

    private func legendDot(_ g: StatGrade, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(g.fill).frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(g.text.opacity(0.5), lineWidth: 1))
            Text(label).dsCaption()
        }
    }

    // MARK: Advanced

    @ViewBuilder
    private var advancedSection: some View {
        switch store.advanced {
        case .idle, .loading:
            DetailSectionCard(title: "Advanced Metrics") { SectionLoading() }
        case .failed(let msg):
            DetailSectionCard(title: "Advanced Metrics") {
                SectionError(message: msg) { Task { await store.loadAdvanced(playerId: player.playerId) } }
            }
        case .empty:
            DetailSectionCard(title: "Advanced Metrics") { ComingSoon(text: "Advanced metrics coming soon.") }
        case .loaded(let rows):
            advancedGroups(rows)
        }
    }

    @ViewBuilder
    private func advancedGroups(_ rows: [AdvancedStat]) -> some View {
        let season = store.latestSeason
        let seasonRows = season == nil ? rows : rows.filter { $0.season == season }
        let usage = AdvancedBuilder.group(seasonRows, metrics: AdvancedBuilder.usage)
        let efficiency = AdvancedBuilder.group(seasonRows, metrics: AdvancedBuilder.efficiency)
        let value = AdvancedBuilder.group(seasonRows, metrics: AdvancedBuilder.fantasyValue)

        if usage.isEmpty && efficiency.isEmpty && value.isEmpty {
            DetailSectionCard(title: "Advanced Metrics") {
                ComingSoon(text: "No advanced metrics with real values yet.")
            }
        } else {
            VStack(spacing: Theme.Spacing.lg) {
                if !usage.isEmpty { advancedCard("Usage", usage) }
                if !efficiency.isEmpty { advancedCard("Efficiency", efficiency) }
                if !value.isEmpty { advancedCard("Fantasy Value", value) }
                freshnessFooter(rows: seasonRows.map { ($0.source, $0.updatedAt) }, season: season)
            }
        }
    }

    private func advancedCard(_ title: String, _ metrics: [(String, String)]) -> some View {
        DetailSectionCard(title: title) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                ForEach(metrics, id: \.0) { StatTile(label: $0.0, value: $0.1) }
            }
        }
    }

    // MARK: Schedule

    @ViewBuilder
    private var scheduleSection: some View {
        switch store.schedule {
        case .idle, .loading:
            DetailSectionCard(title: "Upcoming Schedule") { SectionLoading() }
        case .failed(let msg):
            DetailSectionCard(title: "Upcoming Schedule") {
                SectionError(message: msg) { Task { await store.loadSchedule(team: player.team ?? "") } }
            }
        case .empty:
            DetailSectionCard(title: "Upcoming Schedule") { ComingSoon(text: "Schedule data coming soon.") }
        case .loaded(let games):
            VStack(spacing: Theme.Spacing.lg) {
                DetailSectionCard(title: "Upcoming Schedule") {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(games) { g in ScheduleRow(game: g, team: player.team ?? "") }
                    }
                }
                freshnessFooter(rows: games.map { ($0.source, $0.updatedAt) }, season: games.first?.season)
            }
        }
    }

    // MARK: Freshness footer

    private func freshnessFooter(rows: [(String?, String?)], season: Int?) -> some View {
        let latestUpdated = rows.compactMap { $0.1 }.max()
        let source = rows.compactMap { $0.0 }.first
        return HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
            Text("Season \(season.map(String.init) ?? "—")").dsCaption()
            if let source { Text("· \(source)").dsCaption() }
            if let latestUpdated { Text("· Updated \(PlayerFormat.shortDate(latestUpdated))").dsCaption() }
            Spacer()
        }
    }
}

// MARK: - Game-log column building (plain data, kept out of @ViewBuilder)

enum GameLogBuilder {
    enum Row: Identifiable {
        case game(SupabaseWeeklyStat)
        case bye(Int)
        var id: String {
            switch self {
            case .game(let s): return "g\(s.week ?? 0)"
            case .bye(let w): return "b\(w)"
            }
        }
    }

    /// Weeks first..last with real rows; interior missing weeks become BYE.
    static func rows(from weekly: [SupabaseWeeklyStat]) -> [Row] {
        let games = weekly.compactMap { s -> (Int, SupabaseWeeklyStat)? in s.week.map { ($0, s) } }
            .sorted { $0.0 < $1.0 }
        guard let first = games.first?.0, let last = games.last?.0 else { return [] }
        let byWeek = Dictionary(games, uniquingKeysWith: { a, _ in a })
        return (first...last).map { wk in byWeek[wk].map { Row.game($0) } ?? Row.bye(wk) }
    }

    static func statHeaders(_ position: String) -> [String] {
        switch position.uppercased() {
        case "QB": return ["FPTS", "C", "ATT", "PYDS", "PTD", "INT", "CAR", "RYDS", "RTD"]
        case "RB": return ["FPTS", "CAR", "RYDS", "YPC", "RTD", "TGT", "REC", "REYD", "RETD", "TD"]
        default: return ["FPTS", "TGT", "REC", "REYD", "YPR", "RETD", "TS%", "YPRR"]
        }
    }

    static func statCells(
        _ s: SupabaseWeeklyStat,
        position: String,
        points: Double?,
        advanced: AdvancedStat?
    ) -> [(String, StatGrade)] {
        let pos = position.uppercased()
        let fpts = (PlayerFormat.points(points), FantasyGrade.weeklyPoints(points, position: pos))
        func plain(_ v: Double?, _ digits: Int = 0) -> (String, StatGrade) { (PlayerFormat.num(v, digits: digits), .neutral) }

        switch pos {
        case "QB":
            return [
                fpts,
                ("—", .neutral),  // completions not stored
                ("—", .neutral),  // attempts not stored
                (PlayerFormat.num(s.passingYards, digits: 0), FantasyGrade.primaryYards(s.passingYards, position: pos)),
                (PlayerFormat.num(s.passingTouchdowns, digits: 0), FantasyGrade.touchdowns(s.passingTouchdowns)),
                plain(s.interceptions),
                plain(s.rushingAttempts),
                plain(s.rushingYards),
                (PlayerFormat.num(s.rushingTouchdowns, digits: 0), FantasyGrade.touchdowns(s.rushingTouchdowns)),
            ]
        case "RB":
            let ypc = (s.rushingAttempts ?? 0) > 0 ? (s.rushingYards ?? 0) / (s.rushingAttempts ?? 1) : nil
            let totalTd = (s.rushingTouchdowns ?? 0) + (s.receivingTouchdowns ?? 0)
            return [
                fpts,
                plain(s.rushingAttempts),
                (PlayerFormat.num(s.rushingYards, digits: 0), FantasyGrade.primaryYards(s.rushingYards, position: pos)),
                (PlayerFormat.num(ypc, digits: 1, applicable: ypc != nil), .neutral),
                (PlayerFormat.num(s.rushingTouchdowns, digits: 0), FantasyGrade.touchdowns(s.rushingTouchdowns)),
                plain(s.targets),
                plain(s.receptions),
                plain(s.receivingYards),
                (PlayerFormat.num(s.receivingTouchdowns, digits: 0), FantasyGrade.touchdowns(s.receivingTouchdowns)),
                (PlayerFormat.num(totalTd, digits: 0), FantasyGrade.touchdowns(totalTd)),
            ]
        default:  // WR / TE
            let ypr = (s.receptions ?? 0) > 0 ? (s.receivingYards ?? 0) / (s.receptions ?? 1) : nil
            let ts = advanced?.targetShare
            return [
                fpts,
                plain(s.targets),
                plain(s.receptions),
                (PlayerFormat.num(s.receivingYards, digits: 0), FantasyGrade.primaryYards(s.receivingYards, position: pos)),
                (PlayerFormat.num(ypr, digits: 1, applicable: ypr != nil), .neutral),
                (PlayerFormat.num(s.receivingTouchdowns, digits: 0), FantasyGrade.touchdowns(s.receivingTouchdowns)),
                (ts != nil ? PlayerFormat.num((ts ?? 0) * 100, digits: 0) + "%" : "—", .neutral),
                (PlayerFormat.num(advanced?.yardsPerRouteRun, digits: 1, applicable: advanced?.yardsPerRouteRun != nil), .neutral),
            ]
        }
    }
}

// MARK: - Advanced metric grouping

enum AdvancedBuilder {
    typealias Metric = (label: String, value: (AdvancedStat) -> Double?, percent: Bool)

    static let usage: [Metric] = [
        ("Target Share", { $0.targetShare }, true),
        ("Air Yards Share", { $0.airYardsShare }, true),
        ("Route Participation", { $0.routeParticipation }, true),
    ]
    static let efficiency: [Metric] = [
        ("Yds / Route Run", { $0.yardsPerRouteRun }, false),
        ("EPA / Play", { $0.epaPerPlay }, false),
        ("Success Rate", { $0.successRate }, true),
    ]
    static let fantasyValue: [Metric] = [
        ("Expected FP", { $0.expectedFantasyPoints }, false),
        ("FP Over Expected", { $0.fantasyPointsOverExpected }, false),
    ]

    /// Average each metric over the season rows; keep only metrics with a real value.
    static func group(_ rows: [AdvancedStat], metrics: [Metric]) -> [(String, String)] {
        metrics.compactMap { metric in
            let values = rows.compactMap(metric.value)
            guard !values.isEmpty else { return nil }
            let avg = values.reduce(0, +) / Double(values.count)
            let text = metric.percent ? String(format: "%.0f%%", avg * 100) : String(format: "%.2f", avg)
            return (metric.label, text)
        }
    }
}

// MARK: - Weekly breakdown sheet

private struct WeeklyBreakdownView: View {
    let stat: SupabaseWeeklyStat
    let position: String
    let scoring: DetailScoring
    let advanced: AdvancedStat?
    let game: SupabaseGame?
    let team: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    DetailSectionCard(title: "Box Score") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                            ForEach(boxScore, id: \.0) { StatTile(label: $0.0, value: $0.1) }
                        }
                    }
                    DetailSectionCard(title: "Fantasy Points") {
                        HStack(spacing: Theme.Spacing.sm) {
                            StatTile(label: "PPR", value: PlayerFormat.points(stat.fantasyPointsPpr))
                            StatTile(label: "Half", value: PlayerFormat.points(stat.fantasyPointsHalfPpr))
                            StatTile(label: "Std", value: PlayerFormat.points(stat.fantasyPointsStandard))
                        }
                    }
                    if !weeklyAdvanced.isEmpty {
                        DetailSectionCard(title: "Advanced (Week)") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                                ForEach(weeklyAdvanced, id: \.0) { StatTile(label: $0.0, value: $0.1) }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("Week \(stat.week.map(String.init) ?? "")")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(matchupLine).dsSectionTitle()
            if let result { Text(result).dsCaption() }
        }
    }

    private var matchupLine: String {
        let opp = stat.opponent?.isEmpty == false ? stat.opponent! : (game?.opponent(for: team) ?? "—")
        let ha = game.map { $0.isHome(for: team) ? "vs" : "@" } ?? "vs"
        return "\(ha) \(opp)"
    }

    private var result: String? {
        guard let g = game, let hs = g.homeScore, let as_ = g.awayScore else { return nil }
        let home = g.isHome(for: team)
        let us = home ? hs : as_
        let them = home ? as_ : hs
        let outcome = us > them ? "W" : (us < them ? "L" : "T")
        return "\(outcome) \(us)–\(them)"
    }

    private var boxScore: [(String, String)] {
        switch position.uppercased() {
        case "QB":
            return [
                ("Pass Yds", PlayerFormat.num(stat.passingYards)),
                ("Pass TD", PlayerFormat.num(stat.passingTouchdowns)),
                ("INT", PlayerFormat.num(stat.interceptions)),
                ("Rush Att", PlayerFormat.num(stat.rushingAttempts)),
                ("Rush Yds", PlayerFormat.num(stat.rushingYards)),
                ("Rush TD", PlayerFormat.num(stat.rushingTouchdowns)),
            ]
        case "RB":
            return [
                ("Rush Att", PlayerFormat.num(stat.rushingAttempts)),
                ("Rush Yds", PlayerFormat.num(stat.rushingYards)),
                ("Rush TD", PlayerFormat.num(stat.rushingTouchdowns)),
                ("Targets", PlayerFormat.num(stat.targets)),
                ("Rec", PlayerFormat.num(stat.receptions)),
                ("Rec Yds", PlayerFormat.num(stat.receivingYards)),
                ("Rec TD", PlayerFormat.num(stat.receivingTouchdowns)),
                ("Fum Lost", PlayerFormat.num(stat.fumblesLost)),
            ]
        default:
            return [
                ("Targets", PlayerFormat.num(stat.targets)),
                ("Rec", PlayerFormat.num(stat.receptions)),
                ("Rec Yds", PlayerFormat.num(stat.receivingYards)),
                ("Rec TD", PlayerFormat.num(stat.receivingTouchdowns)),
                ("Fum Lost", PlayerFormat.num(stat.fumblesLost)),
            ]
        }
    }

    private var weeklyAdvanced: [(String, String)] {
        guard let a = advanced else { return [] }
        return AdvancedBuilder.group([a], metrics: AdvancedBuilder.usage + AdvancedBuilder.efficiency + AdvancedBuilder.fantasyValue)
    }
}

// MARK: - Reusable building blocks

private struct DetailSectionCard<Content: View>: View {
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

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold)).tracking(0.4)
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
            Text("Couldn't load. \(message)").dsCallout().foregroundStyle(Theme.Colors.negative)
            Button(action: retry) {
                Text("Retry").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ComingSoon: View {
    let text: String
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "clock.badge.questionmark").foregroundStyle(Theme.Colors.textTertiary)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(matchupText).dsCardTitle()
                Text(PlayerFormat.kickoff(game.kickoffAt)).dsCaption()
            }
            Spacer()
            if let status = game.status, !status.isEmpty {
                Text(status.capitalized).dsCaption()
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
}
