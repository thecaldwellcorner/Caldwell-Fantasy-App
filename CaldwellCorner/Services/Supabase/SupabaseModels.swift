import Foundation

/// A player row as stored in the Supabase `players` table (populated by the
/// `importPlayers.js` sync). Field names map to the table's snake_case columns.
struct SupabasePlayer: Identifiable, Codable, Hashable {
    var sleeperId: String
    var fullName: String?
    var firstName: String?
    var lastName: String?
    var team: String?
    var position: String?
    var age: Int?
    var height: String?
    var weight: String?
    var active: Bool?
    var fantasyPositions: [String]?
    var updatedAt: String?

    var id: String { sleeperId }

    /// Best available display name.
    var displayName: String {
        if let full = fullName, !full.isEmpty { return full }
        let parts = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Unknown Player" : parts.joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case sleeperId = "sleeper_id"
        case fullName = "full_name"
        case firstName = "first_name"
        case lastName = "last_name"
        case team
        case position
        case age
        case height
        case weight
        case active
        case fantasyPositions = "fantasy_positions"
        case updatedAt = "updated_at"
    }
}

/// A team row from the Supabase `teams` table. All descriptive fields are
/// optional so the model tolerates schema differences across projects.
struct SupabaseTeam: Identifiable, Codable, Hashable {
    var teamId: String?
    var name: String?
    var abbreviation: String?
    var conference: String?
    var division: String?
    var byeWeek: Int?
    var logoUrl: String?

    /// Canonical abbreviation used to filter players by team.
    var code: String? { abbreviation ?? teamId }

    var id: String { teamId ?? abbreviation ?? name ?? UUID().uuidString }

    var displayName: String { name ?? abbreviation ?? teamId ?? "Team" }

    enum CodingKeys: String, CodingKey {
        case teamId = "team_id"
        case name
        case abbreviation
        case conference
        case division
        case byeWeek = "bye_week"
        case logoUrl = "logo_url"
    }
}

/// Generic UI state for an async load: covers loading, empty, error, and success
/// so views can render the right thing for each case.
enum LoadState<Value>: Equatable where Value: Equatable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(String)

    var value: Value? {
        if case let .loaded(v) = self { return v }
        return nil
    }
}
