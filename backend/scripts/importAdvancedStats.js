// Imports advanced usage metrics for a season from nflverse into
// `player_advanced_stats`. nflverse's weekly file provides target_share and
// air_yards_share; metrics it does not expose per player (epa_per_play,
// success_rate, route_participation, yards_per_route_run, expected fantasy
// points, FPOE) are left NULL rather than invented, and can be backfilled later
// from additional nflverse datasets (nextgen/ftn) behind the same adapter.
// Usage: node importAdvancedStats.js [season] [--dry-run]

import "./lib/loadEnv.js";
import { parseArgs, makeLogger, reportUnmatched } from "./lib/cli.js";
import { getSupabase } from "./lib/supabase.js";
import { fetchAdvancedStats, SOURCE } from "./lib/nflverse.js";
import { num } from "./lib/csv.js";
import { buildPlayerIndex, matchPlayer } from "./lib/match.js";
import { batchedUpsert, startSyncRun, finishSyncRun } from "./lib/upsert.js";

const log = makeLogger("advanced");

async function main() {
  const { dryRun, season } = parseArgs();
  log(`Importing advanced stats for season ${season}${dryRun ? " (dry-run)" : ""}…`);

  const supabase = getSupabase({ required: !dryRun });

  const raw = await fetchAdvancedStats(season);
  log(`Fetched ${raw.length} rows from nflverse.`);

  if (!supabase) {
    log("No Supabase credentials — dry-run will not match players or write.");
    log(`[dry-run] would attempt to upsert up to ${raw.length} rows into player_advanced_stats.`);
    return;
  }

  log("Building player index from Supabase…");
  const index = await buildPlayerIndex(supabase);

  const rows = [];
  const unmatched = [];
  for (const r of raw) {
    // Only keep rows that actually carry an advanced usage signal.
    const targetShare = num(r.target_share);
    const airYardsShare = num(r.air_yards_share);
    if (targetShare === null && airYardsShare === null) continue;

    const name = r.player_display_name || r.player_name;
    const player = matchPlayer(index, { name, position: r.position, team: r.recent_team });
    if (!player) {
      unmatched.push({ name, position: r.position, team: r.recent_team, providerId: r.player_id });
      continue;
    }
    rows.push({
      player_id: player.id,
      season: num(r.season),
      week: num(r.week),
      epa_per_play: null, // not provided per-player by this dataset
      success_rate: null,
      target_share: targetShare,
      air_yards_share: airYardsShare,
      route_participation: null,
      yards_per_route_run: null,
      expected_fantasy_points: null,
      fantasy_points_over_expected: null,
      source: SOURCE,
      updated_at: new Date().toISOString(),
    });
  }

  log(`Matched ${rows.length} rows; ${unmatched.length} unmatched.`);
  reportUnmatched(log, unmatched);

  const runId = await startSyncRun(supabase, { syncType: "advanced_stats", source: SOURCE, dryRun });
  try {
    const { upserted, errors } = await batchedUpsert(
      supabase,
      "player_advanced_stats",
      rows,
      "player_id,season,week,source",
      { dryRun, log },
    );
    log(`Done. Upserted: ${upserted}, Errors: ${errors}, Unmatched: ${unmatched.length}.`);
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
