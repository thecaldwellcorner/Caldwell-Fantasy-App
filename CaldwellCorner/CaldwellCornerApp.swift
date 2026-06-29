import SwiftUI

@main
struct CaldwellCornerApp: App {
    @StateObject private var state = AppState()
    @StateObject private var gameCenter = GameCenterStore()

    init() {
        Self.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(gameCenter)
                .preferredColorScheme(.dark)
                .tint(Theme.Colors.accent)
        }
    }

    /// Clean, native dark chrome: system blurred bars with themed item colors.
    private static func configureAppearance() {
        let unselected = UIColor(Theme.Colors.textTertiary)
        let selected = UIColor(Theme.Colors.accent)
        let title = UIColor(Theme.Colors.textPrimary)

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()   // native system material
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = unselected
            item.normal.titleTextAttributes = [.foregroundColor: unselected,
                                               .font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected,
                                                 .font: UIFont.systemFont(ofSize: 10, weight: .semibold)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.titleTextAttributes = [.foregroundColor: title]
        nav.largeTitleTextAttributes = [.foregroundColor: title]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}
