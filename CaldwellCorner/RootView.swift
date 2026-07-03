import SwiftUI

enum RootTab: String, CaseIterable, Identifiable {
    case home, coach, matchup, league, rank, reels
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .coach: return "Coach"
        case .matchup: return "Matchup"
        case .league: return "League"
        case .rank: return "Rank"
        case .reels: return "Reels"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .coach: return "sparkles"
        case .matchup: return "scope"
        case .league: return "person.3.fill"
        case .rank: return "chart.bar.fill"
        case .reels: return "play.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: RootTab = .home
    @State private var showPaywall = false

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CaldwellTabBar(selection: $selectedTab)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .home:
            NavigationStack { DashboardView(showPaywall: $showPaywall) }
        case .coach:
            NavigationStack { AIAssistantView(showPaywall: $showPaywall) }
        case .matchup:
            NavigationStack { MatchupView() }
        case .league:
            NavigationStack { LeagueDashboardView() }
        case .rank:
            NavigationStack { RankingsView() }
        case .reels:
            NavigationStack { ReelsView() }
        }
    }
}

// MARK: - Custom bottom navigation (matches the Caldwell IQ design)
struct CaldwellTabBar: View {
    @Binding var selection: RootTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    if selection != tab { withAnimation(Theme.Anim.quick) { selection = tab } }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selection == tab {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Theme.Colors.accent.opacity(0.18))
                                    .frame(width: 46, height: 32)
                            }
                            Image(systemName: tab.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(selection == tab ? Theme.Colors.accent : Theme.Colors.textTertiary)
                        }
                        .frame(height: 32)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(selection == tab ? Theme.Colors.accent : Theme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .background(Theme.Colors.surface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Theme.Colors.stroke, lineWidth: 1))
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, 2)
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(GameCenterStore())
}
