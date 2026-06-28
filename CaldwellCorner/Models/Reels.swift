import Foundation

/// Platform a creator publishes short-form content on.
enum CreatorPlatform: String, Codable, CaseIterable, Identifiable {
    case youtube = "YouTube"
    case tiktok = "TikTok"
    case instagram = "Instagram"
    case x = "X"
    case podcast = "Podcast"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .x: return "bubble.left.fill"
        case .podcast: return "mic.fill"
        }
    }
}

/// Fantasy topic a reel covers. Drives the accent color + icon in the UI.
enum ReelTopic: String, Codable, CaseIterable, Identifiable {
    case sleepers = "Sleepers"
    case tradeTargets = "Trade Targets"
    case waiverPickups = "Waiver Pickups"
    case dynastyBuys = "Dynasty Buys"
    case injuryNews = "Injury News"
    case draftStrategy = "Draft Strategy"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .sleepers: return "moon.zzz.fill"
        case .tradeTargets: return "arrow.left.arrow.right"
        case .waiverPickups: return "hand.raised.fill"
        case .dynastyBuys: return "building.columns.fill"
        case .injuryNews: return "cross.case.fill"
        case .draftStrategy: return "list.bullet.clipboard.fill"
        }
    }
}

/// Curated shelf a reel belongs to.
enum ReelSection: String, Codable, CaseIterable, Identifiable {
    case caldwellCorner = "Caldwell Corner"
    case caldwellCoverage = "Caldwell Coverage"
    case recommendedCreators = "Recommended Creators"
    case trendingClips = "Trending Fantasy Clips"
    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .caldwellCorner: return "Originals from The Caldwell Corner"
        case .caldwellCoverage: return "Our take on the latest fantasy news"
        case .recommendedCreators: return "Trusted voices we follow"
        case .trendingClips: return "What the community is watching now"
        }
    }
}

/// A short-form fantasy football content creator.
struct ContentCreator: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var handle: String
    var platform: CreatorPlatform
    /// True for first-party Caldwell Corner channels.
    var isCaldwell: Bool
    var verified: Bool
    var followers: String
    var bio: String

    init(id: UUID = UUID(), name: String, handle: String, platform: CreatorPlatform,
         isCaldwell: Bool = false, verified: Bool = false, followers: String, bio: String) {
        self.id = id; self.name = name; self.handle = handle; self.platform = platform
        self.isCaldwell = isCaldwell; self.verified = verified
        self.followers = followers; self.bio = bio
    }
}

/// A single short-form video in the Reels feed.
/// Videos are never downloaded or re-hosted — only the external link is stored.
struct ReelPost: Identifiable, Codable, Hashable {
    let id: UUID
    var creatorID: UUID
    var title: String          // caption / title
    var thumbnailURL: String   // remote thumbnail (falls back to a styled placeholder)
    var videoURL: String       // external link opened by "Watch"
    var topic: ReelTopic
    var tags: [String]
    var datePosted: Date
    var durationSeconds: Int
    var section: ReelSection
    var views: String

    init(id: UUID = UUID(), creatorID: UUID, title: String, thumbnailURL: String,
         videoURL: String, topic: ReelTopic, tags: [String], datePosted: Date,
         durationSeconds: Int, section: ReelSection, views: String) {
        self.id = id; self.creatorID = creatorID; self.title = title
        self.thumbnailURL = thumbnailURL; self.videoURL = videoURL; self.topic = topic
        self.tags = tags; self.datePosted = datePosted; self.durationSeconds = durationSeconds
        self.section = section; self.views = views
    }

    var durationLabel: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var url: URL? { URL(string: videoURL) }
}
