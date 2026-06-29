import Foundation

/// Mock achievement catalog, activity feed and leaderboards for the
/// progression system. In production these are tracked server-side.
enum MockAchievements {

    private static func daysAgo(_ d: Double) -> Date { Date().addingTimeInterval(-d * 86_400) }

    static let all: [Achievement] = [
        // Trades
        Achievement(title: "First Trade", detail: "Complete your first trade.", systemImage: "arrow.left.arrow.right",
                    category: .trades, rarity: .common, ap: 50, progress: 1, target: 1, unlockedDate: daysAgo(120)),
        Achievement(title: "Trade Shark", detail: "Complete 25 trades.", systemImage: "fish.fill",
                    category: .trades, rarity: .rare, ap: 150, progress: 25, target: 25, unlockedDate: daysAgo(30)),
        Achievement(title: "Wheeler Dealer", detail: "Complete 100 trades.", systemImage: "arrow.triangle.swap",
                    category: .trades, rarity: .epic, ap: 300, progress: 61, target: 100),
        Achievement(title: "Fleece Master", detail: "Win 10 trades by the model grade.", systemImage: "crown.fill",
                    category: .trades, rarity: .legendary, ap: 500, progress: 4, target: 10),

        // Waivers
        Achievement(title: "Waiver Wizard", detail: "Hit on 10 waiver claims.", systemImage: "wand.and.stars",
                    category: .waivers, rarity: .rare, ap: 150, progress: 10, target: 10, unlockedDate: daysAgo(14)),
        Achievement(title: "FAAB Sniper", detail: "Land a top-5 weekly add with a single-dollar bid.", systemImage: "scope",
                    category: .waivers, rarity: .epic, ap: 300, progress: 1, target: 1, unlockedDate: daysAgo(6)),
        Achievement(title: "Wire to Wire", detail: "Add a player who finishes top-12 at their position.", systemImage: "bolt.horizontal.fill",
                    category: .waivers, rarity: .legendary, ap: 450, progress: 0, target: 1),

        // Draft
        Achievement(title: "Draft Day Hero", detail: "Draft 3 league-winners in one season.", systemImage: "star.circle.fill",
                    category: .draft, rarity: .epic, ap: 350, progress: 1, target: 3),
        Achievement(title: "Mock Marathon", detail: "Complete 20 mock drafts.", systemImage: "person.3.sequence.fill",
                    category: .draft, rarity: .rare, ap: 150, progress: 12, target: 20),
        Achievement(title: "Perfect Draft", detail: "Every pick beats its ADP value.", systemImage: "checkmark.seal.fill",
                    category: .draft, rarity: .mythic, ap: 750, progress: 0, target: 1),

        // Weekly performance
        Achievement(title: "Perfect Lineup", detail: "Set an optimal lineup for a week.", systemImage: "checkmark.circle.fill",
                    category: .weekly, rarity: .rare, ap: 150, progress: 1, target: 1, unlockedDate: daysAgo(3)),
        Achievement(title: "Highest Scorer", detail: "Post the week's top score in your league.", systemImage: "flame.fill",
                    category: .weekly, rarity: .epic, ap: 250, progress: 3, target: 5),
        Achievement(title: "Comeback Kid", detail: "Win after being projected to lose by 20+.", systemImage: "arrow.uturn.up",
                    category: .weekly, rarity: .rare, ap: 175, progress: 1, target: 1, unlockedDate: daysAgo(10)),

        // Season performance
        Achievement(title: "League Champion", detail: "Win a league title.", systemImage: "trophy.fill",
                    category: .season, rarity: .legendary, ap: 900, progress: 3, target: 1, unlockedDate: daysAgo(200)),
        Achievement(title: "Undefeated", detail: "Finish a regular season without a loss.", systemImage: "shield.lefthalf.filled",
                    category: .season, rarity: .mythic, ap: 800, progress: 0, target: 1),
        Achievement(title: "Dynasty Architect", detail: "Build a top-3 dynasty roster by team value.", systemImage: "building.columns.fill",
                    category: .season, rarity: .epic, ap: 350, progress: 2, target: 3),

        // Daily usage
        Achievement(title: "7-Day Streak", detail: "Open the app 7 days in a row.", systemImage: "flame.fill",
                    category: .daily, rarity: .common, ap: 75, progress: 7, target: 7, unlockedDate: daysAgo(1)),
        Achievement(title: "30-Day Streak", detail: "Open the app 30 days in a row.", systemImage: "calendar",
                    category: .daily, rarity: .rare, ap: 200, progress: 18, target: 30),
        Achievement(title: "Coach's Confidant", detail: "Ask the AI Coach 50 questions.", systemImage: "sparkles",
                    category: .daily, rarity: .rare, ap: 150, progress: 33, target: 50),

        // Milestones
        Achievement(title: "Getting Started", detail: "Sync your first league.", systemImage: "arrow.triangle.2.circlepath",
                    category: .milestones, rarity: .common, ap: 50, progress: 1, target: 1, unlockedDate: daysAgo(120)),
        Achievement(title: "Multi-League Manager", detail: "Manage 5 leagues at once.", systemImage: "square.stack.3d.up.fill",
                    category: .milestones, rarity: .rare, ap: 150, progress: 2, target: 5),

        // Hidden
        Achievement(title: "Against All Odds", detail: "Win a matchup with the lowest projection in the league.", systemImage: "dice.fill",
                    category: .hidden, rarity: .epic, ap: 300, progress: 1, target: 1, unlockedDate: daysAgo(20), isHidden: true),
        Achievement(title: "The Caldwell Special", detail: "Follow a Caldwell Take and win the week.", systemImage: "quote.bubble.fill",
                    category: .hidden, rarity: .legendary, ap: 500, progress: 0, target: 1, isHidden: true),
    ]

