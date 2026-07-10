// Loads the .env that lives in the scripts directory, regardless of the current
// working directory. (`import "dotenv/config"` only looks in process.cwd(), so
// running e.g. `node backend/scripts/importSchedule.js` from the repo root would
// miss backend/scripts/.env.) Existing environment variables are not overridden.

import { config } from "dotenv";
import { fileURLToPath } from "node:url";
import path from "node:path";

const scriptsDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
config({ path: path.join(scriptsDir, ".env") });
