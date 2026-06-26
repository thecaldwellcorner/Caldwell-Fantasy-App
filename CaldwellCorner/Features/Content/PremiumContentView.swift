import SwiftUI

struct PremiumContentView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(state.premiumContent) { content in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: icon(content.type))
                            .font(.system(size: 22)).foregroundStyle(tint(content.type))
                            .frame(width: 40, height: 40)
                            .background(Theme.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(content.type.uppercased())
                                .font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.Colors.accent)
                            Text(content.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(content.summary)
                                .font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                                .lineLimit(2)
                            Text("\(content.author) · \(content.publishedAt.relativeShort)")
                                .font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
                        }
                        Spacer()
                    }
                    .card(padding: Theme.Spacing.md)
                }
                Label("Join the Premium Discord for live chat and exclusive drops.", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.info)
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
    private func tint(_ type: String) -> Color {
        switch type {
        case "Livestream": return Theme.Colors.negative
        case "Film": return Theme.Colors.info
        default: return Theme.Colors.accentSecondary
        }
    }
}

struct NotificationsView: View {
    private let items: [(String, String, String, Color)] = [
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
                        Image(systemName: item.0).font(.system(size: 18)).foregroundStyle(item.3).frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.1).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
                            Text(item.2).font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                        }
                        Spacer()
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
