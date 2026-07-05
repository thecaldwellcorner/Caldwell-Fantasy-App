# Sync NFL players into Supabase

## Step 1 — create the table

In Supabase, open the **SQL Editor**, paste the contents of
[`players_table.sql`](./players_table.sql), and click **Run**.

## Step 2 — run these 3 terminal commands

Replace the two values with your own from **Supabase → Project Settings → API**.

```bash
cd backend/scripts
npm install
SUPABASE_URL="https://YOUR_PROJECT.supabase.co" SUPABASE_SERVICE_ROLE_KEY="YOUR_SERVICE_ROLE_KEY" node syncSleeperPlayers.js
```

That's it. You'll see how many players were fetched and synced.

> Keep the service role key on your computer/server only. Never put it in the iOS app.
