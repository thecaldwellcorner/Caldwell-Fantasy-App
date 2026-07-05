// syncSleeperPlayers.js
//
// Automatic data sync: pulls the full NFL player catalog from the Sleeper public
// API and upserts it into the Supabase `players` table (conflict key: sleeper_id).
//
// Run:   npm install && node syncSleeperPlayers.js
// Test:  node syncSleeperPlayers.js --dry-run   (fetch + transform only, no writes)
//
// SECURITY: this uses the Supabase SERVICE ROLE key, which bypasses Row Level
// Security. It must ONLY ever run on the server / trusted backend. Never ship
// the service role key (or this script) inside the iOS/Xcode app — the app talks
// to our own backend endpoints, never to Supabase directly.

import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const SLEEPER_PLAYERS_URL = "https://api.sleeper.app/v1/players/nfl";
const BATCH_SIZE = 500;

const DRY_RUN = process.argv.includes("--dry-run") || process.env.DRY_RUN === "1";

/** Normalize one raw Sleeper player into our `players` row shape. */
function toPlayerRow(sleeperId, p) {
  const first = p.first_name ?? null;
  const last = p.last_name ?? null;
  const fullName = p.full_name ?? [first, last].filter(Boolean).join(" ") ?? null;
  const age = typeof p.age === "number" ? p.age : p.age ? Number(p.age) : null;

  return {
    sleeper_id: sleeperId,
    full_name: fullName || null,
    first_name: first,
    last_name: last,
    team: p.team ?? null,
    position: p.position ?? null,
    age: Number.isFinite(age) ? age : null,
    height: p.height ?? null,
    weight: p.weight ?? null,
    active: Boolean(p.active),
    fantasy_positions: Array.isArray(p.fantasy_positions) ? p.fantasy_positions : [],
    updated_at: new Date().toISOString(),
  };
}

async function fetchSleeperPlayers() {
  console.log(`Fetching NFL players from Sleeper: ${SLEEPER_PLAYERS_URL}`);
  const res = await fetch(SLEEPER_PLAYERS_URL);
  if (!res.ok) {
    throw new Error(`Sleeper API request failed: ${res.status} ${res.statusText}`);
  }
  const raw = await res.json();
  const rows = Object.entries(raw).map(([id, player]) => toPlayerRow(id, player));
  console.log(`Total players fetched: ${rows.length}`);
  return rows;
}

function getSupabaseClient() {
  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    throw new Error(
      "Missing SUPABASE_URL and/or SUPABASE_SERVICE_ROLE_KEY. Set them as environment " +
        "variables (or in a .env file) before running. See README.md.",
    );
  }
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

async function main() {
  const startedAt = Date.now();

  // Fail fast on missing config (unless we're only doing a dry run).
  const supabase = DRY_RUN ? null : getSupabaseClient();

  const rows = await fetchSleeperPlayers();

  if (DRY_RUN) {
    console.log("Dry run — no data written. Sample normalized row:");
    console.log(JSON.stringify(rows[0], null, 2));
    console.log(`\nDone (dry run). Would have synced ${rows.length} players.`);
    return;
  }

  const totalBatches = Math.ceil(rows.length / BATCH_SIZE);
  let synced = 0;
  let errorCount = 0;

  console.log(`Upserting ${rows.length} players in ${totalBatches} batch(es) of ${BATCH_SIZE}…`);

  for (let i = 0; i < rows.length; i += BATCH_SIZE) {
    const batch = rows.slice(i, i + BATCH_SIZE);
    const batchNumber = Math.floor(i / BATCH_SIZE) + 1;

    const { error } = await supabase
      .from("players")
      .upsert(batch, { onConflict: "sleeper_id", ignoreDuplicates: false });

    if (error) {
      errorCount += batch.length;
      console.error(`  Batch ${batchNumber}/${totalBatches} FAILED: ${error.message}`);
    } else {
      synced += batch.length;
      console.log(`  Batch ${batchNumber}/${totalBatches} ok — ${synced}/${rows.length} synced`);
    }
  }

  const seconds = ((Date.now() - startedAt) / 1000).toFixed(1);
  console.log("\n──────────── Sync summary ────────────");
  console.log(`Total players fetched: ${rows.length}`);
  console.log(`Total players synced:  ${synced}`);
  console.log(`Errors:                ${errorCount}`);
  console.log(`Elapsed:               ${seconds}s`);
  console.log("──────────────────────────────────────");

  if (errorCount > 0) process.exitCode = 1;
}

main().catch((err) => {
  console.error(`Fatal: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
