import { describe, it, expect } from "vitest";
import { RecommendationEngine } from "../src/engine/recommendationEngine.js";
import { DEFAULT_LEAGUE, type LeagueSettings, type PlayerMetrics } from "../src/types/playerMetrics.js";
import { seedMetrics } from "../src/db/seed.js";

const byName = (name: string): PlayerMetrics =>
  seedMetrics.find((m) => m.name === name)!;

const league: LeagueSettings = { ...DEFAULT_LEAGUE };

describe("RecommendationEngine", () => {
  it("start/sit returns score, confidence and reasoning for each player", () => {
    const recs = new RecommendationEngine(league).startSit([
      byName("Ja'Marr Chase"),
      byName("Travis Etienne"),
      byName("Cooper Kupp"),
    ]);
    expect(recs).toHaveLength(3);
    for (const r of recs) {
      expect(r.score).toBeGreaterThanOrEqual(0);
      expect(r.score).toBeLessThanOrEqual(100);
      expect(r.confidence).toBeGreaterThanOrEqual(0);
      expect(r.confidence).toBeLessThanOrEqual(100);
      expect(r.reasoning.length).toBeGreaterThan(10);
      expect(["Start", "Flex", "Sit"]).toContain(r.verdict);
    }
    // The elite WR should outrank the touchdown-dependent RB.
    expect(recs[0]!.name).toBe("Ja'Marr Chase");
    expect(recs[0]!.verdict).toBe("Start");
  });

  it("sits a player who is ruled out regardless of talent", () => {
    const out: PlayerMetrics = { ...byName("Ja'Marr Chase"), injuryStatus: "Out", projectedPoints: 0 };
    const [rec] = new RecommendationEngine(league).startSit([out]);
    expect(rec!.verdict).toBe("Sit");
    expect(rec!.reasoning.toLowerCase()).toContain("out");
  });

  it("waiver ranks by emerging opportunity and assigns FAAB bids", () => {
    const recs = new RecommendationEngine(league).waiver(seedMetrics);
    expect(recs[0]!.priority).toBe(1);
    expect(recs[0]!.faabBidPct).toBeGreaterThanOrEqual(recs[recs.length - 1]!.faabBidPct);
    for (const r of recs) {
      expect(r.faabBidPct).toBeGreaterThanOrEqual(0);
      expect(r.faabBidPct).toBeLessThanOrEqual(100);
    }
  });

  it("draft ranks by value over replacement", () => {
    const recs = new RecommendationEngine(league).draft(seedMetrics);
    const vors = recs.map((r) => r.valueOverReplacement);
    const sorted = [...vors].sort((a, b) => b - a);
    expect(vors).toEqual(sorted);
    expect(recs[0]!.reasoning).toContain("value over a replacement");
  });

  it("superflex meaningfully raises QB draft value", () => {
    const std = new RecommendationEngine({ ...league, superflex: false }).draft(seedMetrics);
    const sf = new RecommendationEngine({ ...league, superflex: true }).draft(seedMetrics);
    const qbRankStd = std.findIndex((r) => r.position === "QB");
    const qbRankSf = sf.findIndex((r) => r.position === "QB");
    expect(qbRankSf).toBeLessThanOrEqual(qbRankStd);
  });

  it("trade grades a clearly lopsided deal as a win and flags fairness", () => {
    const engine = new RecommendationEngine(league);
    const rec = engine.trade([byName("Travis Etienne")], [byName("Ja'Marr Chase")]);
    expect(rec.sideBValue).toBeGreaterThan(rec.sideAValue);
    expect(rec.tradeGrade).toBeGreaterThan(55);
    expect(rec.verdict).toBe("Accept");
    expect(rec.fairnessScore).toBeLessThan(100);
    expect(["Low", "Medium", "High"]).toContain(rec.riskRating);
    expect(rec.reasoning).toContain("Chase");
  });

  it("an even trade is graded close to fair", () => {
    const engine = new RecommendationEngine(league);
    const rec = engine.trade([byName("Amon-Ra St. Brown")], [byName("Puka Nacua")]);
    expect(rec.fairnessScore).toBeGreaterThan(70);
  });

  it("dynasty weighting favors the younger breakout asset", () => {
    const dynasty = new RecommendationEngine({ ...league, dynasty: true });
    // Malik Nabers (21, high breakout) vs Cooper Kupp (31, low breakout)
    const rec = dynasty.trade([byName("Cooper Kupp")], [byName("Malik Nabers")]);
    expect(rec.futureScore).toBeGreaterThan(rec.winNowScore);
    expect(rec.tradeGrade).toBeGreaterThan(50);
  });
});
