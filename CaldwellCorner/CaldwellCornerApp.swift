import SwiftUI

@main
struct CaldwellCornerApp: App {
    @StateObject private var state = AppState()

    init() {
        Self.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
                .tint(Theme.Colors.accent)
        }
    }

    /// Premium dark chrome: translucent blurred tab bar + clean nav bar.
    private static func configureAppearance() {
        let surface = UIColor(Theme.Colors.surface)
        let bg = UIColor(Theme.Colors.background)

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        tab.backgroundColor = surface.withAlphaComponent(0.7)
        tab.shadowColor = UIColor(Theme.Colors.stroke).withAlphaComponent(0.6)
        let unselected = UIColor(Theme.Colors.textTertiary)
        let selected = UIColor(Theme.Colors.accent)
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = unselected
            item.normal.titleTextAttributes = [.foregroundColor: unselected]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [.foregroundColor: selected]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        nav.backgroundColor = bg.withAlphaComponent(0.5)
        nav.shadowColor = .clear
        let title = UIColor(Theme.Colors.textPrimary)
        nav.titleTextAttributes = [.foregroundColor: title]
        nav.largeTitleTextAttributes = [.foregroundColor: title]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}
