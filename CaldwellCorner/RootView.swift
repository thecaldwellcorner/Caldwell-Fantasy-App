import Combine
import SwiftUI
import UIKit

/// Reports a scroll view's top offset up the view tree so `RootView` can
/// auto-hide the bottom navigation on scroll. Screens opt in with
/// `.tracksBottomNavScroll()`.
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

extension View {
    /// Attach to a `ScrollView`'s content to drive bottom-nav auto-hide.
    func tracksBottomNavScroll(space: String = "bottomNavScroll") -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named(space)).minY)
            }
        )
    }
}

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

    // Bottom-nav auto-hide state.
    @State private var keyboardVisible = false
    @State private var scrollHidden = false
    @State private var lastOffset: CGFloat = 0
    @State private var idleShowTask: Task<Void, Never>?

    private var navHidden: Bool { keyboardVisible || scrollHidden }

    private var keyboardPublisher: AnyPublisher<Bool, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification).map { _ in true },
            NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification).map { _ in false }
        )
        .eraseToAnyPublisher()
    }

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !navHidden {
                    CaldwellTabBar(selection: $selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onPreferenceChange(ScrollOffsetKey.self) { offset in
                handleScroll(offset)
            }
            .onReceive(keyboardPublisher) { visible in
                withAnimation(Theme.Anim.snappy) { keyboardVisible = visible }
            }
            .onChange(of: selectedTab) { _, _ in
                idleShowTask?.cancel()
                lastOffset = 0
                withAnimation(Theme.Anim.snappy) { scrollHidden = false }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }

    /// Hide on downward scroll, show on upward scroll, near the top, or when
    /// scrolling stops.
    private func handleScroll(_ offset: CGFloat) {
        let delta = offset - lastOffset
        lastOffset = offset

        if offset > -24 {
            if scrollHidden { withAnimation(Theme.Anim.snappy) { scrollHidden = false } }
            scheduleIdleShow()
            return
        }
        guard abs(delta) > 6 else { scheduleIdleShow(); return }  // ignore jitter / bounce
        let scrollingDown = delta < 0  // content moves up as the user scrolls down
        if scrollingDown != scrollHidden {
            withAnimation(Theme.Anim.snappy) { scrollHidden = scrollingDown }
        }
        scheduleIdleShow()
    }

    private func scheduleIdleShow() {
        idleShowTask?.cancel()
        idleShowTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 550_000_000)
            if Task.isCancelled { return }
            if scrollHidden { withAnimation(Theme.Anim.snappy) { scrollHidden = false } }
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
