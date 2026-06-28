/**
 * Canonical player metrics model for Caldwell Corner Fantasy Football.
 *
 * Metrics are sourced from trusted providers only (Sleeper public API and
 * nflverse / nflfastR-style datasets) and normalized into this shape before
 * being stored in the database and consumed by the RecommendationEngine.
 * The app never scrapes arbitrary websites.
 */

export type Position = "QB" | "RB" | "WR" | "TE" | "K" | "DEF";

export type InjuryStatus =
  | "Healthy"
  | "Questionable"
  | "Doubtful"
  | "Out"
  | "IR";

export interface PlayerMetrics {
  /** Stable player id (Sleeper player_id, also used as join key). */
  playerId: string;
  name: string;
  position: Position;
  team: string;
  age: number | null;

  /** Season + week these metrics describe. week=0 means season-to-date. */
  season: number;
  week: number;

  // ---- Usage / opportunity (per PRD §4 advanced metrics) ----
  /** Share of team targets, 0..1. */
  targetShare: number;
  /** Total air yards accrued (intended yards on targets). */
  airYards: number;
  /** Routes run (route participation proxy). */
  routesRun: number;
  /** Share of offensive snaps played, 0..1. */
  snapShare: number;
  /** Red zone usage rate (targets+carries inside the 20 / team RZ plays), 0..1. */
  redZoneUsage: number;

  // ---- Context ----
  /** Team offensive context derived from EPA/play (higher = better offense). 0..100. */
  epaTeamContext: number;
  /** Difficulty of upcoming matchup vs the player's position. 0 (easy)..100 (hard). */
  matchupDifficulty: number;
  injuryStatus: InjuryStatus;

  // ---- Outputs / derived scores ----
  /** Projected fantasy points (format-agnostic baseline; engine adjusts for scoring). */
  projectedPoints: number;
  /** Likelihood of negative regression from unsustainable production. 0..100. */
  regressionScore: number;
  /** Likelihood of a breakout / positive leap. 0..100. */
  breakoutScore: number;
  /** Confidence in the metrics themselves (data completeness + sample size). 0..100. */
  confidenceScore: number;

  /** ISO timestamp of last update. */
  updatedAt: string;

  // ---- Extended advanced analytics (optional; populated as the pipeline matures) ----
  targetsPerRouteRun?: number;
  yardsPerRouteRun?: number;
  routeParticipation?: number;   // 0..1
  airYardsShare?: number;        // 0..1
  firstReadShare?: number;       // 0..1
  redZoneTargets?: number;
  endZoneTargets?: number;
  rushShare?: number;            // 0..1
  goalLineShare?: number;        // 0..1
  explosivePlayRate?: number;    // 0..1
  missedTacklesForced?: number;
  yardsAfterContact?: number;
  expectedFantasyPoints?: number;
  fantasyPointsOverExpected?: number;
  teamPassRateOverExpected?: number; // PROE
  teamEPAperPlay?: number;
  offensiveLineRank?: number;    // 1..32
  impliedTeamTotal?: number;
  spread?: number;
  matchupEPAAllowed?: number;
  scheduleDifficulty?: number;   // 0..100

  /** Provenance / guardrail metadata. */
  dataLastUpdated?: string;
  dataSources?: string[];
  hasCurrentData?: boolean;
}

export type ScoringFormat = "ppr" | "half_ppr" | "standard";

export interface LeagueSettings {
  leagueId?: string;
  scoring: ScoringFormat;
  teamCount: number;
  superflex: boolean;
  /** Dynasty / keeper leagues weight youth and long-term value more heavily. */
  dynasty: boolean;
  /** Starting roster requirements, e.g. { QB: 1, RB: 2, WR: 2, TE: 1, FLEX: 1 }. */
  rosterSlots: Partial<Record<Position | "FLEX" | "SUPERFLEX", number>>;
  /** FAAB budget for waiver recommendations (defaults to 100). */
  faabBudget?: number;
}

export const DEFAULT_LEAGUE: LeagueSettings = {
  scoring: "ppr",
  teamCount: 12,
  superflex: false,
  dynasty: false,
  rosterSlots: { QB: 1, RB: 2, WR: 2, TE: 1, FLEX: 1 },
  faabBudget: 100,
};
