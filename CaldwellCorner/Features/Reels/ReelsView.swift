import SwiftUI
import Combine

// MARK: - Topic styling
enum ReelStyle {
    static func color(_ topic: ReelTopic) -> Color {
        switch topic {
        case .sleepers: return Theme.Colors.info
        case .tradeTargets: return Theme.Colors.accentSecondary
        case .waiverPickups: return Theme.Colors.positive
        case .dynastyBuys: return Theme.Colors.violet
        case .injuryNews: return Theme.Colors.negative
        case .draftStrategy: return Theme.Colors.accent
        }
    }
}

func formatCount(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
    return "\(n)"
}

// MARK: - Reels discovery feed (matches Figma)
struct ReelsView: View {
    @EnvironmentObject var state: AppState
    @State private var filter: Filter = .forYou
    @State private var playing: ReelPost?

    enum Filter: String, CaseIterable, Identifiable { case trending = "Trending", following = "Following", forYou = "For You"; var id: String { rawValue } }

    private var feed: [ReelPost] {
        switch filter {
        case .forYou: return state.reels
        case .trending: return state.reels.sorted { viewsValue($0.views) > viewsValue($1.views) }
        case .following: return state.reels.filter { state.creator($0.creatorID)?.isCaldwell == true }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.lg) {
                header
                ForEach(feed) { reel in
                    ReelFeedCard(reel: reel) { playing = reel }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $playing) { reel in
            ReelPlayerScreen(startID: reel.id)
        }
    }

    private var header: some View {
        HStack {
            Text("Reels").dsScreenTitle()
            Spacer()
            HStack(spacing: 6) {
                ForEach(Filter.allCases) { f in
                    Button { withAnimation(Theme.Anim.quick) { filter = f } } label: {
                        Text(f.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(filter == f ? .white : Theme.Colors.textSecondary)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(filter == f ? Theme.Colors.accent : Theme.Colors.surfaceElevated, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func viewsValue(_ s: String) -> Double {
        let lower = s.lowercased()
        let num = Double(lower.filter { $0.isNumber || $0 == "." }) ?? 0
        if lower.contains("m") { return num * 1_000_000 }
        if lower.contains("k") { return num * 1_000 }
        return num
    }
}

// MARK: - Feed card
struct ReelFeedCard: View {
    @EnvironmentObject var state: AppState
    let reel: ReelPost
    let onOpen: () -> Void

    private var creator: ContentCreator? { state.creator(reel.creatorID) }
    private var liked: Bool { state.likedReels.contains(reel.id) }
    private var saved: Bool { state.savedReels.contains(reel.id) }
    private var likeCount: Int { abs(reel.id.uuidString.hashValue) % 9000 + 1200 + (liked ? 1 : 0) }
    private var commentCount: Int { likeCount / 8 }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onOpen) { thumbnail }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(reel.title).dsCardTitle().lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    CreatorAvatar(creator: creator, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(creator?.name ?? "Caldwell Corner").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
                            if creator?.verified == true {
                                Image(systemName: "checkmark.seal.fill").font(.system(size: 10)).foregroundStyle(Theme.Colors.info)
                            }
                        }
                        Text(creator?.handle ?? "").dsCaption()
                    }
                    Spacer()
                    engagement
                }
            }
            .padding(Theme.Spacing.md)
        }
        .glassCard(padding: 0, radius: 18)
    }

    private var thumbnail: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: URL(string: reel.thumbnailURL)) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: fallback
                }
            }
            .frame(height: 152)
            .frame(maxWidth: .infinity)
            .clipped()
            Tag(text: reel.topic.rawValue, color: ReelStyle.color(reel.topic), filled: true)
                .padding(Theme.Spacing.md)
        }
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(colors: [ReelStyle.color(reel.topic).opacity(0.4), Theme.Colors.surfaceElevated],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: reel.topic.systemImage).font(.system(size: 34)).foregroundStyle(.white.opacity(0.35))
        }
        .frame(height: 152).frame(maxWidth: .infinity)
    }

    private var engagement: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button { withAnimation(Theme.Anim.snappy) { state.toggleLikedReel(reel.id) } } label: {
                countLabel(liked ? "heart.fill" : "heart", formatCount(likeCount), liked ? Theme.Colors.negative : Theme.Colors.textSecondary)
            }.buttonStyle(.plain)
            countLabel("bubble.right", formatCount(commentCount), Theme.Colors.textSecondary)
            Button { state.toggleSavedReel(reel.id) } label: {
                Image(systemName: saved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(saved ? Theme.Colors.accentSecondary : Theme.Colors.textSecondary)
            }.buttonStyle(.plain)
        }
    }

    private func countLabel(_ icon: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
            Text(value).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(color)
    }
}

// MARK: - Immersive in-app player (tap-through from the feed)
struct ReelPlayerScreen: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let startID: UUID
    @State private var currentID: UUID?
    @State private var muted = true

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(state.reels) { reel in
                    ReelCell(reel: reel, muted: $muted, isCurrent: currentID == reel.id)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(reel.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .padding(10).background(.black.opacity(0.4), in: Circle())
            }
            .padding(.horizontal, Theme.Spacing.lg).padding(.top, 54)
        }
        .onAppear { currentID = startID }
    }
}

