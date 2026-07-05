// Pulls NFL players from Sleeper and uploads them to Supabase.

import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function run() {
  // 1. Get all NFL players from Sleeper.
  const res = await fetch("https://api.sleeper.app/v1/players/nfl");
  const data = await res.json();

  // 2. Convert to the table format.
  const players = Object.entries(data).map(([id, p]) => ({
    sleeper_id: id,
    full_name: p.full_name || [p.first_name, p.last_name].filter(Boolean).join(" ") || null,
    first_name: p.first_name || null,
    last_name: p.last_name || null,
    team: p.team || null,
    position: p.position || null,
    age: p.age || null,
    height: p.height || null,
    weight: p.weight || null,
    active: Boolean(p.active),
    fantasy_positions: p.fantasy_positions || [],
    updated_at: new Date().toISOString(),
  }));

  console.log("Players fetched:", players.length);

  // 3. Upload to Supabase, 500 at a time.
  let synced = 0;
  let errors = 0;
  for (let i = 0; i < players.length; i += 500) {
    const batch = players.slice(i, i + 500);
    const { error } = await supabase.from("players").upsert(batch, { onConflict: "sleeper_id" });
    if (error) {
      errors += batch.length;
      console.error("Error on batch:", error.message);
    } else {
      synced += batch.length;
    }
  }

  console.log("Players synced:", synced);
  console.log("Errors:", errors);
}

run().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
