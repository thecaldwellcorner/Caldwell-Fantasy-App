import Foundation

// MARK: - Rarity
enum AchievementRarity: String, Codable, CaseIterable, Hashable, Identifiable {
    case common = "Common"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
    case mythic = "Mythic"
    var id: String { rawValue }

    /// Sort weight (higher = rarer).
    var order: Int {
        switch self {
        case .common: return 0
        case .rare: return 1
        case .epic: return 2
        case .legendary: return 3
        case .mythic: return 4
        }
    }
}

// MARK: - Category
enum AchievementCategory: String, Codable, CaseIterable, Hashable, Identifiable {
    case trades = "Trades"
    case waivers = "Waivers"
    case draft = "Draft"
    case weekly = "Weekly Performance"
    case season = "Season Performance"
    case daily = "Daily Usage"
    case milestones = "Milestones"
    case hidden = "Hidden"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .trades: return "arrow.left.arrow.right.circle.fill"
        case .waivers: return "hand.raised.fill"
        case .draft: return "person.3.sequence.fill"
        case .weekly: return "calendar.badge.clock"
        case .season: return "trophy.fill"
        case .daily: return "flame.fill"
        case .milestones: return "flag.checkered"
        case .hidden: return "questionmark.diamond.fill"
        }
    }
}

// MARK: - Achievement
struct Achievement: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var systemImage: String
    var category: AchievementCategory
    var rarity: AchievementRarity
    var ap: Int                 // Achievement Points awarded on unlock
    var progress: Int
    var target: Int
    var unlockedDate: Date?
    var isHidden: Bool

    init(id: UUID = UUID(), title: String, detail: String, systemImage: String,
         category: AchievementCategory, rarity: AchievementRarity, ap: Int,
         progress: Int, target: Int, unlockedDate: Date? = nil, isHidden: Bool = false) {
        self.id = id; self.title = title; self.detail = detail; self.systemImage = systemImage
        self.category = category; self.rarity = rarity; self.ap = ap
        self.progress = progress; self.target = target
        self.unlockedDate = unlockedDate; self.isHidden = isHidden
    }

    var unlocked: Bool { progress >= target }
    var fraction: Double { target <= 0 ? 0 : min(1, Double(progress) / Double(target)) }
    var earnedAP: Int { unlocked ? ap : 0 }

    /// Hidden, still-locked achievements are masked in the UI.
    var isMasked: Bool { isHidden && !unlocked }
    var displayTitle: String { isMasked ? "Hidden Achievement" : title }
    var displayDetail: String { isMasked ? "Keep playing to reveal this one." : detail }
    var displayIcon: String { isMasked ? "questionmark.diamond.fill" : systemImage }
}

// MARK: - Activity history
struct AchievementActivity: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, Hashable { case unlock, progress, levelUp, rankUp }
    let id: UUID
    var kind: Kind
    var title: String
    var detail: String
    var ap: Int
    var rarity: AchievementRarity?
    var date: Date

    init(id: UUID = UUID(), kind: Kind, title: String, detail: String,
         ap: Int = 0, rarity: AchievementRarity? = nil, date: Date) {
        self.id = id; self.kind = kind; self.title = title; self.detail = detail
        self.ap = ap; self.rarity = rarity; self.date = date
    }
}

// MARK: - Leaderboards
enum LeaderboardScope: String, CaseIterable, Identifiable, Hashable {
    case global = "Global"
    case league = "League"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case season = "Season"
    case allTime = "All-Time"
    var id: String { rawValue }
}

struct LeaderboardEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var rank: Int
    var previousRank: Int
    var name: String
    var handle: String
    var ap: Int
    var level: Int
    var topRarity: AchievementRarity
    var isUser: Bool

    init(id: UUID = UUID(), rank: Int, previousRank: Int, name: String, handle: String,
         ap: Int, level: Int, topRarity: AchievementRarity, isUser: Bool = false) {
        self.id = id; self.rank = rank; self.previousRank = previousRank
        self.name = name; self.handle = handle; self.ap = ap; self.level = level
        self.topRarity = topRarity; self.isUser = isUser
    }

    /// Positive = climbed, negative = dropped, 0 = held.
    var movement: Int { previousRank - rank }
}

// MARK: - Progression (AP → level)
enum Progression {
    /// Cumulative AP required to *reach* a level. Level 1 = 0 AP.
    static func apForLevel(_ level: Int) -> Int {
        let l = max(1, level)
        return 100 * (l - 1) * l   // 0, 200, 600, 1200, 2000, 3000…
    }

    static func level(forAP ap: Int) -> Int {
        var level = 1
        while apForLevel(level + 1) <= ap { level += 1 }
        return level
    }

    static func title(forLevel level: Int) -> String {
        switch level {
        case ..<2: return "Rookie"
        case 2..<4: return "Starter"
        case 4..<6: return "Veteran"
        case 6..<8: return "Pro"
        case 8..<11: return "All-Pro"
        case 11..<15: return "Hall of Famer"
        default: return "Legend"
        }
    }

    struct Summary: Hashable {
        var totalAP: Int
        var unlockedCount: Int
        var totalCount: Int
        var level: Int
        var levelTitle: String
        var apIntoLevel: Int
        var apForNextLevel: Int
        var progressInLevel: Double   // 0…1
        var completion: Double        // 0…1 of all achievements
        var rarityCounts: [AchievementRarity: Int]
    }

    static func summary(for achievements: [Achievement]) -> Summary {
        let unlocked = achievements.filter { $0.unlocked }
        let totalAP = unlocked.reduce(0) { $0 + $1.ap }
        let level = level(forAP: totalAP)
        let floorAP = apForLevel(level)
        let nextAP = apForLevel(level + 1)
        let span = max(1, nextAP - floorAP)
        var rarity: [AchievementRarity: Int] = [:]
        for a in unlocked { rarity[a.rarity, default: 0] += 1 }
        return Summary(
            totalAP: totalAP,
            unlockedCount: unlocked.count,
            totalCount: achievements.count,
            level: level,
            levelTitle: title(forLevel: level),
            apIntoLevel: totalAP - floorAP,
            apForNextLevel: nextAP - floorAP,
            progressInLevel: min(1, Double(totalAP - floorAP) / Double(span)),
            completion: achievements.isEmpty ? 0 : Double(unlocked.count) / Double(achievements.count),
            rarityCounts: rarity)
    }
}
