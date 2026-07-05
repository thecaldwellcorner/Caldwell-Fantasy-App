# Sleeper → Supabase player sync

`syncSleeperPlayers.js` fetches the full NFL player catalog from the free
[Sleeper API](https://docs.sleeper.com/) and upserts it into a Supabase
`players` table. It's a standalone Node script meant to run on the server (or on
a schedule), never in the app.

## What it does

1. Fetches all players from `https://api.sleeper.app/v1/players/nfl`.
2. Normalizes each player to:
   `sleeper_id, full_name, first_name, last_name, team, position, age, height,
   weight, active, fantasy_positions, updated_at`.
3. Connects to Supabase with `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`.
4. Upserts in batches of **500** using `sleeper_id` as the conflict key.
5. Logs total fetched, total synced, and any errors.

## Prerequisites

- **Node.js 18+** (uses the built-in `fetch`).
- A Supabase project with a `players` table. Create it once by running
  [`players_table.sql`](./players_table.sql) in the Supabase SQL editor
  (`sleeper_id` is the primary key / upsert conflict target).

## Configure

Copy the example env file and fill in your project's values (from
**Supabase → Project Settings → API**):

```bash
cp .env.example .env
# edit .env:
# SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
# SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

You can also export them as environment variables instead of using a `.env` file.

## Run

```bash
npm install
node syncSleeperPlayers.js
```

Example output:

```
Fetching NFL players from Sleeper: https://api.sleeper.app/v1/players/nfl
Total players fetched: 11342
Upserting 11342 players in 23 batch(es) of 500…
  Batch 1/23 ok — 500/11342 synced
  ...
──────────── Sync summary ────────────
Total players fetched: 11342
Total players synced:  11342
Errors:                0
Elapsed:               6.8s
──────────────────────────────────────
```

### Dry run (no writes)

Verify the fetch + transform without touching Supabase (no keys required):

```bash
npm install
node syncSleeperPlayers.js --dry-run
```

## Scheduling

Run it on a cron / scheduled job (e.g. daily). For example, a crontab entry:

```cron
# 6:00 AM daily
0 6 * * * cd /path/to/backend/scripts && node syncSleeperPlayers.js >> sync.log 2>&1
```

## Security

`SUPABASE_SERVICE_ROLE_KEY` bypasses Row Level Security and grants full database
access. **Never** embed it in the iOS/Xcode app or any client. It lives only on
the server / in CI secrets. The app should read player data through your backend
API, not directly from Supabase with this key.
