import SwiftUI

struct DraftGuideView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                banner
                ForEach(state.draftGuide) { article in
                    NavigationLink { DraftGuideArticleView(article: article) } label: {
                        DraftGuideRow(article: article)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("2025 Draft Guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { } label: { Image(systemName: "square.and.arrow.down").foregroundStyle(Theme.Colors.accent) }
            }
        }
    }
    private var banner: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("THE CALDWELL CORNER")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.Colors.accentSecondary)
            Text("2025 Draft Guide")
                .font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.Colors.textPrimary)
            Text("Player profiles, sleepers, busts, tiers and auction values — read interactively or download the PDF.")
                .font(.system(size: 13)).foregroundStyle(Theme.Colors.textSecondary)
            HStack {
                Label("Download PDF", systemImage: "arrow.down.doc.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.accent)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Theme.Colors.accent.opacity(0.14)).clipShape(Capsule())
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct DraftGuideRow: View {
    let article: DraftGuideArticle
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Theme.Colors.accentSecondary)
            }.frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(article.category.uppercased())
                    .font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.Colors.accent)
                Text(article.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary).multilineTextAlignment(.leading)
                Text("\(article.author) · \(article.readMinutes) min read")
                    .font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
        }
        .card(padding: Theme.Spacing.md)
    }
    private var icon: String {
        switch article.category {
        case "Sleepers": return "moon.zzz.fill"
        case "Busts": return "exclamationmark.triangle.fill"
        case "Breakouts": return "chart.line.uptrend.xyaxis"
        default: return "list.bullet.rectangle.fill"
        }
    }
}

struct DraftGuideArticleView: View {
    let article: DraftGuideArticle
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(article.category.uppercased())
                    .font(.system(size: 11, weight: .heavy)).foregroundStyle(Theme.Colors.accent)
                Text(article.title)
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.Colors.textPrimary)
                Text("\(article.author) · \(article.readMinutes) min read")
                    .font(.system(size: 12)).foregroundStyle(Theme.Colors.textTertiary)
                Divider().overlay(Theme.Colors.stroke)
                Text(article.body)
                    .font(.system(size: 15)).foregroundStyle(Theme.Colors.textSecondary)
                    .lineSpacing(5)
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Draft Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}
