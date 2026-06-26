import SwiftUI

struct LeagueSyncView: View {
    @EnvironmentObject var state: AppState
    @State private var syncing: LeaguePlatform?
    @State private var synced: Set<LeaguePlatform> = [.sleeper, .espn]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Import your leagues to auto-sync rosters, standings, matchups, scoring settings, draft picks and history.")
                    .font(.system(size: 13)).foregroundStyle(Theme.Colors.textSecondary)

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(LeaguePlatform.allCases) { platform in
                        platformRow(platform)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Manual entry fallback", systemImage: "square.and.pencil")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.accent)
                    Text("Platforms without open APIs (ESPN, Yahoo) may require re-auth occasionally. You can always enter a roster manually.")
                        .font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Sync Leagues")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func platformRow(_ platform: LeaguePlatform) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: platform.systemImage)
                .font(.system(size: 20)).foregroundStyle(Theme.Colors.accent)
                .frame(width: 32)
            Text(platform.rawValue)
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if synced.contains(platform) {
                Label("Synced", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.Colors.positive)
            } else if syncing == platform {
                ProgressView().tint(Theme.Colors.accent)
            } else {
                Button {
                    syncing = platform
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        synced.insert(platform); syncing = nil
                    }
                } label: {
                    Text("Connect").font(.system(size: 13, weight: .bold)).foregroundStyle(.black)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Theme.Colors.accent).clipShape(Capsule())
                }
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}
