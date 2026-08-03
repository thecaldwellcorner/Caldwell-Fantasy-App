import express, { type Request, type Response } from "express";
import { config } from "../config.js";
import { getCache } from "../cache/cache.js";
import type { DataStore } from "../data/store.js";
import type { Player, Position, ScoringFormat, SourceMeta } from "../data/models.js";
import { RecommendationService } from "../services/recommendationService.js";
import { defaultContext, syncLeague, syncStats } from "../sync/syncService.js";

/** How old (seconds) stored data can be before we flag it as stale/delayed. */
const STALE_AFTER_SECONDS = 15 * 60;

interface Sourced {
  meta: SourceMeta;
}

interface DataMeta {
  lastUpdated: string | null;
  sourceAsOf: string | null;
  sources: string[];
  stale: boolean;
}

function dataMeta(items: Sourced[]): DataMeta {
  let lastUpdated: string | null = null;
  let sourceAsOf: string | null = null;
  const sources = new Set<string>();
  for (const it of items) {
    sources.add(it.meta.source);
    if (!lastUpdated || it.meta.fetchedAt > lastUpdated) lastUpdated = it.meta.fetchedAt;
    if (!sourceAsOf || it.meta.sourceUpdatedAt > sourceAsOf) sourceAsOf = it.meta.sourceUpdatedAt;
  }
  const stale = sourceAsOf ? Date.now() - Date.parse(sourceAsOf) > STALE_AFTER_SECONDS * 1000 : true;
  return { lastUpdated, sourceAsOf, sources: [...sources], stale };
}

function parseSeasonWeek(req: Request): { season: number; week: number } {
  return {
    season: Number(req.query.season ?? config.season),
    week: Number(req.query.week ?? config.currentWeek),
  };
}

function parseScoring(req: Request): ScoringFormat {
  const s = String(req.query.scoring ?? "ppr");
  return s === "half_ppr" || s === "standard" ? s : "ppr";
}

function parseIds(value: unknown): string[] {
  if (typeof value !== "string" || value.trim() === "") return [];
  return value.split(",").map((s) => s.trim()).filter(Boolean);
}

/**
 * The public data API. The iOS app calls ONLY these endpoints — never a
 * third-party provider directly. Every response carries `meta` with the
 * "last updated" timestamp, the internal source label(s), and a `stale` flag so
 * the app can render "last updated" and graceful fallbacks.
 */
