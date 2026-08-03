import SwiftUI

/// Connect a Sleeper account by username, pick a league, and view the imported
/// roster (matched to Caldwell IQ players). Sleeper is read-only — no password
/// or email is requested.
struct SleeperConnectView: View {
    @ObservedObject private var store = SleeperStore.shared
    @State private var username = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                content
            }
            .padding(Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .screenBackground()
        .navigationTitle("Connect Sleeper")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .disconnected:
            connectForm(error: nil)
        case .failed(let message):
            connectForm(error: message)
        case .connecting:
            loading("Finding your Sleeper account…")
        case .leagues(let leagues):
            leaguePicker(leagues)
        case .syncing:
            loading("Importing your league…")
        case .connected:
            connectedView
        }
    }

    // MARK: Connect form

    private func connectForm(error: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            DSEyebrow(text: "Read-only • no password", color: Theme.Colors.accent)
            Text("Connect your Sleeper account").dsSectionTitle()
            Text("Enter your Sleeper username to import your leagues and roster.").dsCallout()

            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "person.circle").foregroundStyle(Theme.Colors.textTertiary)
                TextField("Sleeper username", text: $username)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { submit() }
            }
            .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
            .background(Theme.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.Colors.stroke, lineWidth: 1))

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .dsCaption().foregroundStyle(Theme.Colors.negative)
            }

            PrimaryButton(title: "Connect Sleeper", systemImage: "link") { submit() }
                .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .card()
    }

    private func submit() {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task { await store.connect(username: name) }
    }

    // MARK: League picker

    private func leaguePicker(_ leagues: [SleeperLeague]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Select a league").dsSectionTitle()
            ForEach(leagues) { league in
                Button { Task { await store.selectLeague(league) } } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(league.name ?? "League").dsCardTitle()
                        HStack(spacing: 8) {
                            Tag(text: league.scoringFormat, color: Theme.Colors.accent)
                            Text("\(league.totalRosters ?? 0) teams").dsCaption()
                            if let season = league.season { Text("· \(season)").dsCaption() }
                            if let status = league.status { Text("· \(status.capitalized)").dsCaption() }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: Theme.Spacing.md)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Connected

    @ViewBuilder
    private var connectedView: some View {
        if let conn = store.connection {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    DSEyebrow(text: "Connected • \(conn.scoringFormat)", color: Theme.Colors.positive)
                    Text(conn.leagueName).dsSectionTitle()
                    Text("\(conn.teamName) · @\(conn.username)").dsCallout()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(elevated: true)

                if let roster = store.roster {
                    rosterSection("Starters", players: roster.starters)
                    rosterSection("Bench", players: roster.bench)
                    if !roster.unmatched.isEmpty {
                        Text("\(roster.unmatched.count) roster player(s) couldn't be matched to the player database yet.")
                            .dsCaption()
                    }
                } else {
                    loading("Loading your roster…")
                }

                Button(role: .destructive) { store.disconnect() } label: {
                    Text("Disconnect Sleeper").font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.Colors.negative)
            }
        }
    }

    private func rosterSection(_ title: String, players: [RankedPlayer]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(title).dsSectionTitle()
                Spacer()
                Text("\(players.count)").dsCaption()
            }
            if players.isEmpty {
                Text("—").dsCaption()
            } else {
                ForEach(players) { player in
                    NavigationLink { SupabasePlayerDetailView(player: player) } label: {
                        SleeperRosterRow(player: player)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loading(_ text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProgressView().tint(Theme.Colors.accent)
            Text(text).dsCallout()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xl)
    }
}

private struct SleeperRosterRow: View {
    let player: RankedPlayer
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PlayerAvatar(name: player.displayName, position: player.position ?? "", size: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName).dsCardTitle().lineLimit(1)
                HStack(spacing: 6) {
                    if let pos = player.position, !pos.isEmpty { PositionBadge(position: pos, compact: true) }
                    Text(player.team?.isEmpty == false ? player.team! : "FA").dsCaption()
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .card(padding: Theme.Spacing.md)
    }
}
