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

/// Standard native bottom tab bar. SwiftUI reserves the correct layout space, so
/// content (lists, cards, the Coach composer) always sits above it — no floating
/// overlay, no auto-hide, no manual bottom offsets. The Caldwell IQ dark/purple
/// look comes from the `UITabBarAppearance` configured in `CaldwellCornerApp`.
struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: RootTab = .home
    @State private var showPaywall = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView(showPaywall: $showPaywall) }
                .tabItem { Label(RootTab.home.title, systemImage: RootTab.home.icon) }
                .tag(RootTab.home)

            NavigationStack { AIAssistantView(showPaywall: $showPaywall) }
                .tabItem { Label(RootTab.coach.title, systemImage: RootTab.coach.icon) }
                .tag(RootTab.coach)

            NavigationStack { MatchupView() }
                .tabItem { Label(RootTab.matchup.title, systemImage: RootTab.matchup.icon) }
                .tag(RootTab.matchup)

            NavigationStack { LeagueDashboardView() }
                .tabItem { Label(RootTab.league.title, systemImage: RootTab.league.icon) }
                .tag(RootTab.league)

            NavigationStack { RankingsView() }
                .tabItem { Label(RootTab.rank.title, systemImage: RootTab.rank.icon) }
                .tag(RootTab.rank)

            NavigationStack { ReelsView() }
                .tabItem { Label(RootTab.reels.title, systemImage: RootTab.reels.icon) }
                .tag(RootTab.reels)
        }
        .tint(Theme.Colors.accent)
        .task {
            // Ensure a Supabase session exists on launch (anonymous if needed),
            // reusing the persisted session on future launches.
            do {
                let session = try await SupabaseAuth.shared.ensureSession()
                #if DEBUG
                print("🔐 Supabase session ready on launch — user id \(session.userId)")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Supabase auth on launch failed: \(error.localizedDescription)")
                #endif
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .environmentObject(GameCenterStore())
}
