import SwiftUI

/// Observable store that drives the Supabase-backed player directory. It exposes
/// an explicit `LoadState` so the view can render loading / empty / error /
/// success without guessing.
@MainActor
final class SupabasePlayerDirectoryStore: ObservableObject {
    @Published var playersState: LoadState<[SupabasePlayer]> = .idle
    @Published var teams: [SupabaseTeam] = []
    @Published var searchText: String = ""
    @Published var selectedTeam: String?
    @Published var selectedPosition: String?

    let positions = ["QB", "RB", "WR", "TE", "K", "DEF"]

    private let service: SupabaseService

    init(service: SupabaseService = .shared) {
        self.service = service
    }

    /// Teams power the team filter menu. They're auxiliary, so a failure here
    /// simply hides the menu rather than blocking the player list.
    func loadTeams() async {
        do {
            teams = try await service.fetchTeams()
        } catch {
            teams = []
        }
    }

    func loadPlayers() async {
        playersState = .loading
        do {
            let players = try await service.fetchPlayers(
                search: searchText.isEmpty ? nil : searchText,
                team: selectedTeam,
                position: selectedPosition
            )
            playersState = players.isEmpty ? .empty : .loaded(players)
        } catch {
            let message = (error as? SupabaseService.ServiceError)?.errorDescription
                ?? error.localizedDescription
            playersState = .failed(message)
        }
    }

    func clearFilters() async {
        searchText = ""
        selectedTeam = nil
        selectedPosition = nil
        await loadPlayers()
    }
}

/// Player directory backed by Supabase, demonstrating search + team/position
/// filters and the three required states (loading, empty, error).
struct SupabasePlayerDirectoryView: View {
    @StateObject private var store = SupabasePlayerDirectoryStore()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                filterBar
                content
            }
            .padding(.top, 8)
            .navigationTitle("Players")
            .searchable(text: $store.searchText, prompt: "Search players by name")
            .onSubmit(of: .search) {
                Task { await store.loadPlayers() }
            }
            .onChange(of: store.selectedPosition) {
                Task { await store.loadPlayers() }
            }
            .onChange(of: store.selectedTeam) {
                Task { await store.loadPlayers() }
            }
            .task {
                await store.loadTeams()
                await store.loadPlayers()
            }
        }
    }

    // MARK: - Filters

    private var filterBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(title: "All", isOn: store.selectedPosition == nil) {
                        store.selectedPosition = nil
                    }
                    ForEach(store.positions, id: \.self) { pos in
                        chip(title: pos, isOn: store.selectedPosition == pos) {
                            store.selectedPosition = (store.selectedPosition == pos) ? nil : pos
                        }
                    }
                }
                .padding(.horizontal)
            }

            if !store.teams.isEmpty {
                HStack {
                    Menu {
                        Button("All teams") { store.selectedTeam = nil }
                        ForEach(store.teams) { team in
                            if let code = team.code {
                                Button(team.displayName) { store.selectedTeam = code }
                            }
                        }
                    } label: {
                        Label(store.selectedTeam ?? "All teams", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    Spacer()
                    if store.selectedTeam != nil || store.selectedPosition != nil || !store.searchText.isEmpty {
                        Button("Clear") { Task { await store.clearFilters() } }
                            .font(.footnote)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - State-driven content

    @ViewBuilder
    private var content: some View {
        switch store.playersState {
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
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading players…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No players found",
            systemImage: "person.crop.circle.badge.questionmark",
            description: Text("Try a different name, team, or position.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Couldn't load players")
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") { Task { await store.loadPlayers() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playerList(_ players: [SupabasePlayer]) -> some View {
        List(players) { player in
            HStack(spacing: 12) {
                Text(player.position ?? "—")
                    .font(.caption.weight(.bold))
                    .frame(width: 40, height: 28)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(player.displayName)
                        .font(.body.weight(.semibold))
                    HStack(spacing: 6) {
                        if let team = player.team, !team.isEmpty {
                            Text(team)
                        }
                        if let age = player.age {
                            Text("• Age \(age)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
        .refreshable { await store.loadPlayers() }
    }
}

#Preview {
    SupabasePlayerDirectoryView()
}
