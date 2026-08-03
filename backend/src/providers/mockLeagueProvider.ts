import type {
  FantasyLeague,
  FantasyMatchup,
  FantasyRoster,
  SourceMeta,
} from "../data/models.js";
import { MOCK_LEAGUE_ID, MOCK_PLAYERS } from "./mockDataset.js";
import type { LeagueProvider, ProviderContext } from "./types.js";

const OWNERS = ["Caldwell", "Dynasty Daddy", "Waiver Wire Warriors", "Gridiron Gurus"];

/** Mock fantasy league provider so league endpoints work without Sleeper. */
export class MockLeagueProvider implements LeagueProvider {
  readonly sourceLabel = "mock" as const;

  isConfigured(): boolean {
    return true;
  }

  private meta(now: string): SourceMeta {
    return { source: this.sourceLabel, sourceUpdatedAt: now, fetchedAt: now };
  }

  async fetchLeague(leagueId: string, ctx: ProviderContext): Promise<FantasyLeague | undefined> {
    if (leagueId !== MOCK_LEAGUE_ID) return undefined;
    return {
      leagueId,
      platform: "mock",
      name: "Caldwell IQ Demo League",
      season: ctx.season,
      scoring: "ppr",
      teamCount: OWNERS.length,
      superflex: false,
      dynasty: false,
      rosterSlots: { QB: 1, RB: 2, WR: 2, TE: 1, FLEX: 1, K: 1, DEF: 1 },
      meta: this.meta(new Date().toISOString()),
    };
  }

  async fetchRosters(leagueId: string, _ctx: ProviderContext): Promise<FantasyRoster[]> {
    if (leagueId !== MOCK_LEAGUE_ID) return [];
    const now = new Date().toISOString();
    const buckets: string[][] = OWNERS.map(() => []);
    MOCK_PLAYERS.forEach((p, i) => {
      const bucket = buckets[i % OWNERS.length];
      if (bucket) bucket.push(p.playerId);
    });
    return OWNERS.map((owner, idx) => {
      const players = buckets[idx] ?? [];
      return {
        leagueId,
        rosterId: String(idx + 1),
        ownerId: `owner-${idx + 1}`,
        teamName: owner,
        ownerName: owner,
        playerIds: players,
        starters: players.slice(0, 8),
        wins: (idx * 2) % 5,
        losses: (idx + 1) % 5,
        ties: 0,
        pointsFor: 900 + idx * 37.5,
        pointsAgainst: 880 + ((idx + 2) % OWNERS.length) * 30,
        meta: this.meta(now),
      };
    });
  }

  async fetchMatchups(leagueId: string, ctx: ProviderContext): Promise<FantasyMatchup[]> {
    if (leagueId !== MOCK_LEAGUE_ID) return [];
    const now = new Date().toISOString();
    const week = ctx.week || 1;
    const rosters = await this.fetchRosters(leagueId, ctx);
    const out: FantasyMatchup[] = [];
    for (let i = 0; i + 1 < rosters.length; i += 2) {
      const a = rosters[i];
      const b = rosters[i + 1];
      if (!a || !b) continue;
      const matchupId = `${week}-${Math.floor(i / 2) + 1}`;
      const aPts = 95 + ((i + week) % 7) * 6.5;
      const bPts = 90 + ((i + week + 3) % 7) * 6.5;
      out.push({
        leagueId, week, matchupId, rosterId: a.rosterId, opponentRosterId: b.rosterId,
        points: aPts, projectedPoints: aPts - 3, isWinner: aPts >= bPts, meta: this.meta(now),
      });
      out.push({
        leagueId, week, matchupId, rosterId: b.rosterId, opponentRosterId: a.rosterId,
        points: bPts, projectedPoints: bPts + 2, isWinner: bPts > aPts, meta: this.meta(now),
      });
    }
    return out;
  }
}
