# Caldwell IQ — Backend Data Layer

Node.js + TypeScript backend that is the **only** thing the iOS app talks to. The
app never calls third-party APIs and never holds API keys. The backend pulls from
approved providers, normalizes everything into a Supabase/PostgreSQL database, and
serves it back through a small, cached, timestamped REST API.

```
iOS app ──HTTP──> backend API ──adapters──> Sleeper (leagues) + licensed NFL feed (stats)
                      │
                      └── Supabase / Postgres (normalized, source-labeled, timestamped)
```

## Design guarantees

1. **App → backend only.** The app calls our endpoints; it never scrapes or hits a vendor.
2. **Pluggable providers.** Provider *adapters* isolate every vendor. Mock adapters
   ship today; SportsDataIO / MySportsFeeds / Sportradar drop in behind the same
   `StatsProvider` interface with zero changes to the store, API, or app.
3. **Normalized storage in Supabase.** Ten tables (below) hold player, team, game,
   stats, projection, injury, roster, matchup and recommendation data.
4. **Keys stay server-side.** Provider keys live in the backend env only (see `.env.example`).
5. **Caching.** A TTL cache guards provider calls (no redundant fetches) and hot reads.
6. **Timestamps.** Every record carries `source`, `sourceUpdatedAt`, `fetchedAt`; every
   response includes a `meta.lastUpdated` for the app's "last updated" UI.
7. **Fallbacks.** Missing/delayed data returns an explicit `{ available:false, fallback }`
   (or a `stale:true` flag) instead of failing.
8. **Source labels.** Provenance is attached to every stored row and to every stat a
   recommendation cites — internally every stat knows where it came from.

## Quick start

```bash
cd backend
npm install
cp .env.example .env      # defaults: in-memory store + mock providers, works instantly
npm run dev               # http://localhost:8080, auto-seeds via the mock provider
```

```bash
curl localhost:8080/api/health
curl "localhost:8080/api/players?limit=5"
curl "localhost:8080/api/recommendations/start-sit?players=4046,4035&scoring=ppr"
```

## Using Supabase

Supabase is managed Postgres — point the backend at it and run migrations:

```bash
export DATA_STORE=supabase
export SUPABASE_DB_URL='postgres://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres'
npm run migrate           # applies db/supabase_schema.sql
npm run dev
```

Plug in a licensed stats feed later (no app changes needed):

```bash
export STATS_PROVIDER=sportsdataio
export SPORTSDATAIO_API_KEY=your-server-side-key   # server-only, never in the app
export LEAGUE_PROVIDER=sleeper                      # real Sleeper league data
```

## Tables (`db/supabase_schema.sql`)

`teams`, `players`, `games`, `player_weekly_stats`, `player_projections`,
`injuries`, `fantasy_leagues`, `fantasy_rosters`, `fantasy_matchups`,
`ai_recommendations`. Every table carries `source`, `source_updated_at`,
`fetched_at`, `updated_at`.

## API

Base path `/api`. Every read response includes `meta` (`lastUpdated`, `sourceAsOf`,
`sources`, `stale`) or an `{ available:false, fallback }` envelope.

| Method | Path | Description |
|---|---|---|
| GET | `/players?position=&team=&search=&limit=` | List players (cached) |
| GET | `/players/:id` | One player |
| GET | `/players/:id/stats?season=&week=` | Actual weekly stats |
| GET | `/players/:id/projections?season=&week=` | Projections |
| GET | `/players/:id/injury` | Latest injury report |
| GET | `/league/:leagueId` | League settings (lazy-syncs if unknown) |
| GET | `/league/:leagueId/rosters` | Rosters + records |
| GET | `/league/:leagueId/matchups?week=` | Weekly matchups |
| GET | `/recommendations/start-sit?players=id1,id2&scoring=&leagueId=` | Grounded start/sit |
| GET | `/recommendations/trade?give=&get=&scoring=` | Grounded trade grade |
| GET | `/recommendations/waivers?leagueId=&position=&limit=&scoring=` | Grounded waiver targets |
| POST | `/sync?force=true` | Refresh core data from the stats provider |
| POST | `/sync/league/:leagueId?force=true` | Refresh a league |
| GET | `/health` | Store + provider status |

### Recommendations are grounded — they never invent stats

Every recommendation endpoint reads **only stored data** and returns:

```jsonc
{
  "recommendation": "Start Ja'Marr Chase; sit Cooper Kupp.",
  "reasoning": "Ranked by stored PPR value for 2024 week 1. ...",
  "keyStatsUsed": [ { "label": "...", "value": "20.5", "playerId": "4046", "source": "mock" } ],
  "confidence": 95,
  "sourceTimestamps": { "projections": "…", "stats": "…", "injuries": "…" },
  "missingDataWarning": null   // e.g. "Current projection unavailable for: Sam LaPorta …"
}
```

If a player has no stored projection/stats, that gap appears in
`missingDataWarning` and lowers `confidence` — the engine falls back to season
averages where possible and otherwise says so, rather than guessing.

## Architecture

```
backend/
├── db/
│   ├── supabase_schema.sql       # the 10 normalized tables
│   └── schema.sql                # legacy PlayerMetrics schema
├── src/
│   ├── data/                     # models (+ SourceMeta), DataStore, memory + Supabase stores
│   ├── providers/                # StatsProvider/LeagueProvider adapters
│   │   ├── mockStatsProvider.ts  #   deterministic mock NFL feed (default)
│   │   ├── mockLeagueProvider.ts #   mock league/rosters/matchups
│   │   ├── sleeperLeagueProvider.ts  # real Sleeper (free public API)
│   │   ├── sportsDataIoProvider.ts   # licensed-feed template (key server-side)
│   │   └── index.ts              #   provider factory (falls back to mock)
│   ├── sync/syncService.ts       # pull → normalize → stamp source/time → upsert (cached)
│   ├── services/recommendationService.ts  # grounded start-sit / trade / waivers
│   ├── api/dataRoutes.ts         # the endpoints above (mounted at /api)
│   ├── api/routes.ts             # legacy engine (mounted at /api/legacy)
│   └── index.ts                  # bootstrap: migrate, seed via provider, serve
└── test/                         # vitest: providers, store, sync, grounded recs
```

## Scripts

| Script | Purpose |
|---|---|
| `npm run dev` | Run with hot reload (tsx) |
| `npm run build` / `npm start` | Compile to `dist/` and run |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | Vitest (data layer + legacy engine + normalizer) |
| `npm run migrate` | Apply the legacy DB schema |

## Legacy pipeline

The earlier Sleeper + nflverse `PlayerMetrics` ingestion and deterministic
`RecommendationEngine` are preserved and mounted at **`/api/legacy`** (`POST
/api/legacy/recommendations/*`, `POST /api/legacy/ingest`). The new data layer is
the primary contract going forward.
