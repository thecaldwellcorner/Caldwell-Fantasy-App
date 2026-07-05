import type {
  DataSource,
  FantasyLeague,
  FantasyMatchup,
  FantasyRoster,
  Game,
  Injury,
  Player,
  PlayerProjection,
  PlayerWeeklyStat,
  Team,
} from "../data/models.js";

/**
 * Provider adapters isolate the rest of the backend from any specific vendor.
 * Today the mock adapters are used; later, a licensed provider (SportsDataIO,
 * MySportsFeeds, Sportradar, ...) can be dropped in behind these same interfaces
 * without touching the store, sync service, API, or the iOS app. Provider API
 * keys live only in the backend environment and are read inside the adapters.
 */

export interface ProviderContext {
  season: number;
  week: number;
}

/**
 * Source of NFL player stats, projections, injuries, schedule and live scores.
 * Every adapter stamps its own `sourceLabel` so provenance is preserved.
 */
export interface StatsProvider {
  readonly sourceLabel: DataSource;
  /** True if the adapter is fully configured (keys present, etc.). */
  isConfigured(): boolean;

  fetchTeams(ctx: ProviderContext): Promise<Team[]>;
  fetchPlayers(ctx: ProviderContext): Promise<Player[]>;
  fetchGames(ctx: ProviderContext): Promise<Game[]>;
  fetchWeeklyStats(ctx: ProviderContext): Promise<PlayerWeeklyStat[]>;
  fetchProjections(ctx: ProviderContext): Promise<PlayerProjection[]>;
  fetchInjuries(ctx: ProviderContext): Promise<Injury[]>;
}

/** Source of fantasy league data (Sleeper today, others later). */
export interface LeagueProvider {
  readonly sourceLabel: DataSource;
  isConfigured(): boolean;

  fetchLeague(leagueId: string, ctx: ProviderContext): Promise<FantasyLeague | undefined>;
  fetchRosters(leagueId: string, ctx: ProviderContext): Promise<FantasyRoster[]>;
  fetchMatchups(leagueId: string, ctx: ProviderContext): Promise<FantasyMatchup[]>;
}
