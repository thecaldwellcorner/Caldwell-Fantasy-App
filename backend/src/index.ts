import express from "express";
import { config } from "./config.js";
import { getRepository } from "./db/index.js";
import { seedIfEmpty } from "./db/seed.js";
import { buildRouter } from "./api/routes.js";
import { getDataStore } from "./data/storeFactory.js";
import { buildDataRouter } from "./api/dataRoutes.js";
import { MOCK_LEAGUE_ID } from "./providers/mockDataset.js";
import { defaultContext, syncLeague, syncStats } from "./sync/syncService.js";

async function main(): Promise<void> {
  // New normalized data layer (players/teams/games/stats/projections/injuries/leagues).
  const store = getDataStore();
  await store.migrate();

  // Populate the store on boot so the API is useful immediately. With the mock
  // provider this seeds realistic data; with a live provider it does a first pull.
  const ctx = defaultContext();
  const statsSync = await syncStats(store, ctx, { force: true });
  await syncLeague(store, MOCK_LEAGUE_ID, ctx, { force: true });
  // eslint-disable-next-line no-console
  console.log(
    `Data layer ready (store=${config.dataStore}, statsProvider=${config.statsProvider}, ` +
      `leagueProvider=${config.leagueProvider}): ${JSON.stringify(statsSync.counts)}`,
  );

  // Legacy PlayerMetrics engine (kept for continuity of the existing pipeline).
  const repo = getRepository();
  await repo.migrate();
  if (config.dataStore === "memory") {
    const n = await seedIfEmpty(repo);
    if (n > 0) console.log(`Seeded ${n} legacy player-metric rows (memory store).`); // eslint-disable-line no-console
  }

  const app = express();
  app.use(express.json({ limit: "1mb" }));
  app.use("/api", buildDataRouter(store));
  app.use("/api/legacy", buildRouter(repo));

  app.get("/", (_req, res) => {
    res.json({
      service: "Caldwell IQ — Fantasy Data Layer",
      docs: "/api/health",
      dataStore: config.dataStore,
      statsProvider: config.statsProvider,
      leagueProvider: config.leagueProvider,
    });
  });

  app.listen(config.port, () => {
    // eslint-disable-next-line no-console
    console.log(`Backend listening on http://localhost:${config.port} (store=${config.dataStore})`);
  });
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("Fatal:", err);
  process.exit(1);
});
