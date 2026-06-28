import type { PlayerMetrics } from "../types/playerMetrics.js";
import type { MetricsQuery, MetricsRepository } from "./repository.js";

/** In-memory repository. Default store; requires no database. */
export class MemoryRepository implements MetricsRepository {
  private metrics = new Map<string, PlayerMetrics>();
  private ingestions: Array<Record<string, unknown>> = [];

  private key(playerId: string, season: number, week: number): string {
    return `${playerId}:${season}:${week}`;
  }

  async migrate(): Promise<void> {
    // no-op
  }

  async upsertMany(metrics: PlayerMetrics[]): Promise<number> {
    for (const m of metrics) {
      this.metrics.set(this.key(m.playerId, m.season, m.week), { ...m });
    }
    return metrics.length;
  }

  async getOne(
    playerId: string,
    season: number,
    week: number,
  ): Promise<PlayerMetrics | undefined> {
    const found = this.metrics.get(this.key(playerId, season, week));
    return found ? { ...found } : undefined;
  }

  async query(query: MetricsQuery): Promise<PlayerMetrics[]> {
    let rows = [...this.metrics.values()];
    if (query.season !== undefined) rows = rows.filter((r) => r.season === query.season);
    if (query.week !== undefined) rows = rows.filter((r) => r.week === query.week);
    if (query.position !== undefined) rows = rows.filter((r) => r.position === query.position);
    rows.sort((a, b) => b.projectedPoints - a.projectedPoints);
    if (query.limit !== undefined) rows = rows.slice(0, query.limit);
    return rows.map((r) => ({ ...r }));
  }

  async recordIngestion(run: {
    source: string;
    season: number;
    week: number;
    rows: number;
    status: string;
    detail?: string;
  }): Promise<void> {
    this.ingestions.push({ ...run, startedAt: new Date().toISOString() });
  }

  async close(): Promise<void> {
    // no-op
  }
}
