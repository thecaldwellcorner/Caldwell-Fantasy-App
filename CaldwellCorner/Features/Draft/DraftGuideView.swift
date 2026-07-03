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
            DSIconBadge(systemName: icon, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                DSEyebrow(text: article.category, color: Theme.Colors.accent)
                Text(article.title).dsCardTitle().multilineTextAlignment(.leading).lineLimit(2)
                Text("\(article.author) · \(article.readMinutes) min read").dsCaption()
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
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
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                DSEyebrow(text: article.category, color: Theme.Colors.accent)
                Text(article.title).dsScreenTitle().fixedSize(horizontal: false, vertical: true)
                Text("\(article.author) · \(article.readMinutes) min read").dsCaption()
                Divider().overlay(Theme.Colors.strokeSoft).padding(.vertical, Theme.Spacing.sm)
                Text(article.body).dsBody().lineSpacing(5)
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Draft Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}