// MARK: - One full-screen reel
struct ReelCell: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openURL) private var openURL
    let reel: ReelPost
    @Binding var muted: Bool
    let isCurrent: Bool

    private var creator: ContentCreator? { state.creator(reel.creatorID) }
    private var liked: Bool { state.likedReels.contains(reel.id) }
    private var saved: Bool { state.savedReels.contains(reel.id) }
    private var likeCount: Int { abs(reel.id.uuidString.hashValue) % 9000 + 1200 + (liked ? 1 : 0) }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            ReelPlayerView(reel: reel, isActive: isCurrent, muted: muted)
            Theme.Gradient.bottomScrim.allowsHitTesting(false)
            HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
                info
                Spacer(minLength: 0)
                rightRail
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .clipped()
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                CreatorAvatar(creator: creator, size: 34)
                HStack(spacing: 4) {
                    Text(creator?.name ?? "Caldwell Corner").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    if creator?.verified == true {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(Theme.Colors.info)
                    }
                }
                Text(creator?.platform.rawValue ?? "").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            }
            Text(reel.title).font(.system(size: 15, weight: .medium)).foregroundStyle(.white).lineLimit(3)
            HStack(spacing: 8) {
                Tag(text: reel.topic.rawValue, color: ReelStyle.color(reel.topic), filled: true)
                Text("\(reel.views) views").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            }
            if let url = reel.url {
                Button { openURL(url) } label: {
                    HStack(spacing: 4) { Image(systemName: "arrow.up.right.square"); Text("View original") }
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rightRail: some View {
        VStack(spacing: Theme.Spacing.lg) {
            railButton(liked ? "heart.fill" : "heart", label: formatCount(likeCount),
                       tint: liked ? Theme.Colors.negative : .white) {
                withAnimation(Theme.Anim.snappy) { state.toggleLikedReel(reel.id) }
            }
            railButton(saved ? "bookmark.fill" : "bookmark", label: "Save",
                       tint: saved ? Theme.Colors.accentSecondary : .white) {
                withAnimation(Theme.Anim.snappy) { state.toggleSavedReel(reel.id) }
            }
            if let url = reel.url {
                ShareLink(item: url) {
                    VStack(spacing: 4) {
                        railIcon("square.and.arrow.up", tint: .white)
                        Text("Share").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            railButton(muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                       label: muted ? "Muted" : "Sound", tint: .white) { muted.toggle() }
        }
    }

    private func railButton(_ icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                railIcon(icon, tint: tint)
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private func railIcon(_ icon: String, tint: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .semibold)).foregroundStyle(tint)
            .frame(width: 46, height: 46).background(.black.opacity(0.3), in: Circle())
    }
}

// MARK: - Simulated in-app player
struct ReelPlayerView: View {
    let reel: ReelPost
    let isActive: Bool
    let muted: Bool
    @State private var isPlaying = true
    @State private var progress: Double = 0
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private var playing: Bool { isActive && isPlaying }

    var body: some View {
        ZStack {
            thumbnail
            if !playing {
                Image(systemName: "play.fill")
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                    .padding(22).background(.black.opacity(0.35), in: Circle())
                    .transition(.opacity)
            }
            VStack {
                ProgressView(value: min(1, progress)).tint(.white)
                    .padding(.horizontal, Theme.Spacing.lg).padding(.top, 88)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.Anim.quick) { isPlaying.toggle() } }
        .onReceive(ticker) { _ in advance() }
        .onChange(of: isActive) { _, active in if active { progress = 0; isPlaying = true } }
    }

    private func advance() {
        guard playing else { return }
        progress += 0.1 / max(8, Double(reel.durationSeconds))
        if progress >= 1 { progress = 0 }
    }

    @ViewBuilder private var thumbnail: some View {
        AsyncImage(url: URL(string: reel.thumbnailURL)) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .empty: ZStack { fallback; ProgressView().tint(.white) }
            case .failure: fallback
            @unknown default: fallback
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(colors: [ReelStyle.color(reel.topic).opacity(0.35), .black], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 8) {
                Image(systemName: reel.topic.systemImage).font(.system(size: 40)).foregroundStyle(.white.opacity(0.5))
                Text("Preview").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Creator avatar
struct CreatorAvatar: View {
    let creator: ContentCreator?
    var size: CGFloat = 28
    private var tint: Color { creator?.isCaldwell == true ? Theme.Colors.accent : Theme.Colors.info }
    var body: some View {
        Text((creator?.name ?? "?").initials)
            .font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(.white)
            .frame(width: size, height: size).background(tint.opacity(0.85)).clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Saved reels library
struct SavedReelsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            if state.savedReelPosts.isEmpty {
                DSEmptyState(icon: "bookmark", title: "No saved reels yet", message: "Tap the bookmark on any reel to save it.")
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(state.savedReelPosts) { reel in SavedReelRow(reel: reel) }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .screenBackground()
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(Theme.Colors.accent) } }
    }
}

struct SavedReelRow: View {
    @EnvironmentObject var state: AppState
    let reel: ReelPost
    private var creator: ContentCreator? { state.creator(reel.creatorID) }
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(ReelStyle.color(reel.topic).opacity(0.18))
                Image(systemName: reel.topic.systemImage).foregroundStyle(ReelStyle.color(reel.topic))
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(reel.title).dsCardTitle().lineLimit(2)
                Text("\(creator?.name ?? "") · \(reel.views) views").dsCaption()
            }
            Spacer()
            Button { state.toggleSavedReel(reel.id) } label: {
                Image(systemName: "bookmark.fill").foregroundStyle(Theme.Colors.accentSecondary)
            }.buttonStyle(.plain)
        }
        .card(padding: Theme.Spacing.md)
    }
}
