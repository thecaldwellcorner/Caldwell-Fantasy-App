import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                group("Account") {
                    DSNavRow(icon: "person.crop.circle", title: "Edit Profile")
                    separator
                    DSNavRow(icon: "creditcard", title: "Manage Subscription",
                             detail: state.isPremium ? "Premium" : "Free")
                    separator
                    DSNavRow(icon: "star", title: "Favorite Teams")
                }

                group("Preferences") {
                    DSNavRow(icon: "bell", title: "Notifications")
                    separator
                    DSNavRow(icon: "sportscourt", title: "Scoring & Leagues")
                    separator
                    DSNavRow(icon: "moon", title: "Appearance", detail: "Dark")
                }

                group("Support") {
                    DSNavRow(icon: "questionmark.circle", title: "Help & Support")
                    separator
                    DSNavRow(icon: "doc.text", title: "Terms & Privacy")
                    separator
                    DSNavRow(icon: "info.circle", title: "About", detail: "v1.0")
                }

                if state.isPremium {
                    Button { state.profile.tier = .free } label: {
                        Text("Switch to Free (demo)").dsCaption()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var separator: some View {
        Divider().overlay(Theme.Colors.strokeSoft).padding(.leading, 52)
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            DSEyebrow(text: title)
            VStack(spacing: 0) { content() }
                .card(padding: 0)
        }
    }
}
