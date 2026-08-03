import type { InjuryDesignation, Position } from "../data/models.js";

/** Static, hand-authored base identities the mock adapters build on. */
export interface MockPlayerSeed {
  playerId: string;
  fullName: string;
  position: Position;
  team: string;
  age: number;
  jersey: number;
  /** Baseline weekly PPR output the mock generator centers usage/stats around. */
  baselinePpr: number;
  injury?: InjuryDesignation;
  injuryBodyPart?: string;
  /** When true, the mock provider intentionally omits projections (fallback demo). */
  omitProjection?: boolean;
}

export interface MockTeamSeed {
  teamId: string;
  name: string;
  conference: string;
  division: string;
  byeWeek: number;
}

export const MOCK_TEAMS: MockTeamSeed[] = [
  { teamId: "CIN", name: "Cincinnati Bengals", conference: "AFC", division: "North", byeWeek: 12 },
  { teamId: "DET", name: "Detroit Lions", conference: "NFC", division: "North", byeWeek: 5 },
  { teamId: "ATL", name: "Atlanta Falcons", conference: "NFC", division: "South", byeWeek: 12 },
  { teamId: "BUF", name: "Buffalo Bills", conference: "AFC", division: "East", byeWeek: 12 },
  { teamId: "WAS", name: "Washington Commanders", conference: "NFC", division: "East", byeWeek: 14 },
  { teamId: "LV", name: "Las Vegas Raiders", conference: "AFC", division: "West", byeWeek: 10 },
  { teamId: "ARI", name: "Arizona Cardinals", conference: "NFC", division: "West", byeWeek: 11 },
  { teamId: "LAR", name: "Los Angeles Rams", conference: "NFC", division: "West", byeWeek: 6 },
  { teamId: "NYG", name: "New York Giants", conference: "NFC", division: "East", byeWeek: 11 },
  { teamId: "JAX", name: "Jacksonville Jaguars", conference: "AFC", division: "South", byeWeek: 12 },
];

export const MOCK_PLAYERS: MockPlayerSeed[] = [
  { playerId: "4046", fullName: "Ja'Marr Chase", position: "WR", team: "CIN", age: 24, jersey: 1, baselinePpr: 20.1 },
  { playerId: "6794", fullName: "Amon-Ra St. Brown", position: "WR", team: "DET", age: 25, jersey: 14, baselinePpr: 18.0 },
  { playerId: "8138", fullName: "Bijan Robinson", position: "RB", team: "ATL", age: 22, jersey: 7, baselinePpr: 18.9 },
  { playerId: "8155", fullName: "Jahmyr Gibbs", position: "RB", team: "DET", age: 22, jersey: 26, baselinePpr: 17.8 },
  { playerId: "6904", fullName: "Josh Allen", position: "QB", team: "BUF", age: 28, jersey: 17, baselinePpr: 24.8 },
  { playerId: "11560", fullName: "Jayden Daniels", position: "QB", team: "WAS", age: 24, jersey: 5, baselinePpr: 22.0 },
  { playerId: "11604", fullName: "Brock Bowers", position: "TE", team: "LV", age: 22, jersey: 89, baselinePpr: 13.5 },
  { playerId: "6770", fullName: "Trey McBride", position: "TE", team: "ARI", age: 25, jersey: 85, baselinePpr: 13.0 },
  { playerId: "9226", fullName: "Puka Nacua", position: "WR", team: "LAR", age: 23, jersey: 17, baselinePpr: 16.6, injury: "Questionable", injuryBodyPart: "Knee" },
  { playerId: "11631", fullName: "Malik Nabers", position: "WR", team: "NYG", age: 21, jersey: 1, baselinePpr: 16.0 },
  { playerId: "5859", fullName: "Travis Etienne", position: "RB", team: "JAX", age: 25, jersey: 1, baselinePpr: 11.0 },
  { playerId: "4035", fullName: "Cooper Kupp", position: "WR", team: "LAR", age: 31, jersey: 10, baselinePpr: 13.5, injury: "Out", injuryBodyPart: "Ankle" },
  { playerId: "9509", fullName: "Sam LaPorta", position: "TE", team: "DET", age: 23, jersey: 87, baselinePpr: 11.8, omitProjection: true },
  { playerId: "7564", fullName: "Trevor Lawrence", position: "QB", team: "JAX", age: 25, jersey: 16, baselinePpr: 18.2 },
];

/** Mock league that references the players above so the app works end-to-end. */
export const MOCK_LEAGUE_ID = "mock-league-1";