    static let activity: [AchievementActivity] = [
        .init(kind: .unlock, title: "7-Day Streak", detail: "Daily Usage · Common", ap: 75, rarity: .common, date: Date().addingTimeInterval(-3600 * 5)),
        .init(kind: .rankUp, title: "Climbed to #1 — Weekly", detail: "Up 3 spots on the weekly board", date: Date().addingTimeInterval(-3600 * 9)),
        .init(kind: .unlock, title: "FAAB Sniper", detail: "Waivers · Epic", ap: 300, rarity: .epic, date: daysAgo(6)),
        .init(kind: .levelUp, title: "Reached Level 5 — Veteran", detail: "+1 level", date: daysAgo(6.2)),
        .init(kind: .progress, title: "Wheeler Dealer", detail: "61/100 trades", date: daysAgo(9)),
        .init(kind: .unlock, title: "Comeback Kid", detail: "Weekly Performance · Rare", ap: 175, rarity: .rare, date: daysAgo(10)),
        .init(kind: .unlock, title: "Waiver Wizard", detail: "Waivers · Rare", ap: 150, rarity: .rare, date: daysAgo(14)),
    ]

    // MARK: - Leaderboards
    private struct Seed { let name: String; let handle: String; let ap: Int; let rarity: AchievementRarity; let prev: Int }

