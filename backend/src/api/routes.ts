import express, { type Request, type Response } from "express";
import { config } from "../config.js";
import { getCache } from "../cache/cache.js";
import type { MetricsRepository } from "../db/repository.js";
import { RecommendationEngine } from "../engine/recommendationEngine.js";
import { runIngestion } from "../ingestion/ingestService.js";
import {
  DEFAULT_LEAGUE,
  type LeagueSettings,
  type PlayerMetrics,
  type Position,
} from "../types/playerMetrics.js";

function parseLeague(body: unknown): LeagueSettings {
  const b = (body ?? {}) as { league?: Partial<LeagueSettings> };
  return { ...DEFAULT_LEAGUE, ...(b.league ?? {}) };
}

function seasonWeek(req: Request): { season: number; week: number } {
  const q = req.query;
  const body = req.body as { season?: number; week?: number } | undefined;
  const season = Number(q.season ?? body?.season ?? config.season);
  const week = Number(q.week ?? body?.week ?? 0);
  return { season, week };
}

async function fetchByIds(
  repo: MetricsRepository,
  ids: string[],
  season: number,
  week: number,
): Promise<PlayerMetrics[]> {
  const found = await Promise.all(ids.map((id) => repo.getOne(id, season, week)));
  return found.filter((m): m is PlayerMetrics => m !== undefined);
}

export function buildRouter(repo: MetricsRepository): express.Router {
  const router = express.Router();
  const cache = getCache();

  router.get("/health", (_req, res) => {
    res.json({ status: "ok", dataStore: config.dataStore, season: config.season });
  });

  // ---- Player metrics ----
  router.get("/players", async (req: Request, res: Response) => {
    const { season, week } = seasonWeek(req);
    const position = req.query.position as Position | undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const cacheKey = `players:${season}:${week}:${position ?? "all"}:${limit ?? "all"}`;

    const cached = await cache.get<PlayerMetrics[]>(cacheKey);
    if (cached) return res.json({ cached: true, players: cached });

    const players = await repo.query({ season, week, position, limit });
    await cache.set(cacheKey, players, config.cacheTtlSeconds);
    res.json({ cached: false, players });
  });

  router.get("/players/:id", async (req: Request, res: Response) => {
    const { season, week } = seasonWeek(req);
    const metrics = await repo.getOne(req.params.id ?? "", season, week);
    if (!metrics) return res.status(404).json({ error: "player metrics not found" });
    res.json({ player: metrics });
  });

  // ---- Ingestion (pull from trusted sources) ----
  router.post("/ingest", async (req: Request, res: Response) => {
    const body = req.body as { season?: number; week?: number } | undefined;
    try {
      const result = await runIngestion(repo, {
        season: body?.season ?? config.season,
        week: body?.week,
        sleeperBase: config.sleeperApiBase,
        nflverseBase: config.nflverseBase,
      });
      res.json({ ok: true, ...result });
    } catch (err) {
      res.status(502).json({ ok: false, error: (err as Error).message });
    }
  });

  // ---- Recommendations ----
  router.post("/recommendations/start-sit", async (req: Request, res: Response) => {
    const { season, week } = seasonWeek(req);
    const league = parseLeague(req.body);
    const ids = (req.body?.playerIds ?? []) as string[];
    const players = await fetchByIds(repo, ids, season, week);
    if (players.length === 0)
      return res.status(400).json({ error: "no matching players for given ids/season/week" });
    res.json({ recommendations: new RecommendationEngine(league).startSit(players) });
  });

  router.post("/recommendations/waiver", async (req: Request, res: Response) => {
    const { season, week } = seasonWeek(req);
    const league = parseLeague(req.body);
    const limit = req.body?.limit ? Number(req.body.limit) : 50;
    const pool = await repo.query({ season, week, limit });
    res.json({ recommendations: new RecommendationEngine(league).waiver(pool).slice(0, 10) });
  });

  router.post("/recommendations/draft", async (req: Request, res: Response) => {
    const { season, week } = seasonWeek(req);
    const league = parseLeague(req.body);
    const limit = req.body?.limit ? Number(req.body.limit) : 200;
    const pool = await repo.query({ season, week, limit });
    res.json({ recommendations: new RecommendationEngine(league).draft(pool).slice(0, 30) });
  });

  router.post("/recommendations/dynasty", async (req: Request, res: Response) => {
    const { season, week } = seasonWeek(req);
    const league = parseLeague(req.body);
    const limit = req.body?.limit ? Number(req.body.limit) : 200;
    const pool = await repo.query({ season, week, limit });
    res.json({ recommendations: new RecommendationEngine(league).dynasty(pool).slice(0, 30) });
  });

  router.post("/recommendations/keeper", async (req: Request, res: Response) => {
    const { season, week } = seasonWeek(req);
    const league = parseLeague(req.body);
    const limit = req.body?.limit ? Number(req.body.limit) : 200;
    const pool = await repo.query({ season, week, limit });
    res.json({ recommendations: new RecommendationEngine(league).keeper(pool).slice(0, 30) });
  });

  router.post("/recommendations/trade", async (req: Request, res: Response) => {
    const { season, week } = seasonWeek(req);
    const league = parseLeague(req.body);
    const give = await fetchByIds(repo, (req.body?.give ?? []) as string[], season, week);
    const get = await fetchByIds(repo, (req.body?.get ?? []) as string[], season, week);
    res.json({ recommendation: new RecommendationEngine(league).trade(give, get) });
  });

  return router;
}
