import type { PlayerMetrics } from "../types/playerMetrics.js";
import type { MetricsRepository } from "./repository.js";

/**
 * A small, realistic set of normalized metrics so the API and iOS client work
 * out of the box without a live ingestion run. In production these rows come
 * from the Sleeper + nflverse ingestion pipeline. season/week = 2024/0 (STD).
 */
const now = new Date().toISOString();

function row(p: Partial<PlayerMetrics> & Pick<PlayerMetrics, "playerId" | "name" | "position" | "team">): PlayerMetrics {
  return {
    age: null,
    season: 2024,
    week: 0,
    targetShare: 0,
    airYards: 0,
    routesRun: 0,
    snapShare: 0,
    redZoneUsage: 0,
    epaTeamContext: 50,
    matchupDifficulty: 50,
    injuryStatus: "Healthy",
    projectedPoints: 0,
    regressionScore: 50,
    breakoutScore: 50,
    confidenceScore: 60,
    updatedAt: now,
    ...p,
  };
}

export const seedMetrics: PlayerMetrics[] = [
  row({ playerId: "4046", name: "Ja'Marr Chase", position: "WR", team: "CIN", age: 24, targetShare: 0.30, airYards: 1320, routesRun: 340, snapShare: 0.90, redZoneUsage: 0.24, epaTeamContext: 72, matchupDifficulty: 42, projectedPoints: 20.1, regressionScore: 38, breakoutScore: 70, confidenceScore: 92 }),
  row({ playerId: "6794", name: "Amon-Ra St. Brown", position: "WR", team: "DET", age: 25, targetShare: 0.27, airYards: 980, routesRun: 330, snapShare: 0.89, redZoneUsage: 0.21, epaTeamContext: 80, matchupDifficulty: 48, projectedPoints: 18.0, regressionScore: 34, breakoutScore: 58, confidenceScore: 90 }),
  row({ playerId: "8138", name: "Bijan Robinson", position: "RB", team: "ATL", age: 22, targetShare: 0.14, airYards: 120, routesRun: 210, snapShare: 0.80, redZoneUsage: 0.28, epaTeamContext: 58, matchupDifficulty: 40, projectedPoints: 18.9, regressionScore: 28, breakoutScore: 80, confidenceScore: 88 }),
  row({ playerId: "8155", name: "Jahmyr Gibbs", position: "RB", team: "DET", age: 22, targetShare: 0.12, airYards: 90, routesRun: 180, snapShare: 0.60, redZoneUsage: 0.22, epaTeamContext: 80, matchupDifficulty: 46, projectedPoints: 17.8, regressionScore: 32, breakoutScore: 75, confidenceScore: 84 }),
  row({ playerId: "6904", name: "Josh Allen", position: "QB", team: "BUF", age: 28, snapShare: 0.99, projectedPoints: 24.8, epaTeamContext: 78, matchupDifficulty: 50, regressionScore: 30, breakoutScore: 40, confidenceScore: 95 }),
  row({ playerId: "11560", name: "Jayden Daniels", position: "QB", team: "WAS", age: 24, snapShare: 0.99, projectedPoints: 22.0, epaTeamContext: 64, matchupDifficulty: 52, regressionScore: 26, breakoutScore: 78, confidenceScore: 86 }),
  row({ playerId: "11604", name: "Brock Bowers", position: "TE", team: "LV", age: 22, targetShare: 0.23, airYards: 540, routesRun: 300, snapShare: 0.84, redZoneUsage: 0.16, epaTeamContext: 44, matchupDifficulty: 47, projectedPoints: 13.5, regressionScore: 30, breakoutScore: 82, confidenceScore: 83 }),
  row({ playerId: "6770", name: "Trey McBride", position: "TE", team: "ARI", age: 25, targetShare: 0.24, airYards: 460, routesRun: 305, snapShare: 0.86, redZoneUsage: 0.15, epaTeamContext: 56, matchupDifficulty: 45, projectedPoints: 13.0, regressionScore: 36, breakoutScore: 60, confidenceScore: 85 }),
  row({ playerId: "9226", name: "Puka Nacua", position: "WR", team: "LAR", age: 23, targetShare: 0.29, airYards: 760, routesRun: 250, snapShare: 0.87, redZoneUsage: 0.17, epaTeamContext: 54, matchupDifficulty: 44, projectedPoints: 16.6, regressionScore: 40, breakoutScore: 64, confidenceScore: 80 }),
  row({ playerId: "11631", name: "Malik Nabers", position: "WR", team: "NYG", age: 21, targetShare: 0.32, airYards: 1010, routesRun: 320, snapShare: 0.88, redZoneUsage: 0.14, epaTeamContext: 38, matchupDifficulty: 55, projectedPoints: 16.0, regressionScore: 35, breakoutScore: 85, confidenceScore: 82 }),
  row({ playerId: "5859", name: "Travis Etienne", position: "RB", team: "JAX", age: 25, targetShare: 0.11, airYards: 70, routesRun: 150, snapShare: 0.65, redZoneUsage: 0.17, epaTeamContext: 40, matchupDifficulty: 64, projectedPoints: 11.0, regressionScore: 58, breakoutScore: 40, confidenceScore: 74 }),
  row({ playerId: "4035", name: "Cooper Kupp", position: "WR", team: "LAR", age: 31, targetShare: 0.26, airYards: 640, routesRun: 200, snapShare: 0.80, redZoneUsage: 0.18, epaTeamContext: 54, matchupDifficulty: 50, projectedPoints: 13.5, regressionScore: 48, breakoutScore: 25, confidenceScore: 70, injuryStatus: "Questionable" }),
];

export async function seedIfEmpty(repo: MetricsRepository): Promise<number> {
  const existing = await repo.query({ season: 2024, week: 0, limit: 1 });
  if (existing.length > 0) return 0;
  return repo.upsertMany(seedMetrics);
}
