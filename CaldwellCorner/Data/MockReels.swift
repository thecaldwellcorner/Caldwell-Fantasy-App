import Foundation

/// Mock creators + reels for the Reels discovery feed.
/// All video links are external URLs — nothing is downloaded or re-hosted.
enum MockReels {

    static let creators: [ContentCreator] = [
        ContentCreator(name: "The Caldwell Corner", handle: "@thecaldwellcorner",
                       platform: .youtube, isCaldwell: true, verified: true,
                       followers: "412K", bio: "Your fantasy football authority."),
        ContentCreator(name: "Caldwell Corner Clips", handle: "@caldwellclips",
                       platform: .tiktok, isCaldwell: true, verified: true,
                       followers: "188K", bio: "Bite-size fantasy takes."),
        ContentCreator(name: "Carson Caldwell", handle: "@carsoncaldwell",
                       platform: .instagram, isCaldwell: true, verified: true,
                       followers: "95K", bio: "Founder, The Caldwell Corner."),
        ContentCreator(name: "Gridiron Analytics", handle: "@gridironanalytics",
                       platform: .youtube, verified: true,
                       followers: "256K", bio: "Advanced metrics & film."),
        ContentCreator(name: "Dynasty Dugout", handle: "@dynastydugout",
                       platform: .youtube, verified: true,
                       followers: "143K", bio: "Dynasty rankings & rookie scouting."),
        ContentCreator(name: "The Target Share", handle: "@targetshare",
                       platform: .tiktok, verified: false,
                       followers: "77K", bio: "Usage trends that win leagues."),
        ContentCreator(name: "RotoEdge", handle: "@rotoedge",
                       platform: .x, verified: true,
                       followers: "310K", bio: "Breaking news + fantasy impact."),
        ContentCreator(name: "Film & Fantasy", handle: "@filmandfantasy",
                       platform: .podcast, verified: false,
                       followers: "61K", bio: "Where tape meets fantasy."),
    ]

    private static func id(_ handle: String) -> UUID {
        creators.first(where: { $0.handle == handle })?.id ?? UUID()
    }

    private static func daysAgo(_ d: Double) -> Date {
        Date().addingTimeInterval(-d * 86_400)
    }

