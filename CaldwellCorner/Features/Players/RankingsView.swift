import SwiftUI

/// Position scope for the rankings list. `FLEX` spans RB/WR/TE and `ALL` covers
/// every fantasy-relevant position (the ranking view is already QB/RB/WR/TE).
enum RankFilter: String, CaseIterable, Identifiable {
    case all = "ALL"
    case qb = "QB"
    case rb = "RB"
    case wr = "WR"
    case te = "TE"
    case flex = "FLEX"

    var id: String { rawValue }

    /// Positions passed to the query. Empty = no position filter.
    var positions: [String] {
        switch self {
        case .all: return []
        case .flex: return ["RB", "WR", "TE"]
        case .qb: return ["QB"]
        case .rb: return ["RB"]
        case .wr: return ["WR"]
        case .te: return ["TE"]
        }
    }

    var tint: Color {
        switch self {
        case .all, .flex: return Theme.Colors.accent
        default: return Theme.Colors.position(rawValue)
        }
    }
}

/// Supabase-backed store for Player Rankings. Loads the top fantasy-relevant
/// players from the `player_rankings` view (ranked by relevance, not
/// alphabetically) and exposes a `LoadState` for loading / empty / error.
@MainActor
final class PlayerRankingsStore: ObservableObject {
    @Published var state: LoadState<[RankedPlayer]> = .idle
    @Published var searchText: String = ""
    @Published var filter: RankFilter = .all

    private let service: SupabaseService
    private var searchTask: Task<Void, Never>?
    private let pageLimit = 300

    init(service: SupabaseService = .shared) {
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            let players = try await service.fetchRankedPlayers(
                positions: filter.positions,
                search: searchText.isEmpty ? nil : searchText,
                limit: pageLimit
            )
            logDebug(players)
            state = players.isEmpty ? .empty : .loaded(players)
        } catch {
            let message =
                (error as? SupabaseService.ServiceError)?.errorDescription
                ?? error.localizedDescription
            #if DEBUG
            print("❌ Supabase rankings error: \(message)")
            #endif
            state = .failed(message)
        }
    }

    private func logDebug(_ players: [RankedPlayer]) {
        #if DEBUG
        let season = players.first?.latestSeason.map(String.init) ?? "unknown"
        print("📅 Latest stats season selected: \(season)")
        print("✅ Eligible players loaded (\(filter.rawValue)): \(players.count)")
        print("🏈 Top 10 by relevance:")
        for (i, p) in players.prefix(10).enumerated() {
            let score = p.relevanceScore.map { String(format: "%.1f", $0) } ?? "—"
            print("   \(i + 1). \(p.displayName) [\(p.position ?? "?")] score=\(score)")
        }
        let byPos = Dictionary(grouping: players, by: { $0.position ?? "?" })
            .mapValues { $0.count }
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: "  ")
        print("📊 Players per position (loaded): \(byPos)")
        #endif
    }

    func searchChanged() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await self?.load()
        }
    }

    func clearSearch() {
        searchText = ""
        Task { await load() }
    }
}

struct RankingsView: View {
    @StateObject private var store = PlayerRankingsStore()

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            searchField.dsScreenPadding()
            filterRow
            content
        }
        .task {
            if case .idle = store.state { await store.load() }
        }
        .onChange(of: store.searchText) { store.searchChanged() }
        .onChange(of: store.filter) { Task { await store.load() } }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.textTertiary)
            TextField("Search any player", text: $store.searchText)
                .font(.system(size: 15))
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !store.searchText.isEmpty {
                Button { store.clearSearch() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 11)
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.Colors.strokeSoft, lineWidth: 1)
        )
    }

    // MARK: - Filters

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(RankFilter.allCases) { f in
                    FilterChip(title: f.rawValue, selected: store.filter == f, color: f.tint) {
                        withAnimation(Theme.Anim.quick) { store.filter = f }
                    }
                }
            }
            .dsScreenPadding()
        }
    }

    // MARK: - State-driven content

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            loadingView
        case .failed(let message):
            errorView(message)
        case .empty:
            emptyView
        case .loaded(let players):
            playerList(players)
        }
    }

    private var loadingView: some View {
        VStack(spacing: Theme.Spacing.md) {
            Spacer()
            ProgressView().tint(Theme.Colors.accent)
            Text("Loading players…").dsCaption()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ScrollView {
            DSEmptyState(
                icon: "magnifyingglass",
                title: "No players found",
                message: "Try a different name or position."
            )
            .padding(.top, Theme.Spacing.xxl)
        }
        .refreshable { await store.load() }
    }

    private func errorView(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.Colors.warning)
                Text("Couldn't load players. Pull to refresh.")
                    .dsCardTitle()
                    .multilineTextAlignment(.center)
                Text(message)
                    .dsCaption()
                    .multilineTextAlignment(.center)
                Button { Task { await store.load() } } label: {
                    Text("Retry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, 9)
                        .background(Theme.Colors.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.Spacing.xxl)
            .dsScreenPadding()
        }
        .refreshable { await store.load() }
    }

    private func playerList(_ players: [RankedPlayer]) -> some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Text("\(players.count) players").dsCaption()
                    Spacer()
                }
                .padding(.bottom, Theme.Spacing.xs)

                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    NavigationLink {
                        SupabasePlayerDetailView(player: player, rank: index + 1)
                    } label: {
                        RankedPlayerRow(rank: index + 1, player: player)
                    }
                    .buttonStyle(.plain)
                }
            }
            .dsScreenPadding()
            .padding(.bottom, Theme.Spacing.xl)
        }
        .refreshable { await store.load() }
    }
}

struct RankedPlayerRow: View {
    let rank: Int
    let player: RankedPlayer

    private var totalPts: String {
        player.totalFantasyPointsPpr.map { String(format: "%.0f", $0) } ?? "—"
    }
    private var ppg: String {
        player.fantasyPointsPerGame.map { String(format: "%.1f", $0) } ?? "—"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(rank)")
                .dsNumeric(15, color: rank <= 3 ? Theme.Colors.accentSecondary : Theme.Colors.textTertiary)
                .frame(width: 28)
            PlayerAvatar(name: player.displayName, position: player.position ?? "", size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName).dsCardTitle().lineLimit(1)
                HStack(spacing: 6) {
                    if let pos = player.position, !pos.isEmpty {
                        PositionBadge(position: pos, compact: true)
                    }
                    Text(player.team?.isEmpty == false ? player.team! : "FA").dsCaption()
                    if let age = player.age {
                        Text("· \(age) yrs").dsCaption()
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(totalPts).dsNumeric(16, color: Theme.Colors.textPrimary)
                Text("\(ppg) PPG").dsCaption()
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}
