import "dotenv/config";

function num(value: string | undefined, fallback: number): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

export const config = {
  port: num(process.env.PORT, 8080),
  dataStore: (process.env.DATA_STORE ?? "memory") as "postgres" | "memory",
  databaseUrl: process.env.DATABASE_URL ?? "postgres://postgres:postgres@localhost:5432/caldwell",
  redisUrl: process.env.REDIS_URL,
  cacheTtlSeconds: num(process.env.CACHE_TTL_SECONDS, 300),
  sleeperApiBase: process.env.SLEEPER_API_BASE ?? "https://api.sleeper.app/v1",
  nflverseBase:
    process.env.NFLVERSE_BASE ?? "https://github.com/nflverse/nflverse-data/releases/download",
  season: num(process.env.SEASON, 2024),
} as const;

export type AppConfig = typeof config;
