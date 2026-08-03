import type {
  FantasyLeague,
  FantasyMatchup,
  FantasyRoster,
  ScoringFormat,
  SourceMeta,
} from "../data/models.js";
import type { LeagueProvider, ProviderContext } from "./types.js";

interface SleeperLeague {
  name?: string;
  season?: string;
  total_rosters?: number;
  scoring_settings?: Record<string, number>;
  roster_positions?: string[];
  settings?: { type?: number };
}
interface SleeperRoster {
  roster_id?: number;
  owner_id?: string | null;
  players?: string[] | null;
  starters?: string[] | null;
  settings?: {
    wins?: number; losses?: number; ties?: number;
    fpts?: number; fpts_decimal?: number;
    fpts_against?: number; fpts_against_decimal?: number;
  };
}
interface SleeperUser {
  user_id?: string;
  display_name?: string;
  metadata?: { team_name?: string };
}
interface SleeperMatchup {
  roster_id?: number;
  matchup_id?: number | null;
  points?: number;
}

/**
 * Real Sleeper league adapter over Sleeper's free public API (no key needed).
 * This is a trusted first-party source, not web scraping. Sync wraps calls in a
 * try/catch so a Sleeper outage leaves the last-synced league data in place.
 */
export class SleeperLeagueProvider implements LeagueProvider {
  readonly sourceLabel = "sleeper" as const;

  constructor(private readonly baseUrl: string) {}

  isConfigured(): boolean {
    return Boolean(this.baseUrl);
  }

  private meta(): SourceMeta {
    const now = new Date().toISOString();
    return { source: this.sourceLabel, sourceUpdatedAt: now, fetchedAt: now };
  }

  private async getJson<T>(path: string): Promise<T> {
    const res = await fetch(`${this.baseUrl}${path}`);
    if (!res.ok) throw new Error(`Sleeper ${path} failed: ${res.status} ${res.statusText}`);
    return (await res.json()) as T;
  }

  private scoringFormat(s: Record<string, number> | undefined): ScoringFormat {
    const rec = s?.rec ?? 0;
    if (rec >= 1) return "ppr";
    if (rec >= 0.5) return "half_ppr";
    return "standard";
  }

  async fetchLeague(leagueId: string, ctx: ProviderContext): Promise<FantasyLeague | undefined> {
    const l = await this.getJson<SleeperLeague | null>(`/league/${leagueId}`);
    if (!l) return undefined;
    const positions = l.roster_positions ?? [];
    const rosterSlots: Record<string, number> = {};
    for (const pos of positions) {
      if (pos === "BN") continue;
      rosterSlots[pos] = (rosterSlots[pos] ?? 0) + 1;
    }
    return {
      leagueId,
      platform: "sleeper",
      name: l.name ?? `League ${leagueId}`,
      season: Number(l.season) || ctx.season,
      scoring: this.scoringFormat(l.scoring_settings),
      teamCount: l.total_rosters ?? 12,
      superflex: positions.includes("SUPER_FLEX"),
      dynasty: l.settings?.type === 2,
      rosterSlots,
      meta: this.meta(),
    };
  }

  async fetchRosters(leagueId: string, _ctx: ProviderContext): Promise<FantasyRoster[]> {
    const [rosters, users] = await Promise.all([
      this.getJson<SleeperRoster[]>(`/league/${leagueId}/rosters`),
      this.getJson<SleeperUser[]>(`/league/${leagueId}/users`).catch(() => [] as SleeperUser[]),
    ]);
    const userById = new Map<string, SleeperUser>();
    for (const u of users) if (u.user_id) userById.set(u.user_id, u);

    return rosters.map((r) => {
      const owner = r.owner_id ? userById.get(r.owner_id) : undefined;
      const st = r.settings ?? {};
      return {
        leagueId,
        rosterId: String(r.roster_id ?? ""),
        ownerId: r.owner_id ?? null,
        teamName: owner?.metadata?.team_name ?? owner?.display_name ?? null,
        ownerName: owner?.display_name ?? null,
        playerIds: r.players ?? [],
        starters: r.starters ?? [],
        wins: st.wins ?? 0,
        losses: st.losses ?? 0,
        ties: st.ties ?? 0,
        pointsFor: (st.fpts ?? 0) + (st.fpts_decimal ?? 0) / 100,
        pointsAgainst: (st.fpts_against ?? 0) + (st.fpts_against_decimal ?? 0) / 100,
        meta: this.meta(),
      };
    });
  }

  async fetchMatchups(leagueId: string, ctx: ProviderContext): Promise<FantasyMatchup[]> {
    const week = ctx.week || 1;
    const raw = await this.getJson<SleeperMatchup[]>(`/league/${leagueId}/matchups/${week}`);
    // Group by matchup_id to link opponents and decide winners.
    const byMatchup = new Map<number, SleeperMatchup[]>();
    for (const m of raw) {
      const id = m.matchup_id ?? -1;
      const arr = byMatchup.get(id) ?? [];
      arr.push(m);
      byMatchup.set(id, arr);
    }
    const out: FantasyMatchup[] = [];
    for (const [id, entries] of byMatchup) {
      for (const e of entries) {
        const opp = entries.find((o) => o.roster_id !== e.roster_id);
        const points = e.points ?? 0;
        const oppPoints = opp?.points ?? 0;
        out.push({
          leagueId,
          week,
          matchupId: String(id),
          rosterId: String(e.roster_id ?? ""),
          opponentRosterId: opp ? String(opp.roster_id ?? "") : null,
          points,
          projectedPoints: null,
          isWinner: opp ? points >= oppPoints : null,
          meta: this.meta(),
        });
      }
    }
    return out;
  }
}
