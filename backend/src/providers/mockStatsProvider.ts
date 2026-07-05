import type {
  Game,
  Injury,
  Player,
  PlayerProjection,
  PlayerWeeklyStat,
  SourceMeta,
  Team,
} from "../data/models.js";
import { MOCK_PLAYERS, MOCK_TEAMS, type MockPlayerSeed } from "./mockDataset.js";
import type { ProviderContext, StatsProvider } from "./types.js";

/** Deterministic 0..1 pseudo-random from a string seed (stable across runs). */
function seededUnit(seed: string): number {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) {
    h ^= seed.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return ((h >>> 0) % 10000) / 10000;
}

const round1 = (n: number): number => Math.round(n * 10) / 10;

/**
 * Mock NFL stats provider. Produces deterministic, realistic-looking data so the
 * full pipeline (sync → store → API → recommendations) works with no external
 * dependencies. Swapping in SportsDataIO/Sportradar means implementing the same
 * `StatsProvider` interface — nothing else changes.
 */
export class MockStatsProvider implements StatsProvider {
  readonly sourceLabel = "mock" as const;

  isConfigured(): boolean {
    return true;
  }

  private meta(now: string): SourceMeta {
    return { source: this.sourceLabel, sourceUpdatedAt: now, fetchedAt: now };
  }

  async fetchTeams(_ctx: ProviderContext): Promise<Team[]> {
    const now = new Date().toISOString();
    return MOCK_TEAMS.map((t) => ({
      teamId: t.teamId,
      name: t.name,
      abbreviation: t.teamId,
      conference: t.conference,
      division: t.division,
      byeWeek: t.byeWeek,
      logoUrl: `https://static.caldwelliq.mock/logos/${t.teamId}.png`,
      meta: this.meta(now),
    }));
  }

  async fetchPlayers(_ctx: ProviderContext): Promise<Player[]> {
    const now = new Date().toISOString();
    return MOCK_PLAYERS.map((p) => {
      const [firstName, ...rest] = p.fullName.split(" ");
      return {
        playerId: p.playerId,
        fullName: p.fullName,
        firstName: firstName ?? p.fullName,
        lastName: rest.join(" ") || null,
        position: p.position,
        team: p.team,
        jerseyNumber: p.jersey,
        age: p.age,
        heightInches: 70 + Math.round(seededUnit(p.playerId) * 8),
        weightLbs: 190 + Math.round(seededUnit(`${p.playerId}w`) * 60),
        college: null,
        status: p.injury === "IR" ? "Inactive" : "Active",
        headshotUrl: `https://static.caldwelliq.mock/headshots/${p.playerId}.png`,
        meta: this.meta(now),
      };
    });
  }

  async fetchGames(ctx: ProviderContext): Promise<Game[]> {
    const now = new Date().toISOString();
    const week = ctx.week || 1;
    const teams = MOCK_TEAMS.map((t) => t.teamId);
    const games: Game[] = [];
    for (let i = 0; i + 1 < teams.length; i += 2) {
      const home = teams[i] as string;
      const away = teams[i + 1] as string;
      const kickoff = new Date(Date.now() + i * 3600_000).toISOString();
      const r = seededUnit(`${home}${away}${ctx.season}${week}`);
      const status: Game["status"] = r < 0.34 ? "scheduled" : r < 0.67 ? "in_progress" : "final";
      const scored = status !== "scheduled";
      games.push({
        gameId: `${ctx.season}-${week}-${home}-${away}`,
        season: ctx.season,
        week,
        seasonType: "regular",
        homeTeam: home,
        awayTeam: away,
        kickoff,
        status,
        homeScore: scored ? Math.round(r * 31) : null,
        awayScore: scored ? Math.round(seededUnit(`${away}${home}`) * 31) : null,
        quarter: status === "in_progress" ? 1 + Math.round(r * 3) : status === "final" ? 4 : null,
        clock: status === "in_progress" ? "07:24" : null,
        meta: this.meta(now),
      });
    }
    return games;
  }

  async fetchWeeklyStats(ctx: ProviderContext): Promise<PlayerWeeklyStat[]> {
    const now = new Date().toISOString();
    const week = ctx.week || 1;
    return MOCK_PLAYERS.map((p) => {
      const r = seededUnit(`${p.playerId}:${ctx.season}:${week}`);
      const factor = 0.7 + r * 0.6; // 0.7..1.3 of baseline
      const ppr = round1(p.baselinePpr * factor);
      return { ...this.statLine(p, ppr, r), season: ctx.season, week, meta: this.meta(now) };
    });
  }

