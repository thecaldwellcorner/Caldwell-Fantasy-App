# Import NFL players into Supabase

`importPlayers.js` fetches every NFL player from Sleeper and upserts them into
your Supabase `players` table (unique key: `sleeper_id`).

Your `players` table needs a `sleeper_id` column that is the primary key (or has
a unique constraint). See [`players_table.sql`](./players_table.sql) if you need it.

## Terminal commands

```bash
cd backend/scripts
cp .env.example .env        # then open .env and paste in your two values
npm install
node importPlayers.js
```

Get `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from **Supabase → Project
Settings → API**. Keep the service role key private — never put it in the iOS app.

Tested with Node.js v22 (uses the built-in `fetch`).
