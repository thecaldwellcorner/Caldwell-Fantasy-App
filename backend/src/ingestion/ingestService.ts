import type { MetricsRepository } from "../db/repository.js";
import { SleeperClient } from "../datasources/sleeperClient.js";
import { NflverseClient } from "../datasources/nflverseClient.js";
import type {
  NflverseWeeklyStat,
  SleeperPlayer,
  TeamEpaContext,
} from "../datasources/types.js";
import { normalize } from "./metricsNormalizer.js";
import type { PlayerMetrics } from "../types/playerMetrics.js";

const normalizeName = (s: string): string =>
  s.toLowerCase().replace(/[^a-z]/g, "");

/**
 * Joins trusted-source rows and produces normalized metrics. Pure + testable:
 * matches nflverse weekly rows to Sleeper identities by id, falling back to a
 * normalized name+position key (handles differing id namespaces).
 */
export function buildMetrics(
  players: SleeperPlayer[],
  weekly: NflverseWeeklyStat[],
  teamContext: TeamEpaContext[],
): PlayerMetrics[] {
  const byId = new Map<string, SleeperPlayer>();
  const byName = new Map<string, SleeperPlayer>();
  for (const p of players) {
    byId.set(p.playerId, p);
    byName.set(`${normalizeName(p.fullName)}|${p.position}`, p);
  }
  const teamCtx = new Map<string, TeamEpaContext>();
  for (const t of teamContext) teamCtx.set(t.team, t);

  const out: PlayerMetrics[] = [];
  for (const w of weekly) {
    const match =
      byId.get(w.playerId) ??
      byName.get(`${normalizeName(w.playerName)}|${w.position ?? ""}`);
    if (!match) continue;
    out.push(
      normalize({
        player: match,
        weekly: w,
        teamContext: w.team ? teamCtx.get(w.team) : undefined,
      }),
    );
  }
  return out;
}

export interface IngestOptions {
  season: number;
  week?: number;
  sleeperBase: string;
  nflverseBase: string;
}

export interface IngestResult {
  rows: number;
  season: number;
  week: number;
}

/** Full pipeline: pull → normalize → store. Hits live trusted APIs. */
export async function runIngestion(
  repo: MetricsRepository,
  opts: IngestOptions,
): Promise<IngestResult> {
  const sleeper = new SleeperClient(opts.sleeperBase);
  const nflverse = new NflverseClient(opts.nflverseBase);

  const players = await sleeper.getPlayers();
  const weeklyAll = await nflverse.getWeeklyStats(opts.season);
  const teamContext = await nflverse.getTeamEpaContext(opts.season);

  const weekly =
    opts.week !== undefined ? weeklyAll.filter((w) => w.week === opts.week) : weeklyAll;

  const metrics = buildMetrics(players, weekly, teamContext);
  const rows = await repo.upsertMany(metrics);

  const week = opts.week ?? 0;
  await repo.recordIngestion({
    source: "sleeper+nflverse",
    season: opts.season,
    week,
    rows,
    status: "ok",
  });

  return { rows, season: opts.season, week };
}
