import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import pg from "pg";
import type { PlayerMetrics, Position, InjuryStatus } from "../types/playerMetrics.js";
import type { MetricsQuery, MetricsRepository } from "./repository.js";

const { Pool } = pg;

interface MetricRow {
  player_id: string;
  name: string;
  position: string;
  team: string;
  age: number | null;
  season: number;
  week: number;
  target_share: number;
  air_yards: number;
  routes_run: number;
  snap_share: number;
  red_zone_usage: number;
  epa_team_context: number;
  matchup_difficulty: number;
  injury_status: string;
  projected_points: number;
  regression_score: number;
  breakout_score: number;
  confidence_score: number;
  updated_at: Date;
}

function rowToMetrics(r: MetricRow): PlayerMetrics {
  return {
    playerId: r.player_id,
    name: r.name,
    position: r.position as Position,
    team: r.team,
    age: r.age,
    season: r.season,
    week: r.week,
    targetShare: r.target_share,
    airYards: r.air_yards,
    routesRun: r.routes_run,
    snapShare: r.snap_share,
    redZoneUsage: r.red_zone_usage,
    epaTeamContext: r.epa_team_context,
    matchupDifficulty: r.matchup_difficulty,
    injuryStatus: r.injury_status as InjuryStatus,
    projectedPoints: r.projected_points,
    regressionScore: r.regression_score,
    breakoutScore: r.breakout_score,
    confidenceScore: r.confidence_score,
    updatedAt: r.updated_at.toISOString(),
  };
}

export class PostgresRepository implements MetricsRepository {
  private pool: pg.Pool;

  constructor(connectionString: string) {
    this.pool = new Pool({ connectionString });
  }

  async migrate(): Promise<void> {
    const here = path.dirname(fileURLToPath(import.meta.url));
    const schemaPath = path.resolve(here, "../../db/schema.sql");
    const sql = await readFile(schemaPath, "utf8");
    await this.pool.query(sql);
  }

  async upsertMany(metrics: PlayerMetrics[]): Promise<number> {
    if (metrics.length === 0) return 0;
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      for (const m of metrics) {
        await client.query(
          `INSERT INTO players (player_id, name, position, team, age, updated_at)
           VALUES ($1,$2,$3,$4,$5, now())
           ON CONFLICT (player_id) DO UPDATE
             SET name = EXCLUDED.name, position = EXCLUDED.position,
                 team = EXCLUDED.team, age = EXCLUDED.age, updated_at = now()`,
          [m.playerId, m.name, m.position, m.team, m.age],
        );
        await client.query(
          `INSERT INTO player_metrics (
             player_id, season, week, target_share, air_yards, routes_run,
             snap_share, red_zone_usage, epa_team_context, matchup_difficulty,
             injury_status, projected_points, regression_score, breakout_score,
             confidence_score, updated_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15, now())
           ON CONFLICT (player_id, season, week) DO UPDATE SET
             target_share = EXCLUDED.target_share,
             air_yards = EXCLUDED.air_yards,
             routes_run = EXCLUDED.routes_run,
             snap_share = EXCLUDED.snap_share,
             red_zone_usage = EXCLUDED.red_zone_usage,
             epa_team_context = EXCLUDED.epa_team_context,
             matchup_difficulty = EXCLUDED.matchup_difficulty,
             injury_status = EXCLUDED.injury_status,
             projected_points = EXCLUDED.projected_points,
             regression_score = EXCLUDED.regression_score,
             breakout_score = EXCLUDED.breakout_score,
             confidence_score = EXCLUDED.confidence_score,
             updated_at = now()`,
          [
            m.playerId, m.season, m.week, m.targetShare, m.airYards, m.routesRun,
            m.snapShare, m.redZoneUsage, m.epaTeamContext, m.matchupDifficulty,
            m.injuryStatus, m.projectedPoints, m.regressionScore, m.breakoutScore,
            m.confidenceScore,
          ],
        );
      }
      await client.query("COMMIT");
      return metrics.length;
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  }

  async getOne(
    playerId: string,
    season: number,
    week: number,
  ): Promise<PlayerMetrics | undefined> {
    const { rows } = await this.pool.query<MetricRow>(
      `SELECT p.name, p.position, p.team, p.age, m.*
         FROM player_metrics m JOIN players p USING (player_id)
        WHERE m.player_id = $1 AND m.season = $2 AND m.week = $3`,
      [playerId, season, week],
    );
    return rows[0] ? rowToMetrics(rows[0]) : undefined;
  }

  async query(query: MetricsQuery): Promise<PlayerMetrics[]> {
    const where: string[] = [];
    const params: unknown[] = [];
    if (query.season !== undefined) { params.push(query.season); where.push(`m.season = $${params.length}`); }
    if (query.week !== undefined) { params.push(query.week); where.push(`m.week = $${params.length}`); }
    if (query.position !== undefined) { params.push(query.position); where.push(`p.position = $${params.length}`); }
    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";
    const limitSql = query.limit !== undefined ? `LIMIT ${Number(query.limit)}` : "";
    const { rows } = await this.pool.query<MetricRow>(
      `SELECT p.name, p.position, p.team, p.age, m.*
         FROM player_metrics m JOIN players p USING (player_id)
         ${whereSql}
         ORDER BY m.projected_points DESC
         ${limitSql}`,
      params,
    );
    return rows.map(rowToMetrics);
  }

  async recordIngestion(run: {
    source: string;
    season: number;
    week: number;
    rows: number;
    status: string;
    detail?: string;
  }): Promise<void> {
    await this.pool.query(
      `INSERT INTO ingestion_runs (source, season, week, rows, status, detail, finished_at)
       VALUES ($1,$2,$3,$4,$5,$6, now())`,
      [run.source, run.season, run.week, run.rows, run.status, run.detail ?? null],
    );
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}