    static let reels: [ReelPost] = [
        // ---- Caldwell Corner (originals) ----
        ReelPost(creatorID: id("@thecaldwellcorner"),
                 title: "5 League-Winning Sleepers Nobody Is Drafting",
                 thumbnailURL: "https://img.caldwellcorner.app/reels/sleepers-2025.jpg",
                 videoURL: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                 topic: .sleepers, tags: ["Sleepers", "ADP", "Value"],
                 datePosted: daysAgo(1), durationSeconds: 184,
                 section: .caldwellCorner, views: "82K"),
        ReelPost(creatorID: id("@thecaldwellcorner"),
                 title: "Draft Strategy: Zero-RB Is Back in 2025",
                 thumbnailURL: "https://img.caldwellcorner.app/reels/zero-rb.jpg",
                 videoURL: "https://www.youtube.com/watch?v=draftstrategy",
                 topic: .draftStrategy, tags: ["Draft", "Strategy", "Zero-RB"],
                 datePosted: daysAgo(3), durationSeconds: 256,
                 section: .caldwellCorner, views: "121K"),
        ReelPost(creatorID: id("@caldwellclips"),
                 title: "3 Dynasty Buy-Lows Before Their Value Explodes",
                 thumbnailURL: "https://img.caldwellcorner.app/reels/dynasty-buys.jpg",
                 videoURL: "https://www.tiktok.com/@caldwellclips/video/123",
                 topic: .dynastyBuys, tags: ["Dynasty", "Buy-Low"],
                 datePosted: daysAgo(2), durationSeconds: 58,
                 section: .caldwellCorner, views: "54K"),

        // ---- Caldwell Coverage (our take on the news) ----
        ReelPost(creatorID: id("@carsoncaldwell"),
                 title: "Reaction: What the CMC Injury Means for Your Lineup",
                 thumbnailURL: "https://img.caldwellcorner.app/reels/cmc-injury.jpg",
                 videoURL: "https://www.instagram.com/reel/cmc-injury",
                 topic: .injuryNews, tags: ["Injury", "RB", "Lineup"],
                 datePosted: daysAgo(0.2), durationSeconds: 92,
                 section: .caldwellCoverage, views: "33K"),
        ReelPost(creatorID: id("@thecaldwellcorner"),
                 title: "Trade Deadline Targets Every Contender Should Call About",
                 thumbnailURL: "https://img.caldwellcorner.app/reels/trade-targets.jpg",
                 videoURL: "https://www.youtube.com/watch?v=tradetargets",
                 topic: .tradeTargets, tags: ["Trade", "Contender", "Deadline"],
                 datePosted: daysAgo(1.5), durationSeconds: 203,
                 section: .caldwellCoverage, views: "67K"),
        ReelPost(creatorID: id("@caldwellclips"),
                 title: "Waiver Wire: The #1 Add at Every Position This Week",
                 thumbnailURL: "https://img.caldwellcorner.app/reels/waiver-week7.jpg",
                 videoURL: "https://www.tiktok.com/@caldwellclips/video/456",
                 topic: .waiverPickups, tags: ["Waivers", "FAAB", "Week 7"],
                 datePosted: daysAgo(0.5), durationSeconds: 61,
                 section: .caldwellCoverage, views: "41K"),

        // ---- Recommended Creators ----
        ReelPost(creatorID: id("@gridironanalytics"),
                 title: "The Target Share Breakout Nobody Is Talking About",
                 thumbnailURL: "https://img.example.com/reels/breakout-ts.jpg",
                 videoURL: "https://www.youtube.com/watch?v=breakoutts",
                 topic: .sleepers, tags: ["Breakout", "Target Share", "WR"],
                 datePosted: daysAgo(2), durationSeconds: 312,
                 section: .recommendedCreators, views: "98K"),
        ReelPost(creatorID: id("@dynastydugout"),
                 title: "Rookie Dynasty Buys Before Their Rookie Year Ends",
                 thumbnailURL: "https://img.example.com/reels/rookie-buys.jpg",
                 videoURL: "https://www.youtube.com/watch?v=rookiebuys",
                 topic: .dynastyBuys, tags: ["Dynasty", "Rookies", "Buy-Low"],
                 datePosted: daysAgo(4), durationSeconds: 274,
                 section: .recommendedCreators, views: "72K"),
        ReelPost(creatorID: id("@targetshare"),
                 title: "Snap Count Risers: 3 Backs Taking Over Their Backfield",
                 thumbnailURL: "https://img.example.com/reels/snap-risers.jpg",
                 videoURL: "https://www.tiktok.com/@targetshare/video/789",
                 topic: .waiverPickups, tags: ["Waivers", "RB", "Snaps"],
                 datePosted: daysAgo(1), durationSeconds: 47,
                 section: .recommendedCreators, views: "120K"),
        ReelPost(creatorID: id("@filmandfantasy"),
                 title: "Film Room: Why This Trade Target Is Undervalued",
                 thumbnailURL: "https://img.example.com/reels/film-trade.jpg",
                 videoURL: "https://www.youtube.com/watch?v=filmtrade",
                 topic: .tradeTargets, tags: ["Trade", "Film", "Value"],
                 datePosted: daysAgo(5), durationSeconds: 198,
                 section: .recommendedCreators, views: "44K"),

        // ---- Trending Fantasy Clips ----
        ReelPost(creatorID: id("@rotoedge"),
                 title: "BREAKING: Starter Ruled Out — Here's the Pivot",
                 thumbnailURL: "https://img.example.com/reels/breaking-out.jpg",
                 videoURL: "https://twitter.com/rotoedge/status/123",
                 topic: .injuryNews, tags: ["Injury", "Breaking", "Pivot"],
                 datePosted: daysAgo(0.1), durationSeconds: 38,
                 section: .trendingClips, views: "210K"),
        ReelPost(creatorID: id("@gridironanalytics"),
                 title: "Draft Strategy: The Perfect First 5 Rounds",
                 thumbnailURL: "https://img.example.com/reels/first5.jpg",
                 videoURL: "https://www.youtube.com/watch?v=first5rounds",
                 topic: .draftStrategy, tags: ["Draft", "Strategy", "Tiers"],
                 datePosted: daysAgo(2.5), durationSeconds: 421,
                 section: .trendingClips, views: "305K"),
        ReelPost(creatorID: id("@targetshare"),
                 title: "This Sleeper Just Out-Snapped the Starter",
                 thumbnailURL: "https://img.example.com/reels/sleeper-snaps.jpg",
                 videoURL: "https://www.tiktok.com/@targetshare/video/999",
                 topic: .sleepers, tags: ["Sleeper", "Snaps", "Breakout"],
                 datePosted: daysAgo(0.8), durationSeconds: 52,
                 section: .trendingClips, views: "176K"),
        ReelPost(creatorID: id("@dynastydugout"),
                 title: "Sell High Now: 4 Dynasty Assets at Peak Value",
                 thumbnailURL: "https://img.example.com/reels/sell-high.jpg",
                 videoURL: "https://www.youtube.com/watch?v=sellhigh",
                 topic: .dynastyBuys, tags: ["Dynasty", "Sell-High", "Value"],
                 datePosted: daysAgo(3.5), durationSeconds: 233,
                 section: .trendingClips, views: "88K"),
    ]

    static func creator(_ id: UUID) -> ContentCreator? {
        creators.first(where: { $0.id == id })
    }
}
