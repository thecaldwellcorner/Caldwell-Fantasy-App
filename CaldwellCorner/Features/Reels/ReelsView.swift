import SwiftUI

struct ReelsView: View {
    @EnvironmentObject var state: AppState
    @State private var topicFilter: ReelTopic?

    private func reels(_ section: ReelSection) -> [ReelPost] {
        let base = state.reels(in: section)
        guard let topicFilter else { return base }
        return base.filter { $0.topic == topicFilter }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                intro
                topicFilters

                ForEach(ReelSection.allCases) { section in
                    let items = reels(section)
                    if !items.isEmpty {
                        if section == .trendingClips {
                            trendingGrid(section: section, items: items)
                        } else {
                            shelf(section: section, items: items)
                        }
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Reels")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SavedReelsView() } label: {
                    Image(systemName: "bookmark.fill").foregroundStyle(Theme.Colors.accent)
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fantasy Reels")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Short-form fantasy football from The Caldwell Corner and trusted creators")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var topicFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "ALL", selected: topicFilter == nil) { topicFilter = nil }
                ForEach(ReelTopic.allCases) { topic in
                    FilterChip(title: topic.rawValue, selected: topicFilter == topic,
                               color: ReelStyle.color(topic)) {
                        topicFilter = topicFilter == topic ? nil : topic
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }

    private func shelf(section: ReelSection, items: [ReelPost]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: section.rawValue, subtitle: section.subtitle)
                .padding(.horizontal, Theme.Spacing.lg)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ForEach(items) { reel in
                        ReelCard(reel: reel, thumbHeight: 280)
                            .frame(width: 230)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
        }
    }

    private func trendingGrid(section: ReelSection, items: [ReelPost]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: section.rawValue, subtitle: section.subtitle)
                .padding(.horizontal, Theme.Spacing.lg)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md),
                                GridItem(.flexible(), spacing: Theme.Spacing.md)],
                      spacing: Theme.Spacing.md) {
                ForEach(items) { reel in
                    ReelCard(reel: reel, thumbHeight: 210)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
    }
}

// MARK: - Styling helpers
enum ReelStyle {
    static func color(_ topic: ReelTopic) -> Color {
        switch topic {
        case .sleepers: return Theme.Colors.info
        case .tradeTargets: return Theme.Colors.accentSecondary
        case .waiverPickups: return Theme.Colors.positive
        case .dynastyBuys: return Color(hex: 0xB084FF)
        case .injuryNews: return Theme.Colors.negative
        case .draftStrategy: return Theme.Colors.accent
        }
    }
}

// MARK: - Reel card
struct ReelCard: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openURL) private var openURL
    let reel: ReelPost
    var thumbHeight: CGFloat

    private var creator: ContentCreator? { state.creator(reel.creatorID) }
    private var isSaved: Bool { state.savedReels.contains(reel.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            thumbnail
            creatorRow
            Text(reel.title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            tagRow
            HStack(spacing: 4) {
                Image(systemName: "eye.fill").font(.system(size: 9))
                Text(reel.views)
                Text("·")
                Text(reel.datePosted.relativeShort)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.Colors.textTertiary)
            actionBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .stroke(Theme.Colors.stroke, lineWidth: 1))
    }

    private var thumbnail: some View {
        Button { watch() } label: {
            ZStack {
                AsyncImage(url: URL(string: reel.thumbnailURL)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: thumbHeight)
                .clipped()

                // Gradient scrim for legibility
                LinearGradient(colors: [.clear, .black.opacity(0.55)],
                               startPoint: .center, endPoint: .bottom)

                // Play button
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.92))
                    .clipShape(Circle())

                VStack {
                    HStack {
                        topicTag
                        Spacer()
                        platformTag
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text(reel.durationLabel)
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(.black.opacity(0.65))
                            .clipShape(Capsule())
                    }
                }
                .padding(Theme.Spacing.sm)
            }
            .frame(height: thumbHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(colors: [ReelStyle.color(reel.topic).opacity(0.55),
                                    Theme.Colors.surfaceElevated],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: reel.topic.systemImage)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .frame(height: thumbHeight)
    }

    private var topicTag: some View {
        HStack(spacing: 3) {
            Image(systemName: reel.topic.systemImage)
            Text(reel.topic.rawValue)
        }
        .font(.system(size: 9, weight: .heavy))
        .foregroundStyle(.black)
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(ReelStyle.color(reel.topic))
        .clipShape(Capsule())
    }

    private var platformTag: some View {
        Image(systemName: creator?.platform.systemImage ?? "play.rectangle.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(.black.opacity(0.55))
            .clipShape(Circle())
    }

    private var creatorRow: some View {
        HStack(spacing: 6) {
            CreatorAvatar(creator: creator, size: 24)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3) {
                    Text(creator?.name ?? "Unknown")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if creator?.verified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.Colors.info)
                    }
                }
                Text(creator?.platform.rawValue ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var tagRow: some View {
        HStack(spacing: 4) {
            ForEach(reel.tags.prefix(3), id: \.self) { tag in
                Text("#\(tag.replacingOccurrences(of: " ", with: ""))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                    .lineLimit(1)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button { watch() } label: {
                Label("Watch", systemImage: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { state.toggleSavedReel(reel.id) } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSaved ? Theme.Colors.accentSecondary : Theme.Colors.textSecondary)
                    .frame(width: 34, height: 30)
                    .background(Theme.Colors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)

            if let url = reel.url {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 34, height: 30)
                        .background(Theme.Colors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func watch() {
        if let url = reel.url { openURL(url) }
    }
}

// MARK: - Creator avatar
struct CreatorAvatar: View {
    let creator: ContentCreator?
    var size: CGFloat = 28

    private var initials: String {
        (creator?.name ?? "?").split(separator: " ").compactMap { $0.first }
            .map(String.init).prefix(2).joined().uppercased()
    }
    private var tint: Color {
        creator?.isCaldwell == true ? Theme.Colors.accent : Theme.Colors.info
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.6)],
                               startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
    }
}

// MARK: - Saved reels
struct SavedReelsView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            if state.savedReelPosts.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40)).foregroundStyle(Theme.Colors.textTertiary)
                    Text("No saved reels yet")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Tap the bookmark on any reel to save it for later.")
                        .font(.system(size: 13)).foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
                .padding(.horizontal, Theme.Spacing.xl)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Spacing.md),
                                    GridItem(.flexible(), spacing: Theme.Spacing.md)],
                          spacing: Theme.Spacing.md) {
                    ForEach(state.savedReelPosts) { reel in
                        ReelCard(reel: reel, thumbHeight: 210)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .screenBackground()
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
    }
}
