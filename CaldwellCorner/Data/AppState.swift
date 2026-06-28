import Foundation
import SwiftUI

/// Global observable application state. Acts as an in-memory repository
/// standing in for the backend API + auth + billing layers from the PRD.
@MainActor
final class AppState: ObservableObject {
    // Catalog
    @Published var players: [Player] = MockPlayers.all
    @Published var leagues: [League] = MockData.buildLeagues()
    @Published var news: [NewsItem] = MockData.buildNews()
    @Published var injuries: [InjuryReport] = MockData.buildInjuries()
    @Published var waivers: [WaiverTarget] = MockData.buildWaivers()
    @Published var startSit: [StartSitAdvice] = MockData.buildStartSit()
    @Published var bettingProps: [BettingProp] = MockData.buildBetting()
    @Published var draftGuide: [DraftGuideArticle] = MockData.buildDraftGuide()
    @Published var rookies: [RookieProspect] = MockData.buildRookies()
    @Published var pickValues: [DraftPickValue] = MockData.buildPickValues()
    @Published var premiumContent: [PremiumContent] = MockData.buildPremiumContent()
    @Published var achievements: [Achievement] = MockData.buildAchievements()
    @Published var plans: [PlanOption] = MockData.buildPlans()

    // Reels feed
    @Published var creators: [ContentCreator] = MockReels.creators
    @Published var reels: [ReelPost] = MockReels.reels
    @Published var savedReels: Set<UUID> = []

    // User
    @Published var profile: UserProfile = MockData.buildProfile()
    @Published var selectedLeagueID: UUID?

    // AI usage gating for free tier (PRD subscription model)
    @Published var aiMessagesUsedToday: Int = 0
    let freeAIDailyLimit = 5

    // Watchlist
    @Published var watchlist: Set<UUID> = []

    init() {
        selectedLeagueID = leagues.first?.id
    }

    // MARK: - Derived
    var isPremium: Bool { profile.tier == .premium }

    var selectedLeague: League? {
        guard let id = selectedLeagueID else { return leagues.first }
        return leagues.first(where: { $0.id == id }) ?? leagues.first
    }

    func player(_ id: UUID) -> Player? { players.first(where: { $0.id == id }) }

    func rosterPlayers(for team: FantasyTeam) -> [(slot: String, player: Player)] {
        team.roster.compactMap { slot in
            player(slot.playerID).map { (slot.slot, $0) }
        }
    }

    // MARK: - Mutations
    func upgradeToPremium() {
        withAnimation { profile.tier = .premium }
    }

    func toggleWatchlist(_ id: UUID) {
        if watchlist.contains(id) { watchlist.remove(id) } else { watchlist.insert(id) }
    }

    // MARK: - Reels
    func creator(_ id: UUID) -> ContentCreator? { creators.first(where: { $0.id == id }) }

    func reels(in section: ReelSection) -> [ReelPost] {
        reels.filter { $0.section == section }
    }

    func toggleSavedReel(_ id: UUID) {
        if savedReels.contains(id) { savedReels.remove(id) } else { savedReels.insert(id) }
    }

    var savedReelPosts: [ReelPost] { reels.filter { savedReels.contains($0.id) } }

    func canUseAI() -> Bool { isPremium || aiMessagesUsedToday < freeAIDailyLimit }

    func registerAIUsage() {
        if !isPremium { aiMessagesUsedToday += 1 }
    }

    func rankedPlayers(scoring: ScoringFormat, dynasty: Bool, superflex: Bool, position: Position?) -> [Player] {
        var list = players
        if let position { list = list.filter { $0.position == position } }
        list.sort { a, b in
            let av = dynasty ? a.dynastyValue : a.redraftValue
            let bv = dynasty ? b.dynastyValue : b.redraftValue
            // Superflex bumps QB value
            let aAdj = av + (superflex && a.position == .qb ? 8 : 0)
            let bAdj = bv + (superflex && b.position == .qb ? 8 : 0)
            return aAdj > bAdj
        }
        return list
    }
}
