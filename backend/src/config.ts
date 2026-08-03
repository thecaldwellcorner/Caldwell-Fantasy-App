import "dotenv/config";

function num(value: string | undefined, fallback: number): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

export const config = {
  port: num(process.env.PORT, 8080),

  // Data store: "supabase"/"postgres" use a Postgres connection string; otherwise
  // an in-memory store (no external deps) is used for dev / CI / tests.
  dataStore: (process.env.DATA_STORE ?? "memory") as "supabase" | "postgres" | "memory",
  databaseUrl: process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/caldwell",
  // Supabase is managed Postgres — accept either SUPABASE_DB_URL or DATABASE_URL.
  supabaseDbUrl:
    process.env.SUPABASE_DB_URL ?? process.env.DATABASE_URL ?? "",

  redisUrl: process.env.REDIS_URL,
  cacheTtlSeconds: num(process.env.CACHE_TTL_SECONDS, 300),

  // Provider selection. Licensed feeds are used only when fully configured;
  // otherwise the mock adapters keep the service working. Keys are server-only.
  statsProvider: (process.env.STATS_PROVIDER ?? "mock") as
    | "mock"
    | "sportsdataio"
    | "mysportsfeeds"
    | "sportradar",
  leagueProvider: (process.env.LEAGUE_PROVIDER ?? "mock") as "mock" | "sleeper",
  sportsDataIoApiKey: process.env.SPORTSDATAIO_API_KEY,
  sportsDataIoBase: process.env.SPORTSDATAIO_BASE ?? "https://api.sportsdata.io/v3/nfl",

  sleeperApiBase: process.env.SLEEPER_API_BASE ?? "https://api.sleeper.app/v1",
  nflverseBase:
    process.env.NFLVERSE_BASE ?? "https://github.com/nflverse/nflverse-data/releases/download",
  season: num(process.env.SEASON, 2024),
  currentWeek: num(process.env.CURRENT_WEEK, 1),
} as const;

export type AppConfig = typeof config;
