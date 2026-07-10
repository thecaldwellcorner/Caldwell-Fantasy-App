// Imports player images into `player_images` from a LICENSED provider.
//
// Player images have licensing requirements, so we do NOT auto-import image URLs
// from open datasets. Until a licensed image provider is configured
// (IMAGES_API_KEY + IMAGES_PROVIDER) with an implemented adapter, this script
// imports nothing and exits cleanly. Images are never invented.
// Usage: node importPlayerImages.js [--dry-run]

import "./lib/loadEnv.js";
import { parseArgs, makeLogger, reportUnmatched } from "./lib/cli.js";
import { getSupabase } from "./lib/supabase.js";
import { getImagesProvider } from "./providers/images.js";
import { buildPlayerIndex, matchPlayer } from "./lib/match.js";
import { batchedUpsert, startSyncRun, finishSyncRun } from "./lib/upsert.js";

const log = makeLogger("images");

async function main() {
  const { dryRun } = parseArgs();
  const provider = getImagesProvider();

  if (!provider) {
    log(
      "No licensed image provider configured (set IMAGES_API_KEY + IMAGES_PROVIDER and implement " +
        "providers/images.js). Images are never scraped or invented — nothing imported.",
    );
    const supabase = getSupabase({ required: false });
    await finishSyncRun(
      supabase,
      await startSyncRun(supabase, { syncType: "images", source: "none", dryRun }),
      { status: "skipped", rowsProcessed: 0, errorMessage: "no provider configured" },
    );
    return;
  }

  log(`Importing player images from "${provider.source}"${dryRun ? " (dry-run)" : ""}…`);
  const supabase = getSupabase({ required: !dryRun });
  const index = supabase ? await buildPlayerIndex(supabase) : null;

  const raw = await provider.fetchImages();
  const rows = [];
  const unmatched = [];
  for (const img of raw) {
    const player = index ? matchPlayer(index, { name: img.name, position: img.position, team: img.team }) : null;
    if (!player) {
      unmatched.push({ name: img.name, position: img.position, team: img.team, providerId: img.providerPlayerId });
      continue;
    }
    rows.push({
      player_id: player.id,
      image_url: img.imageUrl,
      image_type: img.imageType ?? "headshot",
      provider: provider.source,
      license_reference: img.licenseReference ?? null,
      updated_at: new Date().toISOString(),
    });
  }

  reportUnmatched(log, unmatched);
  const runId = await startSyncRun(supabase, { syncType: "images", source: provider.source, dryRun });
  try {
    const { upserted, errors } = await batchedUpsert(
      supabase,
      "player_images",
      rows,
      "player_id,image_type",
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
