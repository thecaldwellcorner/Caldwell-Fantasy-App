// Imports all NFL players from Sleeper into your Supabase `players` table.
// Loads SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY from a .env file.

import "./lib/loadEnv.js";
import { createClient } from "@supabase/supabase-js";

const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error(
    "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.\n" +
      "Copy .env.example to .env and fill in your values.",
  );
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

async function importPlayers() {
  // 1. Fetch every NFL player from Sleeper.
  console.log("Fetching players from Sleeper...");
  const res = await fetch("https://api.sleeper.app/v1/players/nfl");
  if (!res.ok) throw new Error(`Sleeper request failed: ${res.status} ${res.statusText}`);
  const data = await res.json();

  // 2. Convert to the players table format.
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

  console.log(`Fetched ${players.length} players. Uploading to Supabase...`);

  // 3. Upsert into Supabase, 500 at a time, using sleeper_id as the unique key.
  let imported = 0;
  for (let i = 0; i < players.length; i += 500) {
    const batch = players.slice(i, i + 500);
    const { error } = await supabase.from("players").upsert(batch, { onConflict: "sleeper_id" });
    if (error) throw new Error(`Upsert failed: ${error.message}`);
    imported += batch.length;
    console.log(`Uploaded ${imported}/${players.length}`);
  }

  console.log(`Done. Imported ${imported} players.`);
}

importPlayers().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
