import SwiftUI

struct NewsCenterView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(state.news) { item in
                    NavigationLink { NewsDetailView(item: item) } label: {
                        NewsRow(item: item)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("News Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NewsDetailView: View {
    let item: NewsItem
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if item.isBreaking { Tag(text: "Breaking", color: Theme.Colors.negative, filled: true) }
                    Text(item.headline).dsScreenTitle().fixedSize(horizontal: false, vertical: true)
                    Text("\(item.source) · \(item.timestamp.relativeShort)").dsCaption()
                }

                if let name = item.playerName, let pos = item.position {
                    HStack {
                        PlayerAvatar(name: name, position: pos.rawValue, size: 40)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name).dsCardTitle()
                            PositionBadge(position: pos.rawValue, compact: true)
                        }
                        Spacer()
                        impactPill
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("AI Fantasy Impact", systemImage: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                    Text(item.aiSummary).dsBody().fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Story")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var impactPill: some View {
        let color: Color = item.fantasyImpact == "Stock Up" ? Theme.Colors.positive : item.fantasyImpact == "Stock Down" ? Theme.Colors.negative : Theme.Colors.textSecondary
        return Tag(text: item.fantasyImpact, color: color, filled: true)
    }
}
