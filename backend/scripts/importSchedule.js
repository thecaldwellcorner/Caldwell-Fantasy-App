// Imports the NFL schedule for a season from nflverse into the `games` table.
// Usage: node importSchedule.js [season] [--dry-run]

import "dotenv/config";
import { parseArgs, makeLogger } from "./lib/cli.js";
import { getSupabase } from "./lib/supabase.js";
import { fetchSchedule, SOURCE } from "./lib/nflverse.js";
import { int } from "./lib/csv.js";
import { batchedUpsert, startSyncRun, finishSyncRun } from "./lib/upsert.js";

const log = makeLogger("schedule");

function kickoffISO(gameday, gametime) {
  if (!gameday) return null;
  // nfldata gametime is US Eastern. Use -05:00 (EST) as a documented approximation.
  if (!/^\d{1,2}:\d{2}$/.test(gametime || "")) return null;
  const date = new Date(`${gameday}T${gametime.padStart(5, "0")}:00-05:00`);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function toGameRow(r) {
  const homeScore = int(r.home_score);
  const awayScore = int(r.away_score);
  const played = homeScore !== null && awayScore !== null;
  return {
    provider_game_id: r.game_id,
    season: int(r.season),
    week: int(r.week),
    season_type: r.game_type || null,
    home_team: r.home_team || null,
    away_team: r.away_team || null,
    home_score: homeScore,
    away_score: awayScore,
    kickoff_at: kickoffISO(r.gameday, r.gametime),
    status: played ? "final" : "scheduled",
    venue: r.stadium || null,
    source: SOURCE,
    updated_at: new Date().toISOString(),
  };
}

async function main() {
  const { dryRun, season } = parseArgs();
  log(`Importing schedule for season ${season}${dryRun ? " (dry-run)" : ""}…`);

  const supabase = getSupabase({ required: !dryRun });

  const rows = (await fetchSchedule(season))
    .filter((r) => r.game_id)
    .map(toGameRow);
  log(`Fetched ${rows.length} games from nflverse.`);

  const runId = await startSyncRun(supabase, { syncType: "schedule", source: SOURCE, dryRun });
  try {
    const { upserted, errors } = await batchedUpsert(supabase, "games", rows, "provider_game_id", {
      dryRun,
      log,
    });
    log(`Done. Upserted: ${upserted}, Errors: ${errors}.`);
    await finishSyncRun(supabase, runId, {
      status: errors > 0 ? "completed_with_errors" : "success",
      rowsProcessed: upserted,
    });
    if (errors > 0) process.exitCode = 1;
  } catch (err) {
    await finishSyncRun(supabase, runId, { status: "failed", errorMessage: err.message });
    throw err;
  }
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
