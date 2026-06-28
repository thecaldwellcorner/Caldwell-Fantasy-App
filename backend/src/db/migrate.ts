import { getRepository } from "./index.js";
import { config } from "../config.js";

async function main(): Promise<void> {
  const repo = getRepository();
  await repo.migrate();
  // eslint-disable-next-line no-console
  console.log(`Migrations applied (store=${config.dataStore}).`);
  await repo.close();
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});
