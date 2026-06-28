import type { InjuryStatus, Position } from "../types/playerMetrics.js";

/** Player identity + status from Sleeper's public `players` endpoint. */
export interface SleeperPlayer {
  playerId: string;
  fullName: string;
  position: Position | null;
  team: string | null;
  age: number | null;
  injuryStatus: InjuryStatus;
}

/**
 * Weekly usage row sourced from nflverse / nflfastR-style datasets. Field names
 * mirror the public nflverse player-stats schema so the loader maps 1:1.
 */
export interface NflverseWeeklyStat {
  playerId: string; // joined to Sleeper via gsis/sleeper id map
  playerName: string;
  position: Position | null;
  team: string | null;
  season: number;
  week: number;
  targets: number;
  receptions: number;
  receivingYards: number;
  receivingTds: number;
  receivingAirYards: number; // absolute intended (air) yards
  airYardsShare: number; // 0..1
  targetShare: number; // 0..1
  routes: number; // routes run (0 when unavailable)
  wopr: number; // weighted opportunity rating
  carries: number;
  rushingYards: number;
  rushingTds: number;
  offenseSnaps: number;
  teamOffenseSnaps: number;
  redZoneTouches: number;
  teamRedZonePlays: number;
  passingYards: number;
  passingTds: number;
  interceptions: number;
  fantasyPointsPpr: number;
}

/** Team-level offensive strength derived from EPA/play (nflfastR). */
export interface TeamEpaContext {
  team: string;
  season: number;
  offenseEpaPerPlay: number; // typically -0.2 .. 0.3
  defenseEpaPerPlayAllowed: number;
}
