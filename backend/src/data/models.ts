/**
 * Canonical, normalized domain models for the Caldwell IQ data layer.
 *
 * Everything the app sees flows through these shapes. Each record carries a
 * `meta: SourceMeta` block so every stat knows where it came from and when it
 * was current — this is what powers the app's "last updated" UI and the
 * missing/stale-data fallbacks. Raw provider payloads are normalized into these
 * models by the sync service before being stored.
 */

/** Internal source label attached to every stored record. */
export type DataSource =
  | "mock"
  | "sleeper"
  | "sportsdataio"
  | "mysportsfeeds"
  | "sportradar"
  | "nflverse";

export interface SourceMeta {
  /** Which provider adapter produced this record. */
  source: DataSource;
  /** ISO timestamp the provider reported the data as current ("as of"). */
  sourceUpdatedAt: string;
  /** ISO timestamp we ingested/normalized it into our store. */
  fetchedAt: string;
}

export type Position = "QB" | "RB" | "WR" | "TE" | "K" | "DEF";

export type InjuryDesignation =
  | "Healthy"
  | "Questionable"
  | "Doubtful"
  | "Out"
  | "IR"
  | "PUP"
  | "SUS";

export type GameStatus = "scheduled" | "in_progress" | "final" | "postponed";

export type SeasonType = "pre" | "regular" | "post";

export type ScoringFormat = "ppr" | "half_ppr" | "standard";

export interface Team {
  teamId: string;
  name: string;
  abbreviation: string;
  conference: string | null;
  division: string | null;
  byeWeek: number | null;
  logoUrl: string | null;
  meta: SourceMeta;
}

export interface Player {
  playerId: string;
  fullName: string;
  firstName: string | null;
  lastName: string | null;
  position: Position;
  team: string | null;
  jerseyNumber: number | null;
  age: number | null;
  heightInches: number | null;
  weightLbs: number | null;
  college: string | null;
  status: string;
  headshotUrl: string | null;
  meta: SourceMeta;
}

export interface Game {
  gameId: string;
  season: number;
  week: number;
  seasonType: SeasonType;
  homeTeam: string;
  awayTeam: string;
  kickoff: string | null;
  status: GameStatus;
  homeScore: number | null;
  awayScore: number | null;
  quarter: number | null;
  clock: string | null;
  meta: SourceMeta;
}

export interface PlayerWeeklyStat {
  playerId: string;
  season: number;
  /** 0 = season-to-date. */
  week: number;
  team: string | null;
  opponent: string | null;

  passingYards: number;
  passingTds: number;
  interceptions: number;
  completions: number;
  passAttempts: number;

  carries: number;
  rushingYards: number;
  rushingTds: number;

  targets: number;
  receptions: number;
  receivingYards: number;
  receivingTds: number;
  airYards: number;
  targetShare: number;

  fumblesLost: number;
  snaps: number;
  snapShare: number;

  fantasyPointsPpr: number;
  fantasyPointsHalfPpr: number;
  fantasyPointsStandard: number;

  meta: SourceMeta;
}

export interface PlayerProjection {
  playerId: string;
  season: number;
  /** 0 = rest-of-season. */
  week: number;

  projPassingYards: number;
  projPassingTds: number;
  projRushingYards: number;
  projRushingTds: number;
  projReceptions: number;
  projReceivingYards: number;
  projReceivingTds: number;

  projFantasyPointsPpr: number;
  projFantasyPointsHalfPpr: number;
  projFantasyPointsStandard: number;
  floor: number;
  ceiling: number;

  meta: SourceMeta;
}

export interface Injury {
  playerId: string;
  season: number;
  week: number;
  status: InjuryDesignation;
  bodyPart: string | null;
  practiceStatus: string | null;
  returnEstimate: string | null;
  reportDate: string | null;
  note: string | null;
  meta: SourceMeta;
}

export interface FantasyLeague {
  leagueId: string;
  platform: string;
  name: string;
  season: number;
  scoring: ScoringFormat;
  teamCount: number;
  superflex: boolean;
  dynasty: boolean;
  rosterSlots: Record<string, number>;
  meta: SourceMeta;
}

export interface FantasyRoster {
  leagueId: string;
  rosterId: string;
  ownerId: string | null;
  teamName: string | null;
  ownerName: string | null;
  playerIds: string[];
  starters: string[];
  wins: number;
  losses: number;
  ties: number;
  pointsFor: number;
  pointsAgainst: number;
  meta: SourceMeta;
}

export interface FantasyMatchup {
  leagueId: string;
  week: number;
  matchupId: string;
  rosterId: string;
  opponentRosterId: string | null;
  points: number;
  projectedPoints: number | null;
  isWinner: boolean | null;
  meta: SourceMeta;
}

/** A single stat cited by a recommendation, with its own provenance. */
export interface KeyStat {
  label: string;
  value: string;
  playerId?: string;
  source: DataSource;
}

export type RecommendationKind = "start_sit" | "trade" | "waiver";

export interface AiRecommendation {
  id: string;
  leagueId: string | null;
  kind: RecommendationKind;
  subjectPlayerIds: string[];
  recommendation: string;
  reasoning: string;
  keyStatsUsed: KeyStat[];
  confidence: number;
  /** Map of data-category -> ISO timestamp, e.g. { stats, projections, injuries }. */
  sourceTimestamps: Record<string, string>;
  missingDataWarning: string | null;
  createdAt: string;
}

/**
 * The grounded recommendation envelope returned by the recommendation
 * endpoints. It never invents stats — only stored data is cited.
 */
export interface GroundedRecommendation {
  recommendation: string;
  reasoning: string;
  keyStatsUsed: KeyStat[];
  confidence: number;
  sourceTimestamps: Record<string, string>;
  missingDataWarning: string | null;
}
