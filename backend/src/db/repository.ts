import type { PlayerMetrics, Position } from "../types/playerMetrics.js";

export interface MetricsQuery {
  season?: number;
  week?: number;
  position?: Position;
  /** Limit number of rows (after sorting by projectedPoints desc). */
  limit?: number;
}

/**
 * Storage abstraction for player metrics. Implemented by both an in-memory
 * store (default / tests / CI) and a PostgreSQL-backed store (production).
 */
export interface MetricsRepository {
  /** Apply DDL / run migrations. No-op for in-memory. */
  migrate(): Promise<void>;

  /** Upsert a batch of normalized metrics (idempotent on playerId+season+week). */
  upsertMany(metrics: PlayerMetrics[]): Promise<number>;

  /** Fetch a single player's metrics for a given season/week. */
  getOne(playerId: string, season: number, week: number): Promise<PlayerMetrics | undefined>;

  /** Query metrics with optional filters. */
  query(query: MetricsQuery): Promise<PlayerMetrics[]>;

  /** Record an ingestion run for observability. */
  recordIngestion(run: {
    source: string;
    season: number;
    week: number;
    rows: number;
    status: string;
    detail?: string;
  }): Promise<void>;

  /** Release any resources. */
  close(): Promise<void>;
}
