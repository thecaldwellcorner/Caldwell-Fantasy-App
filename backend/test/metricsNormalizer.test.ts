import { describe, it, expect } from "vitest";
import {
  normalize,
  epaToContextScore,
  epaToMatchupDifficulty,
  expectedFromOpportunity,
} from "../src/ingestion/metricsNormalizer.js";
import { buildMetrics } from "../src/ingestion/ingestService.js";
import type { NflverseWeeklyStat, SleeperPlayer } from "../src/datasources/types.js";
import { parseCsv } from "../src/datasources/csv.js";

function weekly(overrides: Partial<NflverseWeeklyStat>): NflverseWeeklyStat {
  return {
    playerId: "x",
    playerName: "Test Player",
    position: "WR",
    team: "CIN",
    season: 2024,
    week: 5,
    targets: 10,
    receptions: 7,
    receivingYards: 95,
    receivingTds: 1,
    receivingAirYards: 130,
    airYardsShare: 0.35,
    targetShare: 0.28,
    routes: 32,
    wopr: 0.6,
    carries: 0,
    rushingYards: 0,
    rushingTds: 0,
    offenseSnaps: 60,
    teamOffenseSnaps: 66,
    redZoneTouches: 3,
    teamRedZonePlays: 15,
    passingYards: 0,
    passingTds: 0,
    interceptions: 0,
    fantasyPointsPpr: 22.5,
    ...overrides,
  };
}

const player: SleeperPlayer = {
  playerId: "x",
  fullName: "Test Player",
  position: "WR",
  team: "CIN",
  age: 24,
  injuryStatus: "Healthy",
};

describe("metricsNormalizer", () => {
  it("maps usage fields and clamps shares to 0..1", () => {
    const m = normalize({ player, weekly: weekly({}) });
    expect(m.targetShare).toBeCloseTo(0.28, 3);
    expect(m.snapShare).toBeCloseTo(60 / 66, 2);
    expect(m.airYards).toBe(130);
    expect(m.redZoneUsage).toBeCloseTo(3 / 15, 3);
    expect(m.snapShare).toBeLessThanOrEqual(1);
  });

  it("produces all derived scores within 0..100", () => {
    const m = normalize({ player, weekly: weekly({}) });
    for (const s of [m.regressionScore, m.breakoutScore, m.confidenceScore]) {
      expect(s).toBeGreaterThanOrEqual(0);
      expect(s).toBeLessThanOrEqual(100);
    }
    expect(m.projectedPoints).toBeGreaterThan(0);
  });

  it("flags regression when realized far exceeds opportunity", () => {
    const efoLow = weekly({ targetShare: 0.1, airYardsShare: 0.1, fantasyPointsPpr: 28, receivingTds: 3 });
    const m = normalize({ player, weekly: efoLow });
    expect(m.regressionScore).toBeGreaterThan(60);
  });

  it("flags breakout for young player with big opportunity but modest output", () => {
    const w = weekly({ targetShare: 0.34, fantasyPointsPpr: 8, receivingTds: 0 });
    const young: SleeperPlayer = { ...player, age: 22 };
    const m = normalize({ player: young, weekly: w });
    expect(m.breakoutScore).toBeGreaterThan(60);
  });

  it("zeroes projection for players ruled out", () => {
    const out: SleeperPlayer = { ...player, injuryStatus: "Out" };
    const m = normalize({ player: out, weekly: weekly({}) });
    expect(m.projectedPoints).toBe(0);
  });

  it("EPA helpers map onto 0..100 and invert difficulty", () => {
    expect(epaToContextScore(0.3)).toBeGreaterThan(epaToContextScore(-0.1));
    // A defense allowing less EPA is a tougher matchup (higher difficulty).
    expect(epaToMatchupDifficulty(-0.15)).toBeGreaterThan(epaToMatchupDifficulty(0.15));
  });

  it("expectedFromOpportunity rewards higher usage", () => {
    const lo = expectedFromOpportunity("WR", weekly({ targetShare: 0.1, airYardsShare: 0.1 }));
    const hi = expectedFromOpportunity("WR", weekly({ targetShare: 0.35, airYardsShare: 0.4 }));
    expect(hi).toBeGreaterThan(lo);
  });

  it("joins nflverse rows to Sleeper identities by name fallback", () => {
    const players: SleeperPlayer[] = [
      { ...player, playerId: "sleeper-123", fullName: "Test Player" },
    ];
    const rows = [weekly({ playerId: "gsis-999", playerName: "Test Player" })];
    const metrics = buildMetrics(players, rows, []);
    expect(metrics).toHaveLength(1);
    expect(metrics[0]!.playerId).toBe("sleeper-123");
  });

  it("parses CSV with quoted fields and embedded commas", () => {
    const csv = 'name,team\n"Smith, Jr.",CIN\nDoe,DET\n';
    const rows = parseCsv(csv);
    expect(rows).toHaveLength(2);
    expect(rows[0]!.name).toBe("Smith, Jr.");
    expect(rows[1]!.team).toBe("DET");
  });
});