export function buildDataRouter(store: DataStore): express.Router {
  const router = express.Router();
  const cache = getCache();
  const recs = new RecommendationService(store);

  router.get("/health", (_req, res) => {
    res.json({
      status: "ok",
      dataStore: config.dataStore,
      statsProvider: config.statsProvider,
      leagueProvider: config.leagueProvider,
      season: config.season,
      week: config.currentWeek,
    });
  });

  // ---- Manual refresh (pull from providers into the store) ----
  router.post("/sync", async (req: Request, res: Response) => {
    const force = req.query.force === "true";
    const summary = await syncStats(store, defaultContext(), { force });
    res.json(summary);
  });
  router.post("/sync/league/:leagueId", async (req: Request, res: Response) => {
    const force = req.query.force === "true";
    const summary = await syncLeague(store, req.params.leagueId ?? "", defaultContext(), { force });
    res.json(summary);
  });

  // ---- Players ----
  router.get("/players", async (req: Request, res: Response) => {
    const position = req.query.position as Position | undefined;
    const team = req.query.team as string | undefined;
    const search = req.query.search as string | undefined;
    const limit = req.query.limit ? Number(req.query.limit) : undefined;
    const cacheKey = `api:players:${position ?? ""}:${team ?? ""}:${search ?? ""}:${limit ?? ""}`;

    const cached = await cache.get<{ players: Player[]; meta: DataMeta }>(cacheKey);
    if (cached) return res.json({ ...cached, cached: true });

    const players = await store.getPlayers({ position, team, search, limit });
    const payload = { players, meta: dataMeta(players) };
    await cache.set(cacheKey, payload, config.cacheTtlSeconds);
    res.json({ ...payload, cached: false });
  });

  router.get("/players/:id", async (req: Request, res: Response) => {
    const player = await store.getPlayer(req.params.id ?? "");
    if (!player) {
      return res.status(404).json({
        available: false,
        player: null,
        fallback: { reason: "Player not found in store. Try POST /sync to refresh." },
      });
    }
    res.json({ available: true, player, meta: dataMeta([player]) });
  });

  router.get("/players/:id/stats", async (req: Request, res: Response) => {
    const id = req.params.id ?? "";
    const season = Number(req.query.season ?? config.season);
    const week = req.query.week !== undefined ? Number(req.query.week) : undefined;
    const rows = await store.getPlayerWeeklyStats(id, season, week);
    if (rows.length === 0) {
      return res.json({
        available: false,
        stats: [],
        fallback: { reason: "No stored weekly stats for this player/season yet." },
      });
    }
    res.json({ available: true, stats: rows, meta: dataMeta(rows) });
  });

  router.get("/players/:id/projections", async (req: Request, res: Response) => {
    const id = req.params.id ?? "";
    const season = Number(req.query.season ?? config.season);
    const week = req.query.week !== undefined ? Number(req.query.week) : undefined;
    const rows = await store.getPlayerProjections(id, season, week);
    if (rows.length === 0) {
      return res.json({
        available: false,
        projections: [],
        fallback: { reason: "Current projection unavailable for this player." },
      });
    }
    res.json({ available: true, projections: rows, meta: dataMeta(rows) });
  });

  router.get("/players/:id/injury", async (req: Request, res: Response) => {
    const injury = await store.getPlayerInjury(req.params.id ?? "");
    if (!injury) {
      return res.json({
        available: false,
        injury: null,
        fallback: { reason: "No injury report on file (treat as Healthy unless stale)." },
      });
    }
    res.json({ available: true, injury, meta: dataMeta([injury]) });
  });

  // ---- League ----
  router.get("/league/:leagueId", async (req: Request, res: Response) => {
    const leagueId = req.params.leagueId ?? "";
    let league = await store.getLeague(leagueId);
    if (!league) {
      // Lazy refresh so a first-time league id is populated on demand.
      await syncLeague(store, leagueId, defaultContext());
      league = await store.getLeague(leagueId);
    }
    if (!league) {
      return res.status(404).json({
        available: false,
        league: null,
        fallback: { reason: "League not found at the configured provider." },
      });
    }
    res.json({ available: true, league, meta: dataMeta([league]) });
  });

  router.get("/league/:leagueId/rosters", async (req: Request, res: Response) => {
    const leagueId = req.params.leagueId ?? "";
    let rosters = await store.getLeagueRosters(leagueId);
    if (rosters.length === 0) {
      await syncLeague(store, leagueId, defaultContext());
      rosters = await store.getLeagueRosters(leagueId);
    }
    if (rosters.length === 0) {
      return res.json({ available: false, rosters: [], fallback: { reason: "No rosters synced for this league." } });
    }
    res.json({ available: true, rosters, meta: dataMeta(rosters) });
  });

  router.get("/league/:leagueId/matchups", async (req: Request, res: Response) => {
    const leagueId = req.params.leagueId ?? "";
    const week = req.query.week !== undefined ? Number(req.query.week) : undefined;
    let matchups = await store.getLeagueMatchups(leagueId, week);
    if (matchups.length === 0) {
      await syncLeague(store, leagueId, defaultContext());
      matchups = await store.getLeagueMatchups(leagueId, week);
    }
    if (matchups.length === 0) {
      return res.json({ available: false, matchups: [], fallback: { reason: "No matchups synced for this league/week." } });
    }
    res.json({ available: true, matchups, meta: dataMeta(matchups) });
  });

  // ---- Recommendations (grounded in stored data only) ----
  router.get("/recommendations/start-sit", async (req: Request, res: Response) => {
    const { season, week } = parseSeasonWeek(req);
    const playerIds = parseIds(req.query.players);
    if (playerIds.length === 0) {
      return res.status(400).json({ error: "provide ?players=id1,id2,..." });
    }
    const result = await recs.startSit({
      playerIds,
      scoring: parseScoring(req),
      season,
      week,
      leagueId: req.query.leagueId as string | undefined,
    });
    res.json(result);
  });

  router.get("/recommendations/trade", async (req: Request, res: Response) => {
    const { season, week } = parseSeasonWeek(req);
    const give = parseIds(req.query.give);
    const get = parseIds(req.query.get);
    if (give.length === 0 && get.length === 0) {
      return res.status(400).json({ error: "provide ?give=id1,.. and/or ?get=id2,.." });
    }
    const result = await recs.trade({
      give,
      get,
      scoring: parseScoring(req),
      season,
      week,
      leagueId: req.query.leagueId as string | undefined,
    });
    res.json(result);
  });

  router.get("/recommendations/waivers", async (req: Request, res: Response) => {
    const { season, week } = parseSeasonWeek(req);
    const result = await recs.waivers({
      scoring: parseScoring(req),
      season,
      week,
      position: req.query.position as Position | undefined,
      limit: req.query.limit ? Number(req.query.limit) : undefined,
      leagueId: req.query.leagueId as string | undefined,
    });
    res.json(result);
  });

  return router;
}
