import express from "express";
import { config } from "./config.js";
import { getRepository } from "./db/index.js";
import { seedIfEmpty } from "./db/seed.js";
import { buildRouter } from "./api/routes.js";

async function main(): Promise<void> {
  const repo = getRepository();
  await repo.migrate();

  // Seed the in-memory store so the API is useful without a live ingestion run.
  if (config.dataStore === "memory") {
    const n = await seedIfEmpty(repo);
    if (n > 0) {
      // eslint-disable-next-line no-console
      console.log(`Seeded ${n} sample player-metric rows (memory store).`);
    }
  }

  const app = express();
  app.use(express.json({ limit: "1mb" }));
  app.use("/api", buildRouter(repo));

  app.get("/", (_req, res) => {
    res.json({
      service: "Caldwell Corner Fantasy Football — Backend",
      docs: "/api/health",
      dataStore: config.dataStore,
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
