import SwiftUI

struct LeagueSyncView: View {
    @EnvironmentObject var state: AppState
    @State private var syncing: LeaguePlatform?
    @State private var synced: Set<LeaguePlatform> = [.sleeper, .espn]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Import a league to auto-sync rosters, standings, matchups, scoring, draft picks and history.")
                    .dsCallout()

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(LeaguePlatform.allCases) { platform in platformRow(platform) }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Manual entry fallback", systemImage: "square.and.pencil")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.accent)
                    Text("Platforms without open APIs (ESPN, Yahoo) may require occasional re-auth. You can always enter a roster manually.")
                        .dsCaption()
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
            DSIconBadge(systemName: platform.systemImage, size: 36)
            Text(platform.rawValue).dsCardTitle()
            Spacer()
            if synced.contains(platform) {
                Label("Synced", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.positive)
            } else if syncing == platform {
                ProgressView().tint(Theme.Colors.accent)
            } else {
                Button {
                    syncing = platform
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        synced.insert(platform); syncing = nil
                    }
                } label: {
                    Text("Connect").font(.system(size: 13, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Theme.Colors.accent).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}
