import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: Tab = .home
    @State private var showPaywall = false

    enum Tab: Hashable { case home, reels, players, assistant, tools }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView(showPaywall: $showPaywall) }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            NavigationStack { ReelsView() }
                .tabItem { Label("Reels", systemImage: "play.square.stack.fill") }
                .tag(Tab.reels)

            NavigationStack { PlayersView() }
                .tabItem { Label("Players", systemImage: "person.2.fill") }
                .tag(Tab.players)

            NavigationStack { AIAssistantView(showPaywall: $showPaywall) }
                .tabItem { Label("Assistant", systemImage: "sparkles") }
                .tag(Tab.assistant)

            NavigationStack { ToolsView(showPaywall: $showPaywall) }
                .tabItem { Label("Tools", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.tools)
        }
        .buttonStyle(PressableButtonStyle())
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
