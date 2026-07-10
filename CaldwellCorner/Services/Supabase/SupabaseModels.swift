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

/// A scheduled/played game from the optional `games` table.
struct SupabaseGame: Identifiable, Codable, Hashable {
    var gameId: String
    var season: Int?
    var week: Int?
    var seasonType: String?
    var homeTeam: String?
    var awayTeam: String?
    var kickoff: String?
    var status: String?
    var homeScore: Int?
    var awayScore: Int?

    var id: String { gameId }

    /// The opponent for a given team, or nil if this game doesn't involve them.
    func opponent(for team: String) -> String? {
        if homeTeam == team { return awayTeam }
        if awayTeam == team { return homeTeam }
        return nil
    }

    func isHome(for team: String) -> Bool { homeTeam == team }

    enum CodingKeys: String, CodingKey {
        case gameId = "game_id"
        case season
        case week
        case seasonType = "season_type"
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case kickoff
        case status
        case homeScore = "home_score"
        case awayScore = "away_score"
    }
}

/// A projection row from the optional `player_projections` table.
struct SupabaseProjection: Identifiable, Codable, Hashable {
    var playerId: String
    var season: Int?
    var week: Int?
    var projFantasyPointsPpr: Double?
    var projFantasyPointsHalfPpr: Double?
    var projFantasyPointsStandard: Double?
    var floor: Double?
    var ceiling: Double?

    var id: String { "\(playerId)-\(season ?? 0)-\(week ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case season
        case week
        case projFantasyPointsPpr = "proj_fantasy_points_ppr"
        case projFantasyPointsHalfPpr = "proj_fantasy_points_half_ppr"
        case projFantasyPointsStandard = "proj_fantasy_points_standard"
        case floor
        case ceiling
    }
}

/// A weekly box-score row from the optional `player_weekly_stats` table.
struct SupabaseWeeklyStat: Identifiable, Codable, Hashable {
    var playerId: String
    var season: Int?
    var week: Int?
    var opponent: String?
    var passingYards: Double?
    var passingTds: Double?
    var rushingYards: Double?
    var rushingTds: Double?
    var receptions: Double?
    var receivingYards: Double?
    var receivingTds: Double?
    var fantasyPointsPpr: Double?

    var id: String { "\(playerId)-\(season ?? 0)-\(week ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case season
        case week
        case opponent
        case passingYards = "passing_yards"
        case passingTds = "passing_tds"
        case rushingYards = "rushing_yards"
        case rushingTds = "rushing_tds"
        case receptions
        case receivingYards = "receiving_yards"
        case receivingTds = "receiving_tds"
        case fantasyPointsPpr = "fantasy_points_ppr"
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
