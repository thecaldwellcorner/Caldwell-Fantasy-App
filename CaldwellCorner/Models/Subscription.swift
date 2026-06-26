import Foundation

enum SubscriptionTier: String, Codable {
    case free = "Free"
    case premium = "Premium"
}

struct PlanOption: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var price: String
    var period: String
    var perks: [String]
    var badge: String?
    var isFeatured: Bool
}

struct Achievement: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var detail: String
    var systemImage: String
    var unlocked: Bool
}

struct UserProfile: Codable, Hashable {
    var displayName: String
    var handle: String
    var favoriteTeam: String
    var memberSince: String
    var lifetimeLeagues: Int
    var championships: Int
    var tier: SubscriptionTier
}
