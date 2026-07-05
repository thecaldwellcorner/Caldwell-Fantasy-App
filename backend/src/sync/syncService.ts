import { getCache } from "../cache/cache.js";
import { config } from "../config.js";
import type { DataStore } from "../data/store.js";
import { getLeagueProvider, getStatsProvider } from "../providers/index.js";
import type { LeagueProvider, ProviderContext, StatsProvider } from "../providers/types.js";

export interface SyncSummary {
  scope: string;
  ok: boolean;
  source: string;
  counts: Record<string, number>;
  errors: string[];
  syncedAt: string;
  /** True when the refresh was skipped because cached data is still fresh. */
  fromCache: boolean;
}

async function runStep<T>(
  label: string,
  counts: Record<string, number>,
  errors: string[],
  fn: () => Promise<T[]>,
  store: (rows: T[]) => Promise<number>,
): Promise<void> {
  try {
    const rows = await fn();
    counts[label] = await store(rows);
  } catch (err) {
    // Fallback: keep whatever is already stored; record the failure.
    errors.push(`${label}: ${(err as Error).message}`);
  }
}

/**
 * Refreshes core NFL data (teams, players, games, weekly stats, projections,
 * injuries) from the configured stats provider into the store. Each step is
 * independent so one failing feed never blocks the others (graceful fallback).
 * A short cache guard prevents hammering the provider for the same season/week.
 */
export async function syncStats(
  store: DataStore,
  ctx: ProviderContext,
  opts: { force?: boolean; provider?: StatsProvider } = {},
): Promise<SyncSummary> {
  const cache = getCache();
  const cacheKey = `sync:stats:${ctx.season}:${ctx.week}`;
  const syncedAt = new Date().toISOString();

  if (!opts.force && (await cache.get<string>(cacheKey))) {
    return { scope: "stats", ok: true, source: config.statsProvider, counts: {}, errors: [], syncedAt, fromCache: true };
  }

  const provider = opts.provider ?? getStatsProvider();
  const counts: Record<string, number> = {};
  const errors: string[] = [];

  // Teams + players first (referenced by other tables via foreign keys).
  await runStep("teams", counts, errors, () => provider.fetchTeams(ctx), (r) => store.upsertTeams(r));
  await runStep("players", counts, errors, () => provider.fetchPlayers(ctx), (r) => store.upsertPlayers(r));
  await runStep("games", counts, errors, () => provider.fetchGames(ctx), (r) => store.upsertGames(r));
  await runStep("weeklyStats", counts, errors, () => provider.fetchWeeklyStats(ctx), (r) => store.upsertWeeklyStats(r));
  await runStep("projections", counts, errors, () => provider.fetchProjections(ctx), (r) => store.upsertProjections(r));
  await runStep("injuries", counts, errors, () => provider.fetchInjuries(ctx), (r) => store.upsertInjuries(r));

  const ok = errors.length === 0;
  if (ok) await cache.set(cacheKey, syncedAt, config.cacheTtlSeconds);

  return { scope: "stats", ok, source: provider.sourceLabel, counts, errors, syncedAt, fromCache: false };
}

/** Refreshes a single fantasy league (league meta, rosters, matchups). */
export async function syncLeague(
  store: DataStore,
  leagueId: string,
  ctx: ProviderContext,
  opts: { force?: boolean; provider?: LeagueProvider } = {},
): Promise<SyncSummary> {
  const cache = getCache();
  const cacheKey = `sync:league:${leagueId}:${ctx.season}:${ctx.week}`;
  const syncedAt = new Date().toISOString();

  if (!opts.force && (await cache.get<string>(cacheKey))) {
    return { scope: "league", ok: true, source: config.leagueProvider, counts: {}, errors: [], syncedAt, fromCache: true };
  }

  const provider = opts.provider ?? getLeagueProvider();
  const counts: Record<string, number> = {};
  const errors: string[] = [];

  try {
    const league = await provider.fetchLeague(leagueId, ctx);
    if (league) {
      await store.upsertLeague(league);
      counts.league = 1;
    } else {
      errors.push("league: not found at provider");
    }
  } catch (err) {
    errors.push(`league: ${(err as Error).message}`);
  }

  await runStep("rosters", counts, errors, () => provider.fetchRosters(leagueId, ctx), (r) => store.upsertRosters(r));
  await runStep("matchups", counts, errors, () => provider.fetchMatchups(leagueId, ctx), (r) => store.upsertMatchups(r));

  const ok = errors.length === 0;
  if (ok) await cache.set(cacheKey, syncedAt, config.cacheTtlSeconds);

  return { scope: "league", ok, source: provider.sourceLabel, counts, errors, syncedAt, fromCache: false };
}

export function defaultContext(): ProviderContext {
  return { season: config.season, week: config.currentWeek };
}
