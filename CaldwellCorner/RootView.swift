import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab: Tab = .home
    @State private var showPaywall = false

    enum Tab: Hashable { case home, players, assistant, tools, profile }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { DashboardView(showPaywall: $showPaywall) }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            NavigationStack { PlayersView() }
                .tabItem { Label("Players", systemImage: "person.2.fill") }
                .tag(Tab.players)

            NavigationStack { AIAssistantView(showPaywall: $showPaywall) }
                .tabItem { Label("Assistant", systemImage: "sparkles") }
                .tag(Tab.assistant)

            NavigationStack { ToolsView(showPaywall: $showPaywall) }
                .tabItem { Label("Tools", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.tools)

            NavigationStack { ProfileView(showPaywall: $showPaywall) }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

#Preview {
    RootView().environmentObject(AppState())
}