    static func leaderboard(_ scope: LeaderboardScope, userAP: Int) -> [LeaderboardEntry] {
        // Each scope has a different field + the user lands at a different rank.
        let seeds: [Seed]
        switch scope {
        case .global:
            seeds = [
                Seed(name: "Marcus Bell", handle: "@gridirongoblin", ap: 9120, rarity: .mythic, prev: 1),
                Seed(name: "Priya N.", handle: "@dynastydestroyer", ap: 8740, rarity: .mythic, prev: 3),
                Seed(name: "Carson Caldwell", handle: "@carsoncaldwell", ap: 8650, rarity: .legendary, prev: 2),
                Seed(name: "Tyler R.", handle: "@waiverwarrior", ap: 7980, rarity: .legendary, prev: 4),
                Seed(name: "Sam K.", handle: "@tankcommander", ap: 7210, rarity: .epic, prev: 6),
            ]
            return assemble(scope: scope, seeds: seeds, userRank: 14, userPrev: 17, userAP: userAP, total: 18)
        case .league:
            seeds = [
                Seed(name: "Marcus Bell", handle: "@gridirongoblin", ap: 4120, rarity: .legendary, prev: 1),
                Seed(name: "Priya N.", handle: "@dynastydestroyer", ap: 3980, rarity: .legendary, prev: 2),
            ]
            return assemble(scope: scope, seeds: seeds, userRank: 3, userPrev: 5, userAP: userAP, total: 12)
        case .weekly:
            seeds = []
            return assemble(scope: scope, seeds: seeds, userRank: 1, userPrev: 4, userAP: max(420, userAP / 10), total: 12)
        case .monthly:
            seeds = [
                Seed(name: "Tyler R.", handle: "@waiverwarrior", ap: 1820, rarity: .epic, prev: 2),
            ]
            return assemble(scope: scope, seeds: seeds, userRank: 2, userPrev: 6, userAP: max(1500, userAP / 3), total: 14)
        case .season:
            seeds = [
                Seed(name: "Priya N.", handle: "@dynastydestroyer", ap: 5200, rarity: .legendary, prev: 1),
                Seed(name: "Marcus Bell", handle: "@gridirongoblin", ap: 5050, rarity: .legendary, prev: 3),
            ]
            return assemble(scope: scope, seeds: seeds, userRank: 4, userPrev: 4, userAP: max(3000, userAP), total: 16)
        case .allTime:
            seeds = [
                Seed(name: "Carson Caldwell", handle: "@carsoncaldwell", ap: 24800, rarity: .mythic, prev: 1),
                Seed(name: "Marcus Bell", handle: "@gridirongoblin", ap: 21500, rarity: .mythic, prev: 2),
                Seed(name: "Priya N.", handle: "@dynastydestroyer", ap: 19900, rarity: .mythic, prev: 4),
            ]
            return assemble(scope: scope, seeds: seeds, userRank: 9, userPrev: 11, userAP: max(8000, userAP * 3), total: 25)
        }
    }

    private static func assemble(scope: LeaderboardScope, seeds: [Seed], userRank: Int,
                                 userPrev: Int, userAP: Int, total: Int) -> [LeaderboardEntry] {
        var entries: [LeaderboardEntry] = []
        let filler = ["Jordan", "Alex", "Casey", "Morgan", "Riley", "Drew", "Jamie", "Quinn", "Avery", "Reese", "Skyler", "Devon", "Harper", "Rowan"]
        var rank = 1
        var seedIdx = 0
        var fillerIdx = 0
        // Top ranks from seeds, then fillers, inserting the user at userRank.
        while rank <= total {
            if rank == userRank {
                entries.append(LeaderboardEntry(
                    rank: rank, previousRank: userPrev, name: "Corner GM", handle: "@cornergm",
                    ap: userAP, level: Progression.level(forAP: userAP), topRarity: .legendary, isUser: true))
            } else if seedIdx < seeds.count {
                let s = seeds[seedIdx]; seedIdx += 1
                entries.append(LeaderboardEntry(
                    rank: rank, previousRank: s.prev == rank ? rank : s.prev,
                    name: s.name, handle: s.handle, ap: s.ap, level: Progression.level(forAP: s.ap),
                    topRarity: s.rarity))
            } else {
                let baseAP = max(200, userAP - (rank - userRank) * 220 + (rank < userRank ? 1800 : 0))
                let name = filler[fillerIdx % filler.count]; fillerIdx += 1
                let prev = rank + (rank % 3 == 0 ? 1 : rank % 2 == 0 ? -1 : 0)
                entries.append(LeaderboardEntry(
                    rank: rank, previousRank: max(1, prev), name: "\(name) \(Character(UnicodeScalar(65 + (fillerIdx % 26))!)).",
                    handle: "@\(name.lowercased())\(rank)", ap: max(150, baseAP),
                    level: Progression.level(forAP: max(150, baseAP)),
                    topRarity: rank < userRank ? .epic : .rare))
            }
            rank += 1
        }
        return entries
    }
}
