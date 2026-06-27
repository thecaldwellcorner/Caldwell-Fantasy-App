import SwiftUI

@main
struct CaldwellCornerApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
                .tint(Theme.Colors.accent)
        }
    }
}
