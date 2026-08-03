import type {
  AiRecommendation,
  FantasyLeague,
  FantasyMatchup,
  FantasyRoster,
  Game,
  GameStatus,
  Injury,
  Player,
  PlayerProjection,
  PlayerWeeklyStat,
  Position,
  RecommendationKind,
  Team,
} from "./models.js";

export interface PlayerFilter {
  position?: Position;
  team?: string;
  /** Case-insensitive substring match on full name. */
  search?: string;
  limit?: number;
}

export interface GameFilter {
  season?: number;
  week?: number;
  team?: string;
  status?: GameStatus;
  limit?: number;
}

export interface InjuryFilter {
  season?: number;
  week?: number;
  team?: string;
}

/**
 * Storage abstraction for the normalized fantasy data layer. Implemented by an
 * in-memory store (default / dev / CI / tests) and a Supabase/PostgreSQL store
 * (production). The rest of the app depends only on this interface, so swapping
 * providers or the database never touches the API or the app.
 */
export interface DataStore {
  migrate(): Promise<void>;
  close(): Promise<void>;

  upsertTeams(rows: Team[]): Promise<number>;
  getTeams(): Promise<Team[]>;
  getTeam(teamId: string): Promise<Team | undefined>;

  upsertPlayers(rows: Player[]): Promise<number>;
  getPlayers(filter: PlayerFilter): Promise<Player[]>;
  getPlayer(playerId: string): Promise<Player | undefined>;

  upsertGames(rows: Game[]): Promise<number>;
  getGames(filter: GameFilter): Promise<Game[]>;
  getGame(gameId: string): Promise<Game | undefined>;

  upsertWeeklyStats(rows: PlayerWeeklyStat[]): Promise<number>;
  getPlayerWeeklyStats(
    playerId: string,
    season?: number,
    week?: number,
  ): Promise<PlayerWeeklyStat[]>;

  upsertProjections(rows: PlayerProjection[]): Promise<number>;
  getPlayerProjections(
    playerId: string,
    season?: number,
    week?: number,
  ): Promise<PlayerProjection[]>;

  upsertInjuries(rows: Injury[]): Promise<number>;
  /** Most recent injury row for a player (by season/week), if any. */
  getPlayerInjury(playerId: string): Promise<Injury | undefined>;
  getInjuries(filter: InjuryFilter): Promise<Injury[]>;

  upsertLeague(row: FantasyLeague): Promise<void>;
  getLeague(leagueId: string): Promise<FantasyLeague | undefined>;

  upsertRosters(rows: FantasyRoster[]): Promise<number>;
  getLeagueRosters(leagueId: string): Promise<FantasyRoster[]>;
  getRoster(leagueId: string, rosterId: string): Promise<FantasyRoster | undefined>;

  upsertMatchups(rows: FantasyMatchup[]): Promise<number>;
  getLeagueMatchups(leagueId: string, week?: number): Promise<FantasyMatchup[]>;

  insertRecommendation(rec: AiRecommendation): Promise<void>;
  getRecommendations(filter: {
    leagueId?: string;
    kind?: RecommendationKind;
    limit?: number;
  }): Promise<AiRecommendation[]>;
}
