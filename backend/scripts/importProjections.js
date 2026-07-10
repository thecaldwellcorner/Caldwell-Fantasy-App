// Imports player projections into `player_projections` from a LICENSED provider.
//
// Projections are never scraped or invented. Until a licensed provider is
// configured (PROJECTIONS_API_KEY + PROJECTIONS_SOURCE) with an implemented
// adapter, this script imports nothing and exits cleanly.
// Usage: node importProjections.js [season] [--dry-run]

import "./lib/loadEnv.js";
import { parseArgs, makeLogger, reportUnmatched } from "./lib/cli.js";
import { getSupabase } from "./lib/supabase.js";
import { getProjectionsProvider } from "./providers/projections.js";
import { buildPlayerIndex, matchPlayer } from "./lib/match.js";
import { batchedUpsert, startSyncRun, finishSyncRun } from "./lib/upsert.js";

const log = makeLogger("projections");

async function main() {
  const { dryRun, season } = parseArgs();
  const provider = getProjectionsProvider();

  if (!provider) {
    log(
      "No licensed projections provider configured (set PROJECTIONS_API_KEY + PROJECTIONS_SOURCE " +
        "and implement providers/projections.js). Projections are never invented — nothing imported.",
    );
    const supabase = getSupabase({ required: false });
    await finishSyncRun(
      supabase,
      await startSyncRun(supabase, { syncType: "projections", source: "none", dryRun }),
      { status: "skipped", rowsProcessed: 0, errorMessage: "no provider configured" },
    );
    return;
  }

  log(`Importing projections for season ${season} from "${provider.source}"${dryRun ? " (dry-run)" : ""}…`);
  const supabase = getSupabase({ required: !dryRun });
  const index = supabase ? await buildPlayerIndex(supabase) : null;

  const raw = await provider.fetchProjections(season);
  const rows = [];
  const unmatched = [];
  for (const p of raw) {
    const player = index ? matchPlayer(index, { name: p.name, position: p.position, team: p.team }) : null;
    if (!player) {
      unmatched.push({ name: p.name, position: p.position, team: p.team, providerId: p.providerPlayerId });
      continue;
    }
    rows.push({
      player_id: player.id,
      season: p.season ?? season,
      week: p.week ?? null,
      projected_points_ppr: p.projectedPointsPpr ?? null,
      projected_points_half_ppr: p.projectedPointsHalfPpr ?? null,
      projected_points_standard: p.projectedPointsStandard ?? null,
      floor: p.floor ?? null,
      ceiling: p.ceiling ?? null,
      confidence: p.confidence ?? null,
      projection_source: provider.source,
      model_version: p.modelVersion ?? null,
      updated_at: new Date().toISOString(),
    });
  }

  reportUnmatched(log, unmatched);
  const runId = await startSyncRun(supabase, { syncType: "projections", source: provider.source, dryRun });
  try {
    const { upserted, errors } = await batchedUpsert(
      supabase,
      "player_projections",
      rows,
      "player_id,season,week,projection_source",
      { dryRun, log },
    );
    log(`Done. Upserted: ${upserted}, Errors: ${errors}, Unmatched: ${unmatched.length}.`);
    await finishSyncRun(supabase, runId, {
      status: errors > 0 ? "completed_with_errors" : "success",
      rowsProcessed: upserted,
    });
  } catch (err) {
    await finishSyncRun(supabase, runId, { status: "failed", errorMessage: err.message });
    throw err;
  }
}

main().catch((err) => {
  console.error(`Fatal: ${err.message}`);
  process.exit(1);
});
