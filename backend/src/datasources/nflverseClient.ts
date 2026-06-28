import type { Position } from "../types/playerMetrics.js";
import type { NflverseWeeklyStat, TeamEpaContext } from "./types.js";
import { parseCsv } from "./csv.js";

const VALID_POSITIONS: Position[] = ["QB", "RB", "WR", "TE", "K", "DEF"];

function num(row: Record<string, string>, ...keys: string[]): number {
  for (const k of keys) {
    const v = row[k];
    if (v !== undefined && v !== "" && v !== "NA") {
      const n = Number(v);
      if (Number.isFinite(n)) return n;
    }
  }
  return 0;
}

function str(row: Record<string, string>, ...keys: string[]): string {
  for (const k of keys) {
    const v = row[k];
    if (v !== undefined && v !== "" && v !== "NA") return v;
  }
  return "";
}

/**
 * Loads nflverse / nflfastR-style datasets published as public CSVs on the
 * nflverse-data GitHub releases. These are trusted, community-maintained,
 * widely used research datasets — not arbitrary scraped pages.
 *
 * Column mapping follows the public nflverse `player_stats` schema, with
 * fallbacks so minor schema drift does not break ingestion.
 */
export class NflverseClient {
  constructor(private readonly baseUrl: string) {}

  private async fetchCsv(url: string): Promise<Record<string, string>[]> {
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`nflverse fetch failed: ${res.status} ${res.statusText} (${url})`);
    }
    return parseCsv(await res.text());
  }

  /** Build the public CSV URL for weekly player stats for a season. */
  weeklyStatsUrl(season: number): string {
    return `${this.baseUrl}/player_stats/player_stats_${season}.csv`;
  }

  /** Fetch + map weekly player stats for a season. */
  async getWeeklyStats(season: number): Promise<NflverseWeeklyStat[]> {
    const rows = await this.fetchCsv(this.weeklyStatsUrl(season));
    return this.mapWeeklyStats(rows, season);
  }

  /** Pure mapping from raw CSV rows → typed weekly stats (testable offline). */
  mapWeeklyStats(rows: Record<string, string>[], season: number): NflverseWeeklyStat[] {
    const out: NflverseWeeklyStat[] = [];
    for (const row of rows) {
      const position = str(row, "position", "position_group") as Position;
      if (!VALID_POSITIONS.includes(position)) continue;
      out.push({
        playerId: str(row, "player_id", "gsis_id", "sleeper_id"),
        playerName: str(row, "player_display_name", "player_name", "full_name"),
        position,
        team: str(row, "recent_team", "team") || null,
        season: num(row, "season") || season,
        week: num(row, "week"),
        targets: num(row, "targets"),
        receptions: num(row, "receptions"),
        receivingYards: num(row, "receiving_yards"),
        receivingTds: num(row, "receiving_tds"),
        receivingAirYards: num(row, "receiving_air_yards", "air_yards"),
        airYardsShare: num(row, "air_yards_share"),
        targetShare: num(row, "target_share"),
        routes: num(row, "routes", "routes_run"),
        wopr: num(row, "wopr", "wopr_x"),
        carries: num(row, "carries", "rushing_attempts"),
        rushingYards: num(row, "rushing_yards"),
        rushingTds: num(row, "rushing_tds"),
        offenseSnaps: num(row, "offense_snaps"),
        teamOffenseSnaps: num(row, "team_offense_snaps"),
        redZoneTouches: num(row, "rz_touches", "red_zone_touches"),
        teamRedZonePlays: num(row, "team_rz_plays", "team_red_zone_plays"),
        passingYards: num(row, "passing_yards"),
        passingTds: num(row, "passing_tds"),
        interceptions: num(row, "interceptions"),
        fantasyPointsPpr: num(row, "fantasy_points_ppr"),
      });
    }
    return out;
  }

  /** Team offensive/defensive EPA context for a season (nflfastR-derived). */
  async getTeamEpaContext(season: number): Promise<TeamEpaContext[]> {
    const url = `${this.baseUrl}/stats_team/stats_team_reg_${season}.csv`;
    try {
      const rows = await this.fetchCsv(url);
      return rows
        .map((row) => ({
          team: str(row, "team"),
          season,
          offenseEpaPerPlay: num(row, "off_epa", "offense_epa_per_play", "epa_per_play"),
          defenseEpaPerPlayAllowed: num(row, "def_epa", "defense_epa_per_play"),
        }))
        .filter((t) => t.team !== "");
    } catch {
      // EPA context is optional; ingestion degrades gracefully without it.
      return [];
    }
  }
}
