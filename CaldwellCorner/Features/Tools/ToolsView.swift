import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var state: AppState
    @Binding var showPaywall: Bool

    struct ToolItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let premium: Bool
        let destination: AnyView
    }

    private var sections: [(String, [ToolItem])] {
        [
            ("Analyze", [
                ToolItem(title: "Trade Analyzer", subtitle: "Grade any deal", icon: "arrow.left.arrow.right", tint: Theme.Colors.info, premium: false, destination: AnyView(TradeAnalyzerView())),
                ToolItem(title: "Start / Sit", subtitle: "Weekly lineup calls", icon: "checklist", tint: Theme.Colors.accentSecondary, premium: false, destination: AnyView(StartSitView())),
                ToolItem(title: "Waiver Assistant", subtitle: "FAAB & priority", icon: "hand.raised.fill", tint: Theme.Colors.positive, premium: false, destination: AnyView(WaiverView())),
            ]),
            ("Draft", [
                ToolItem(title: "Draft Center", subtitle: "Mock & live assistant", icon: "person.3.sequence.fill", tint: Theme.Colors.accent, premium: false, destination: AnyView(DraftCenterView())),
                ToolItem(title: "Draft Guide", subtitle: "Annual premium guide", icon: "book.fill", tint: Theme.Colors.accentSecondary, premium: true, destination: AnyView(DraftGuideView())),
            ]),
            ("Dynasty", [
                ToolItem(title: "Dynasty Hub", subtitle: "Picks, rookies, age curves", icon: "building.columns.fill", tint: Theme.Colors.info, premium: true, destination: AnyView(DynastyHubView())),
            ]),
            ("Stay Informed", [
                ToolItem(title: "News Center", subtitle: "AI impact summaries", icon: "newspaper.fill", tint: Theme.Colors.textPrimary, premium: false, destination: AnyView(NewsCenterView())),
                ToolItem(title: "Injury Center", subtitle: "Status & replacements", icon: "cross.case.fill", tint: Theme.Colors.warning, premium: false, destination: AnyView(InjuryCenterView())),
                ToolItem(title: "Betting Center", subtitle: "Props, EV & edges", icon: "dollarsign.circle.fill", tint: Theme.Colors.positive, premium: true, destination: AnyView(BettingCenterView())),
            ]),
            ("My Leagues", [
                ToolItem(title: "League Dashboard", subtitle: "Standings & odds", icon: "trophy.fill", tint: Theme.Colors.accentSecondary, premium: false, destination: AnyView(LeagueDashboardView())),
                ToolItem(title: "Sync a League", subtitle: "Sleeper, ESPN, Yahoo…", icon: "arrow.triangle.2.circlepath", tint: Theme.Colors.accent, premium: false, destination: AnyView(LeagueSyncView())),
                ToolItem(title: "Premium Content", subtitle: "Film, video, livestreams", icon: "play.rectangle.fill", tint: Theme.Colors.negative, premium: true, destination: AnyView(PremiumContentView())),
            ]),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                ForEach(sections, id: \.0) { section in
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        SectionHeader(title: section.0)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                            ForEach(section.1) { item in
                                toolCard(item)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Tools")
    }

    private func toolCard(_ item: ToolItem) -> some View {
        Group {
            if item.premium && !state.isPremium {
                Button { showPaywall = true } label: { toolCardContent(item, locked: true) }
            } else {
                NavigationLink { item.destination } label: { toolCardContent(item, locked: false) }
            }
        }
    }

    private func toolCardContent(_ item: ToolItem, locked: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: item.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(item.tint)
                Spacer()
                if locked { PremiumBadge() }
            }
            Text(item.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(item.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .card(padding: Theme.Spacing.md)
    }
}
