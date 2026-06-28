import { config } from "../config.js";
import { getRepository } from "../db/index.js";
import { runIngestion } from "./ingestService.js";

async function main(): Promise<void> {
  const repo = getRepository();
  await repo.migrate();
  const weekArg = process.argv[2];
  const week = weekArg ? Number(weekArg) : undefined;

  // eslint-disable-next-line no-console
  console.log(`Ingesting season=${config.season}${week ? ` week=${week}` : ""} …`);
  const result = await runIngestion(repo, {
    season: config.season,
    week,
    sleeperBase: config.sleeperApiBase,
    nflverseBase: config.nflverseBase,
  });
  // eslint-disable-next-line no-console
  console.log(`Stored ${result.rows} player-metric rows.`);
  await repo.close();
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error("Ingestion failed:", err);
  process.exit(1);
});
