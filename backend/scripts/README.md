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

---

# Data layer (games, weekly stats, advanced stats, projections, images)

Provider-adapter based imports for the Caldwell IQ data layer. Data comes from
**nflverse's public, downloadable datasets** (open data) and licensed provider
adapters — **never** by scraping ESPN, NFL.com, Yahoo, FantasyPros, PFF, etc.

| Script | Source | Table | Notes |
|---|---|---|---|
| `importSchedule.js` | nflverse (nfldata) | `games` | Season schedule + scores |
| `importWeeklyStats.js` | nflverse | `player_weekly_stats` | Box scores, matched to `players` |
| `importAdvancedStats.js` | nflverse | `player_advanced_stats` | `target_share`, `air_yards_share` (others NULL until wired) |
| `importProjections.js` | licensed adapter | `player_projections` | No-op until a provider is configured |
| `importPlayerImages.js` | licensed adapter | `player_images` | No-op until a provider is configured |

## 1. Run the migration

In Supabase → SQL Editor, run [`migrations/001_data_layer.sql`](./migrations/001_data_layer.sql).
It creates the six tables, adds a uuid `id` to `players` (for foreign keys),
and adds read policies for the `anon` role (the app reads with the publishable
key; writes happen only from these server-side scripts).

## 2. Configure

```bash
cd backend/scripts
cp .env.example .env        # set SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY (+ optional SEASON)
npm install
```

## 3. Import (exact commands)

```bash
# Dry-run first — reports what WOULD be inserted, writes nothing:
node importSchedule.js 2024 --dry-run
node importWeeklyStats.js 2024 --dry-run
node importAdvancedStats.js 2024 --dry-run

# Real imports (upserts in batches of 500, logs progress + unmatched players):
node importSchedule.js 2024
node importWeeklyStats.js 2024
node importAdvancedStats.js 2024

# Projections & images: no-ops until a licensed provider is configured.
node importProjections.js 2024
node importPlayerImages.js
```

(Season can also come from `SEASON` in `.env`, or `--season 2024`. npm aliases
exist too: `npm run import:schedule -- 2024 --dry-run`, etc.)

## How it works

- **Provider adapters** (`lib/nflverse.js`, `providers/*.js`) isolate every
  source so it can be swapped later. nflverse release-asset URLs are centralized
  and each fetch falls back across known-good URL patterns.
- **Player matching**: nflverse uses GSIS ids + names; our `players` table is
  keyed by `sleeper_id`. We match on normalized name → name+position →
  disambiguate by team. **Unmatched players are logged, never dropped.**
- **Upserts** avoid duplicates via each table's unique constraint (batches of 500).
- **`--dry-run`** reports counts + a sample row and writes nothing. Without
  Supabase keys, dry-run still fetches/parses the source (player matching is
  skipped).
- **`data_sync_runs`** records each run (type, source, status, rows, errors).
- **Nothing is invented.** Missing metrics/projections/images are left NULL or
  skipped with a clear message — never fabricated. `fantasy_points_half_ppr` is
  computed from real `fantasy_points` + `0.5 × receptions` (the definition of
  half-PPR), not guessed.

## Security

`SUPABASE_SERVICE_ROLE_KEY` and any provider API keys are **server-side only** —
never embedded in the iOS app. The app reads via the public publishable key with
row-level-security read policies.
