import type { InjuryStatus, Position } from "../types/playerMetrics.js";
import type { SleeperPlayer } from "./types.js";

const VALID_POSITIONS: Position[] = ["QB", "RB", "WR", "TE", "K", "DEF"];

function normalizeInjury(raw: string | null | undefined): InjuryStatus {
  switch ((raw ?? "").toUpperCase()) {
    case "QUESTIONABLE":
      return "Questionable";
    case "DOUBTFUL":
      return "Doubtful";
    case "OUT":
      return "Out";
    case "IR":
    case "PUP":
    case "NA":
      return "IR";
    default:
      return "Healthy";
  }
}

/**
 * Client for Sleeper's free, public, documented API (no key required).
 * Docs: https://docs.sleeper.com/
 *
 * This is a trusted, first-party source — not web scraping.
 */
export class SleeperClient {
  constructor(private readonly baseUrl: string) {}

  private async getJson<T>(path: string): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`);
    if (!res.ok) {
      throw new Error(`Sleeper API ${path} failed: ${res.status} ${res.statusText}`);
    }
    return (await res.json()) as T;
  }

  /** Fetch the full NFL player catalog and normalize to our identity shape. */
  async getPlayers(): Promise<SleeperPlayer[]> {
    const raw = await this.getJson<Record<string, RawSleeperPlayer>>("/players/nfl");
    const players: SleeperPlayer[] = [];
    for (const [id, p] of Object.entries(raw)) {
      const position = (p.position ?? "") as string;
      if (!VALID_POSITIONS.includes(position as Position)) continue;
      players.push({
        playerId: id,
        fullName: p.full_name ?? `${p.first_name ?? ""} ${p.last_name ?? ""}`.trim(),
        position: position as Position,
        team: p.team ?? null,
        age: typeof p.age === "number" ? p.age : null,
        injuryStatus: normalizeInjury(p.injury_status),
      });
    }
    return players;
  }

  /** Current NFL state (week, season, etc.). */
  async getNflState(): Promise<{ week: number; season: string; season_type: string }> {
    return this.getJson("/state/nfl");
  }

  /** Rosters for a league (used by league-sync features). */
  async getLeagueRosters(leagueId: string): Promise<unknown[]> {
    return this.getJson(`/league/${leagueId}/rosters`);
  }
}

interface RawSleeperPlayer {
  full_name?: string;
  first_name?: string;
  last_name?: string;
  position?: string;
  team?: string | null;
  age?: number;
  injury_status?: string | null;
}
