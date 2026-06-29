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

// MARK: - In-app vertical feed
struct ReelsView: View {
    @EnvironmentObject var state: AppState
    @State private var currentID: UUID?
    @State private var muted = true
    @State private var showSaved = false

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
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) { header }
        .onAppear { if currentID == nil { currentID = state.reels.first?.id } }
        .sheet(isPresented: $showSaved) {
            NavigationStack { SavedReelsView() }
                .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        HStack {
            Text("Reels")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 4)
            Spacer()
            Button { showSaved = true } label: {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(9)
                    .background(.black.opacity(0.35), in: Circle())
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, 54)
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
            .padding(.bottom, Theme.Spacing.lg)
        }
        .clipped()
    }

    // Bottom-left info
    private var info: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 8) {
                CreatorAvatar(creator: creator, size: 34)
                HStack(spacing: 4) {
                    Text(creator?.name ?? "Caldwell Corner")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                    if creator?.verified == true {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(Theme.Colors.info)
                    }
                }
                Text(creator?.platform.rawValue ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(reel.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(3)
            HStack(spacing: 8) {
                Tag(text: reel.topic.rawValue, color: ReelStyle.color(reel.topic), filled: true)
                Text("\(reel.views) views").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            }
            if let url = reel.url {
                Button { openURL(url) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.square")
                        Text("View original")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Right action rail
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
                       label: muted ? "Muted" : "Sound", tint: .white) {
                muted.toggle()
            }
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
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 46, height: 46)
            .background(.black.opacity(0.3), in: Circle())
    }
}

// MARK: - Simulated in-app player (thumbnail + playback UI)
// Plays inside the app. Drop an AVPlayer here when a direct video URL exists;
// the thumbnail doubles as the loading state and the failure fallback.
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
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(22)
                    .background(.black.opacity(0.35), in: Circle())
                    .transition(.opacity)
            }
            VStack {
                ProgressView(value: min(1, progress))
                    .tint(.white)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, 88)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.Anim.quick) { isPlaying.toggle() } }
        .onReceive(ticker) { _ in advance() }
        .onChange(of: isActive) { _, active in
            if active { progress = 0; isPlaying = true }
        }
    }

    private func advance() {
        guard playing else { return }
        let duration = max(8, Double(reel.durationSeconds))
        progress += 0.1 / duration
        if progress >= 1 { progress = 0 }     // loop
    }

    @ViewBuilder private var thumbnail: some View {
        AsyncImage(url: URL(string: reel.thumbnailURL)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty:
                ZStack { fallback; ProgressView().tint(.white) }
            case .failure:
                fallback
            @unknown default:
                fallback
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(colors: [ReelStyle.color(reel.topic).opacity(0.35), .black],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 8) {
                Image(systemName: reel.topic.systemImage)
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.5))
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
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.opacity(0.8))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Saved reels (library)
struct SavedReelsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            if state.savedReelPosts.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "bookmark").font(.system(size: 36)).foregroundStyle(Theme.Colors.textTertiary)
                    Text("No saved reels yet").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
                    Text("Tap the bookmark on any reel to save it.").font(.system(size: 13)).foregroundStyle(Theme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity).padding(.top, 80).padding(.horizontal, Theme.Spacing.xl)
            } else {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(state.savedReelPosts) { reel in
                        SavedReelRow(reel: reel)
                    }
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
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(ReelStyle.color(reel.topic).opacity(0.18))
                Image(systemName: reel.topic.systemImage).foregroundStyle(ReelStyle.color(reel.topic))
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(reel.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary).lineLimit(2)
                Text("\(creator?.name ?? "") · \(reel.views) views").font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            Button { state.toggleSavedReel(reel.id) } label: {
                Image(systemName: "bookmark.fill").foregroundStyle(Theme.Colors.accentSecondary)
            }
            .buttonStyle(.plain)
        }
        .card(padding: Theme.Spacing.md)
    }
}
