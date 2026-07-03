import SwiftUI

struct PremiumContentView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(state.premiumContent) { content in
                    HStack(spacing: Theme.Spacing.md) {
                        DSIconBadge(systemName: icon(content.type), size: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            DSEyebrow(text: content.type, color: Theme.Colors.accent)
                            Text(content.title).dsCardTitle().lineLimit(1)
                            Text(content.summary).dsCaption().lineLimit(2)
                            Text("\(content.author) · \(content.publishedAt.relativeShort)")
                                .font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .card(padding: Theme.Spacing.md)
                }
                Label("Join the Premium Discord for live chat and exclusive drops.", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Premium Content")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func icon(_ type: String) -> String {
        switch type {
        case "Film": return "film.fill"
        case "Video": return "play.rectangle.fill"
        case "Livestream": return "dot.radiowaves.left.and.right"
        default: return "doc.text.fill"
        }
    }
}

struct NotificationsView: View {
    private let items: [(icon: String, title: String, body: String, tint: Color)] = [
        ("cross.case.fill", "Injury Alert", "Cooper Kupp placed on IR — Puka Nacua sees elite volume.", Theme.Colors.negative),
        ("arrow.left.arrow.right", "Trade Offer", "Marcus offered you Saquon Barkley for Jahmyr Gibbs.", Theme.Colors.info),
        ("hand.raised.fill", "Waiver Reminder", "Waivers process tonight at 3 AM. You have 3 claims queued.", Theme.Colors.accentSecondary),
        ("checklist", "Start/Sit Reminder", "Lock your Week 7 lineup — 2 questionable players to review.", Theme.Colors.accent),
        ("newspaper.fill", "Breaking", "Jayden Daniels posts third straight 25+ point game.", Theme.Colors.positive),
    ]
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    HStack(spacing: Theme.Spacing.md) {
                        DSIconBadge(systemName: item.icon, tint: item.tint, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).dsCardTitle()
                            Text(item.body).dsCaption()
                        }
                        Spacer(minLength: 0)
                    }
                    .card(padding: Theme.Spacing.md)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}
