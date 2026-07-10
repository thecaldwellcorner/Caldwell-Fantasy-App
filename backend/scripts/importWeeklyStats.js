// Imports weekly player box-score stats for a season from nflverse into
// `player_weekly_stats`, matching players to our Supabase players table.
// Usage: node importWeeklyStats.js [season] [--dry-run]

import "./lib/loadEnv.js";
import { parseArgs, makeLogger, reportUnmatched } from "./lib/cli.js";
import { getSupabase } from "./lib/supabase.js";
import { fetchWeeklyStats, SOURCE } from "./lib/nflverse.js";
import { num } from "./lib/csv.js";
import { buildPlayerIndex, matchPlayer } from "./lib/match.js";
import { batchedUpsert, startSyncRun, finishSyncRun } from "./lib/upsert.js";

const log = makeLogger("weekly");

function fumblesLost(r) {
  const parts = [num(r.sack_fumbles_lost), num(r.rushing_fumbles_lost), num(r.receiving_fumbles_lost)];
  const present = parts.filter((p) => p !== null);
  return present.length ? present.reduce((a, b) => a + b, 0) : null;
}

async function main() {
  const { dryRun, season } = parseArgs();
  log(`Importing weekly stats for season ${season}${dryRun ? " (dry-run)" : ""}…`);

  const supabase = getSupabase({ required: !dryRun });

  const raw = await fetchWeeklyStats(season);
  log(`Fetched ${raw.length} weekly stat rows from nflverse.`);

  if (!supabase) {
    log("No Supabase credentials — dry-run will not match players or write. Set keys to enable matching.");
    log(`[dry-run] would attempt to upsert up to ${raw.length} rows into player_weekly_stats.`);
    return;
  }

  log("Building player index from Supabase…");
  const index = await buildPlayerIndex(supabase);

  const rows = [];
  const unmatched = [];
  for (const r of raw) {
    const name = r.player_display_name || r.player_name;
    const player = matchPlayer(index, { name, position: r.position, team: r.recent_team });
    if (!player) {
      unmatched.push({ name, position: r.position, team: r.recent_team, providerId: r.player_id });
      continue;
    }
    const receptions = num(r.receptions);
    const standard = num(r.fantasy_points);
    const halfPpr =
      standard !== null && receptions !== null ? standard + 0.5 * receptions : null;
    rows.push({
      player_id: player.id,
      provider_player_id: r.player_id || null,
      season: num(r.season),
      week: num(r.week),
      team: r.recent_team || null,
      opponent: r.opponent_team || null,
      passing_yards: num(r.passing_yards),
      passing_touchdowns: num(r.passing_tds),
      interceptions: num(r.interceptions),
      rushing_attempts: num(r.carries),
      rushing_yards: num(r.rushing_yards),
      rushing_touchdowns: num(r.rushing_tds),
      targets: num(r.targets),
      receptions,
      receiving_yards: num(r.receiving_yards),
      receiving_touchdowns: num(r.receiving_tds),
      fumbles_lost: fumblesLost(r),
      fantasy_points_ppr: num(r.fantasy_points_ppr),
      fantasy_points_half_ppr: halfPpr,
      fantasy_points_standard: standard,
      source: SOURCE,
      updated_at: new Date().toISOString(),
    });
  }

  log(`Matched ${rows.length} rows; ${unmatched.length} unmatched.`);
  reportUnmatched(log, unmatched);

  const runId = await startSyncRun(supabase, { syncType: "weekly_stats", source: SOURCE, dryRun });
  try {
    const { upserted, errors } = await batchedUpsert(
      supabase,
      "player_weekly_stats",
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
