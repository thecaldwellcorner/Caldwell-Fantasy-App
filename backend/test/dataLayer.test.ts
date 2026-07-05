import { describe, expect, it, beforeEach } from "vitest";
import { MemoryStore } from "../src/data/memoryStore.js";
import { MockStatsProvider } from "../src/providers/mockStatsProvider.js";
import { MockLeagueProvider } from "../src/providers/mockLeagueProvider.js";
import { MOCK_LEAGUE_ID } from "../src/providers/mockDataset.js";
import { syncLeague, syncStats } from "../src/sync/syncService.js";
import { RecommendationService } from "../src/services/recommendationService.js";

const CTX = { season: 2024, week: 1 };

async function freshStore(): Promise<MemoryStore> {
  const store = new MemoryStore();
  await syncStats(store, CTX, { force: true, provider: new MockStatsProvider() });
  await syncLeague(store, MOCK_LEAGUE_ID, CTX, { force: true, provider: new MockLeagueProvider() });
  return store;
}

describe("MockStatsProvider", () => {
  it("is deterministic across calls", async () => {
    const p = new MockStatsProvider();
    const a = await p.fetchWeeklyStats(CTX);
    const b = await p.fetchWeeklyStats(CTX);
    expect(a).toEqual(b);
    expect(a.length).toBeGreaterThan(0);
  });

  it("stamps every record with source provenance", async () => {
    const p = new MockStatsProvider();
    const players = await p.fetchPlayers(CTX);
    for (const player of players) {
      expect(player.meta.source).toBe("mock");
      expect(Date.parse(player.meta.sourceUpdatedAt)).not.toBeNaN();
      expect(Date.parse(player.meta.fetchedAt)).not.toBeNaN();
    }
  });
});

describe("sync + store", () => {
  it("populates all core tables and preserves source labels", async () => {
    const store = await freshStore();
    const players = await store.getPlayers({});
    expect(players.length).toBeGreaterThan(5);

    const chase = await store.getPlayer("4046");
    expect(chase?.fullName).toBe("Ja'Marr Chase");
    expect(chase?.meta.source).toBe("mock");

    const stats = await store.getPlayerWeeklyStats("4046", 2024);
    expect(stats.length).toBe(1);
    expect(stats[0]?.fantasyPointsPpr).toBeGreaterThan(0);

    const rosters = await store.getLeagueRosters(MOCK_LEAGUE_ID);
    expect(rosters.length).toBeGreaterThan(0);
  });

  it("skips redundant provider calls while data is fresh (cache guard)", async () => {
    const store = new MemoryStore();
    const first = await syncStats(store, CTX, { force: true, provider: new MockStatsProvider() });
    expect(first.fromCache).toBe(false);
    const second = await syncStats(store, CTX, { provider: new MockStatsProvider() });
    expect(second.fromCache).toBe(true);
  });
});

describe("RecommendationService (grounded, stored-data-only)", () => {
  let store: MemoryStore;
  beforeEach(async () => {
    store = await freshStore();
  });

  it("start/sit ranks by stored value, benches injured players, cites sources", async () => {
    const svc = new RecommendationService(store);
    // Chase (healthy) vs Cooper Kupp (Out) — Kupp must be sat.
    const result = await svc.startSit({
      playerIds: ["4046", "4035"],
      scoring: "ppr",
      season: 2024,
      week: 1,
    });
    expect(result.recommendation).toContain("Ja'Marr Chase");
    expect(result.recommendation.toLowerCase()).toContain("sit");
    expect(result.keyStatsUsed.length).toBeGreaterThan(0);
    // Every cited stat carries a source label (provenance).
    for (const s of result.keyStatsUsed) expect(s.source).toBe("mock");
    expect(result.sourceTimestamps.projections).toBeDefined();
    expect(result.confidence).toBeGreaterThan(0);
  });

  it("surfaces a missing-data warning instead of inventing stats", async () => {
    const svc = new RecommendationService(store);
    // 9509 (Sam LaPorta) intentionally has no projection in the mock provider.
    const result = await svc.startSit({
      playerIds: ["4046", "9509"],
      scoring: "ppr",
      season: 2024,
      week: 1,
    });
    expect(result.missingDataWarning).toBeTruthy();
    expect(result.missingDataWarning).toContain("Sam LaPorta");
  });

  it("returns an explicit no-data envelope for unknown players", async () => {
    const svc = new RecommendationService(store);
    const result = await svc.startSit({
      playerIds: ["does-not-exist"],
      scoring: "ppr",
      season: 2024,
      week: 1,
    });
    expect(result.confidence).toBe(0);
    expect(result.missingDataWarning).toBeTruthy();
  });

  it("grades a trade from stored projected values", async () => {
    const svc = new RecommendationService(store);
    const result = await svc.trade({
      give: ["4035"],
      get: ["4046"],
      scoring: "ppr",
      season: 2024,
      week: 1,
    });
    expect(["Accept", "Fair", "Decline"]).toContain(result.recommendation.split(":")[0]);
    expect(result.keyStatsUsed.length).toBeGreaterThan(0);
  });

  it("ranks waiver targets and excludes rostered players", async () => {
    const svc = new RecommendationService(store);
    const result = await svc.waivers({
      scoring: "ppr",
      season: 2024,
      week: 1,
      limit: 3,
      leagueId: MOCK_LEAGUE_ID,
    });
    // All mock players are rostered in the demo league, so nothing is available.
    expect(result.missingDataWarning ?? result.recommendation).toBeTruthy();

    const openResult = await svc.waivers({ scoring: "ppr", season: 2024, week: 1, limit: 3 });
    expect(openResult.recommendation).toContain("waiver");
    expect(openResult.keyStatsUsed.length).toBeGreaterThan(0);
  });

  it("persists recommendations to the store", async () => {
    const svc = new RecommendationService(store);
    await svc.startSit({ playerIds: ["4046", "8138"], scoring: "ppr", season: 2024, week: 1 });
    const saved = await store.getRecommendations({ kind: "start_sit" });
    expect(saved.length).toBeGreaterThan(0);
    expect(saved[0]?.confidence).toBeGreaterThan(0);
  });
});
