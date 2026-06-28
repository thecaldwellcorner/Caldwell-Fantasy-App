# Caldwell Corner Fantasy Football — Backend

Node.js + TypeScript backend that powers the fantasy app's data and AI layer (per the PRD tech stack: Node.js/TypeScript, PostgreSQL, Redis).

It does three things:

1. **Ingests trusted data** from first-party / community-maintained sources — the **Sleeper public API** (player identities, teams, injury status) and **nflverse / nflfastR-style datasets** (weekly usage + team EPA context, published as public CSVs). **It never scrapes arbitrary websites.**
2. **Stores normalized `PlayerMetrics`** in a database (PostgreSQL, with an in-memory fallback for local dev / CI).
3. **Serves AI recommendations** from a deterministic `RecommendationEngine` (start/sit, trade, waiver, draft) — each with a score, confidence rating, and plain-English reasoning, grounded entirely in the stored metrics.

## Requirements

- Node.js >= 20
- (Optional) PostgreSQL 14+ for persistent storage

## Quick start

```bash
cd backend
npm install
cp .env.example .env          # defaults work out of the box (in-memory store)
npm run dev                    # starts on http://localhost:8080, seeds sample metrics
```

Try it:

```bash
curl localhost:8080/api/health
curl "localhost:8080/api/players?limit=5"

curl -X POST localhost:8080/api/recommendations/trade \
  -H 'content-type: application/json' \
  -d '{"league":{"scoring":"ppr","dynasty":true,"superflex":true},"give":["4035"],"get":["11631"]}'
```

## Using a real database

```bash
# Point at Postgres and run migrations
export DATA_STORE=postgres
export DATABASE_URL=postgres://user:pass@localhost:5432/caldwell
npm run migrate
npm run dev
```

## Ingesting live data

```bash
# Pull the full season (Sleeper players + nflverse weekly stats), normalize, store
npm run ingest
# or a single week
npm run ingest -- 6
```

Or trigger over HTTP: `POST /api/ingest { "season": 2024, "week": 6 }`.

> nflverse publishes datasets on GitHub releases; exact file paths occasionally
> change between seasons. `NflverseClient.weeklyStatsUrl()` centralizes the URL
> pattern, and ingestion degrades gracefully (e.g. EPA context is optional).

## API

| Method | Path | Description |
|---|---|---|
| GET | `/api/health` | Service + store status |
| GET | `/api/players?season=&week=&position=&limit=` | Query stored metrics (cached) |
| GET | `/api/players/:id?season=&week=` | One player's metrics |
| POST | `/api/ingest` | Run ingestion from trusted sources |
| POST | `/api/recommendations/start-sit` | `{ league, playerIds[], season?, week? }` |
| POST | `/api/recommendations/waiver` | `{ league, season?, week? }` |
| POST | `/api/recommendations/draft` | `{ league, season?, week? }` |
| POST | `/api/recommendations/dynasty` | `{ league, season?, week? }` — long-horizon ranking |
| POST | `/api/recommendations/keeper` | `{ league, season?, week? }` — win-now/keep ranking |
| POST | `/api/recommendations/trade` | `{ league, give[], get[], season?, week? }` |

`PlayerMetrics` also carries an extended optional advanced-analytics block
(`targetsPerRouteRun`, `yardsPerRouteRun`, `routeParticipation`, `airYardsShare`,
`firstReadShare`, `redZoneTargets`, `endZoneTargets`, `rushShare`, `goalLineShare`,
`explosivePlayRate`, `missedTacklesForced`, `yardsAfterContact`,
`expectedFantasyPoints`, `fantasyPointsOverExpected`, `teamPassRateOverExpected`,
`teamEPAperPlay`, `offensiveLineRank`, `impliedTeamTotal`, `spread`,
`matchupEPAAllowed`, `scheduleDifficulty`) plus provenance (`dataLastUpdated`,
`dataSources`, `hasCurrentData`) used by the grounding guardrails.

## Architecture

```
backend/
├── db/schema.sql                 # PostgreSQL DDL
├── src/
│   ├── config.ts                 # env-driven config
│   ├── types/                    # PlayerMetrics, LeagueSettings, recommendation types
│   ├── datasources/              # SleeperClient, NflverseClient, CSV parser
│   ├── ingestion/                # metricsNormalizer (derives projection/regression/
│   │                             #   breakout/confidence) + ingestService (join + store)
│   ├── db/                       # repository interface + Postgres & in-memory impls + cache + seed
│   ├── engine/                   # RecommendationEngine + scoring
│   ├── api/routes.ts             # Express endpoints
│   └── index.ts                  # server bootstrap
└── test/                         # vitest: engine + normalizer
```

### `PlayerMetrics`

Per the request, every player row carries: `targetShare`, `airYards`, `routesRun`,
`snapShare`, `redZoneUsage`, `epaTeamContext` (team EPA-based offensive context),
`matchupDifficulty`, `injuryStatus`, `projectedPoints`, `regressionScore`,
`breakoutScore`, and `confidenceScore` (plus identity + season/week).

### `RecommendationEngine`

Takes `PlayerMetrics[]` + `LeagueSettings` and returns:

- **start/sit** — Start/Flex/Sit verdict, weekly score, confidence, reasoning
- **waiver** — priority order + suggested FAAB bid %, reasoning
- **draft** — value-over-replacement (positional scarcity aware), reasoning
- **dynasty** — long-horizon ranking (future value weighted), reasoning
- **keeper** — win-now/keep ranking, reasoning
- **trade** — trade grade, fairness, win-now vs. future, risk rating, reasoning

> The richest, fully-explained engine (per-metric key drivers, short/long-term
> values, missing-data guardrails, "Caldwell Take" placeholder) lives in the iOS
> app at `CaldwellCorner/Services/CaldwellEngine.swift`, which powers the AI Coach.
> The AI assistant only **explains** this deterministic output — it never invents
> rankings or stats.

It is deterministic and grounded in the stored metrics (no fabricated stats),
matching the PRD's RAG / anti-hallucination requirement. League context (scoring
format, Superflex, dynasty/keeper, team count, roster slots) adjusts every score.

## Scripts

| Script | Purpose |
|---|---|
| `npm run dev` | Run with hot reload (tsx) |
| `npm run build` / `npm start` | Compile to `dist/` and run |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | Vitest unit tests (engine + normalizer) |
| `npm run migrate` | Apply DB schema |
| `npm run ingest [week]` | Pull + normalize + store metrics |

## Tests

```bash
npm test
```

Covers the recommendation engine (start/sit ordering, injury handling, waiver
FAAB, draft VOR, Superflex QB bump, trade grading/fairness, dynasty weighting)
and the metrics normalizer (field mapping, score bounds, regression/breakout
detection, EPA scaling, id-vs-name joins, CSV parsing).

## iOS integration

The SwiftUI app consumes this service via `CaldwellCorner/Services/BackendClient.swift`
and the mirrored `CaldwellCorner/Models/PlayerMetrics.swift`. Set `CC_BACKEND_URL`
to point the app at a running backend; otherwise it falls back to the on-device
mock data.
