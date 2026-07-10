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

/// A row from the `player_rankings` view: an eligible active QB/RB/WR/TE with
/// aggregated latest-season stats and a data-driven relevance score.
struct RankedPlayer: Identifiable, Codable, Hashable {
    var playerId: String            // players.id (uuid) — used to join stats
    var sleeperId: String?
    var fullName: String
    var position: String?
    var team: String?
    var age: Int?
    var height: String?
    var weight: String?
    var latestSeason: Int?
    var totalFantasyPointsPpr: Double?
    var gamesPlayed: Int?
    var fantasyPointsPerGame: Double?
    var recentUsage: Double?
    var relevanceScore: Double?

    var id: String { playerId }
    var displayName: String { fullName.isEmpty ? "Unknown Player" : fullName }

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case sleeperId = "sleeper_id"
        case fullName = "full_name"
        case position
        case team
        case age
        case height
        case weight
        case latestSeason = "latest_season"
        case totalFantasyPointsPpr = "total_fantasy_points_ppr"
        case gamesPlayed = "games_played"
        case fantasyPointsPerGame = "fantasy_points_per_game"
        case recentUsage = "recent_usage"
        case relevanceScore = "relevance_score"
    }
}

/// A scheduled/played game from the `games` table.
struct SupabaseGame: Identifiable, Codable, Hashable {
    var providerGameId: String
    var season: Int?
    var week: Int?
    var homeTeam: String?
    var awayTeam: String?
    var kickoffAt: String?
    var status: String?
    var venue: String?

    var id: String { providerGameId }

    func opponent(for team: String) -> String? {
        if homeTeam == team { return awayTeam }
        if awayTeam == team { return homeTeam }
        return nil
    }

    func isHome(for team: String) -> Bool { homeTeam == team }

    enum CodingKeys: String, CodingKey {
        case providerGameId = "provider_game_id"
        case season
        case week
        case homeTeam = "home_team"
        case awayTeam = "away_team"
        case kickoffAt = "kickoff_at"
        case status
        case venue
    }
}

/// A weekly box-score row from the `player_weekly_stats` table (keyed by the
/// player's uuid `player_id`).
struct SupabaseWeeklyStat: Identifiable, Codable, Hashable {
    var playerId: String
    var season: Int?
    var week: Int?
    var team: String?
    var opponent: String?
    var passingYards: Double?
    var passingTouchdowns: Double?
    var interceptions: Double?
    var rushingAttempts: Double?
    var rushingYards: Double?
    var rushingTouchdowns: Double?
    var targets: Double?
    var receptions: Double?
    var receivingYards: Double?
    var receivingTouchdowns: Double?
    var fumblesLost: Double?
    var fantasyPointsPpr: Double?
    var fantasyPointsHalfPpr: Double?
    var fantasyPointsStandard: Double?

    var id: String { "\(playerId)-\(season ?? 0)-\(week ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case season
        case week
        case team
        case opponent
        case passingYards = "passing_yards"
        case passingTouchdowns = "passing_touchdowns"
        case interceptions
        case rushingAttempts = "rushing_attempts"
        case rushingYards = "rushing_yards"
        case rushingTouchdowns = "rushing_touchdowns"
        case targets
        case receptions
        case receivingYards = "receiving_yards"
        case receivingTouchdowns = "receiving_touchdowns"
        case fumblesLost = "fumbles_lost"
        case fantasyPointsPpr = "fantasy_points_ppr"
        case fantasyPointsHalfPpr = "fantasy_points_half_ppr"
        case fantasyPointsStandard = "fantasy_points_standard"
    }
}

/// A row from `player_advanced_stats`. Only some metrics are populated today;
/// the UI shows only fields with real (non-null) values.
struct AdvancedStat: Identifiable, Codable, Hashable {
    var playerId: String
    var season: Int?
    var week: Int?
    var epaPerPlay: Double?
    var successRate: Double?
    var targetShare: Double?
    var airYardsShare: Double?
    var routeParticipation: Double?
    var yardsPerRouteRun: Double?
    var expectedFantasyPoints: Double?
    var fantasyPointsOverExpected: Double?

    var id: String { "\(playerId)-\(season ?? 0)-\(week ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case season
        case week
        case epaPerPlay = "epa_per_play"
        case successRate = "success_rate"
        case targetShare = "target_share"
        case airYardsShare = "air_yards_share"
        case routeParticipation = "route_participation"
        case yardsPerRouteRun = "yards_per_route_run"
        case expectedFantasyPoints = "expected_fantasy_points"
        case fantasyPointsOverExpected = "fantasy_points_over_expected"
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
