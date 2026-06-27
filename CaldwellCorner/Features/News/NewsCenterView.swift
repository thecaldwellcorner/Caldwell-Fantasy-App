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
                if item.isBreaking {
                    Text("BREAKING NEWS")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Theme.Colors.negative)
                        .clipShape(Capsule())
                }
                Text(item.headline)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("\(item.source) · \(item.timestamp.relativeShort)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textTertiary)

                if let name = item.playerName, let pos = item.position {
                    HStack {
                        PlayerAvatar(name: name, position: pos.rawValue, size: 40)
                        VStack(alignment: .leading) {
                            Text(name).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.Colors.textPrimary)
                            PositionBadge(position: pos.rawValue, compact: true)
                        }
                        Spacer()
                        impactPill
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Label("AI Fantasy Impact", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Colors.accent)
                    Text(item.aiSummary)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Colors.textSecondary)
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
        return Text(item.fantasyImpact)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.black)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
}