  private statLine(
    p: MockPlayerSeed,
    ppr: number,
    r: number,
  ): Omit<PlayerWeeklyStat, "season" | "week" | "meta"> {
    const base = {
      playerId: p.playerId,
      team: p.team,
      opponent: null as string | null,
      passingYards: 0, passingTds: 0, interceptions: 0, completions: 0, passAttempts: 0,
      carries: 0, rushingYards: 0, rushingTds: 0,
      targets: 0, receptions: 0, receivingYards: 0, receivingTds: 0, airYards: 0, targetShare: 0,
      fumblesLost: 0, snaps: Math.round(45 + r * 25), snapShare: round1(0.6 + r * 0.35),
      fantasyPointsPpr: ppr,
      fantasyPointsHalfPpr: round1(ppr * 0.9),
      fantasyPointsStandard: round1(ppr * 0.8),
    };
    if (p.position === "QB") {
      base.passingYards = Math.round(220 + r * 130);
      base.passingTds = 1 + Math.round(r * 2);
      base.interceptions = Math.round(r * 1.4);
      base.completions = Math.round(18 + r * 12);
      base.passAttempts = Math.round(28 + r * 14);
      base.carries = Math.round(3 + r * 6);
      base.rushingYards = Math.round(r * 45);
      base.rushingTds = r > 0.7 ? 1 : 0;
      base.fantasyPointsHalfPpr = base.fantasyPointsPpr;
      base.fantasyPointsStandard = base.fantasyPointsPpr;
    } else if (p.position === "RB") {
      base.carries = Math.round(12 + r * 12);
      base.rushingYards = Math.round(55 + r * 70);
      base.rushingTds = r > 0.6 ? 1 : 0;
      base.targets = Math.round(2 + r * 5);
      base.receptions = Math.round(base.targets * (0.6 + r * 0.3));
      base.receivingYards = Math.round(base.receptions * (6 + r * 4));
      base.targetShare = round1(0.08 + r * 0.1);
      base.airYards = Math.round(base.targets * 4);
    } else {
      base.targets = Math.round(6 + r * 6);
      base.receptions = Math.round(base.targets * (0.6 + r * 0.25));
      base.receivingYards = Math.round(base.receptions * (10 + r * 6));
      base.receivingTds = r > 0.65 ? 1 : 0;
      base.airYards = Math.round(base.targets * (9 + r * 5));
      base.targetShare = round1(0.18 + r * 0.15);
    }
    return base;
  }

  async fetchProjections(ctx: ProviderContext): Promise<PlayerProjection[]> {
    const now = new Date().toISOString();
    const week = ctx.week || 1;
    const out: PlayerProjection[] = [];
    for (const p of MOCK_PLAYERS) {
      if (p.omitProjection) continue; // intentional missing-data case for fallback demo
      const r = seededUnit(`proj:${p.playerId}:${ctx.season}:${week}`);
      const ppr = round1(p.baselinePpr * (0.85 + r * 0.3));
      out.push({
        playerId: p.playerId,
        season: ctx.season,
        week,
        projPassingYards: p.position === "QB" ? Math.round(240 + r * 60) : 0,
        projPassingTds: p.position === "QB" ? round1(1.5 + r) : 0,
        projRushingYards: p.position === "RB" ? Math.round(60 + r * 40) : p.position === "QB" ? Math.round(r * 30) : 0,
        projRushingTds: p.position === "RB" ? round1(0.4 + r * 0.5) : 0,
        projReceptions: p.position === "WR" || p.position === "TE" ? Math.round(5 + r * 4) : Math.round(r * 3),
        projReceivingYards: p.position === "WR" || p.position === "TE" ? Math.round(60 + r * 40) : Math.round(r * 25),
        projReceivingTds: p.position === "WR" || p.position === "TE" ? round1(0.4 + r * 0.4) : 0,
        projFantasyPointsPpr: ppr,
        projFantasyPointsHalfPpr: round1(ppr * 0.9),
        projFantasyPointsStandard: round1(ppr * 0.8),
        floor: round1(ppr * 0.65),
        ceiling: round1(ppr * 1.5),
        meta: this.meta(now),
      });
    }
    return out;
  }

  async fetchInjuries(ctx: ProviderContext): Promise<Injury[]> {
    const now = new Date().toISOString();
    const week = ctx.week || 1;
    return MOCK_PLAYERS.filter((p) => p.injury && p.injury !== "Healthy").map((p) => ({
      playerId: p.playerId,
      season: ctx.season,
      week,
      status: p.injury ?? "Healthy",
      bodyPart: p.injuryBodyPart ?? null,
      practiceStatus: p.injury === "Out" ? "DNP" : "Limited",
      returnEstimate: p.injury === "Out" ? "Week " + (week + 1) : "Game-time decision",
      reportDate: now,
      note: null,
      meta: this.meta(now),
    }));
  }
}
