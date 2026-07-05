import { randomUUID } from "node:crypto";
import type {
  AiRecommendation,
  GroundedRecommendation,
  Injury,
  KeyStat,
  Player,
  PlayerProjection,
  PlayerWeeklyStat,
  RecommendationKind,
  ScoringFormat,
} from "../data/models.js";
import type { DataStore } from "../data/store.js";

interface Bundle {
  player: Player;
  projection: PlayerProjection | undefined;
  seasonStats: PlayerWeeklyStat[];
  latestWeekly: PlayerWeeklyStat | undefined;
  injury: Injury | undefined;
}

const round1 = (n: number): number => Math.round(n * 10) / 10;
const clamp = (n: number, lo = 0, hi = 100): number => Math.max(lo, Math.min(hi, n));
const mean = (xs: number[]): number => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0);

function projPoints(p: PlayerProjection, scoring: ScoringFormat): number {
  if (scoring === "ppr") return p.projFantasyPointsPpr;
  if (scoring === "half_ppr") return p.projFantasyPointsHalfPpr;
  return p.projFantasyPointsStandard;
}
function actualPoints(s: PlayerWeeklyStat, scoring: ScoringFormat): number {
  if (scoring === "ppr") return s.fantasyPointsPpr;
  if (scoring === "half_ppr") return s.fantasyPointsHalfPpr;
  return s.fantasyPointsStandard;
}

/** Injury multipliers applied to a player's weekly value (never invents data). */
function injuryMultiplier(status: Injury["status"] | undefined): number {
  switch (status) {
    case "Out":
    case "IR":
    case "PUP":
    case "SUS":
      return 0;
    case "Doubtful":
      return 0.35;
    case "Questionable":
      return 0.9;
    default:
      return 1;
  }
}

/**
 * Produces recommendations that are grounded ONLY in data already stored in our
 * database. It never fabricates stats: if a player has no projection or stats,
 * that gap is surfaced in `missingDataWarning` and it lowers confidence.
 */
export class RecommendationService {
  constructor(private readonly store: DataStore) {}

  private async bundle(playerId: string, season: number, week: number): Promise<Bundle | undefined> {
    const player = await this.store.getPlayer(playerId);
    if (!player) return undefined;
    const projections = await this.store.getPlayerProjections(playerId, season);
    const projection =
      projections.find((p) => p.week === week) ?? projections.find((p) => p.week === 0) ?? projections[0];
    const seasonStats = (await this.store.getPlayerWeeklyStats(playerId, season)).filter((s) => s.week > 0);
    const latestWeekly = seasonStats[0];
    const injury = await this.store.getPlayerInjury(playerId);
    return { player, projection, seasonStats, latestWeekly, injury };
  }

  private valueOf(b: Bundle, scoring: ScoringFormat): { value: number | null; basis: string } {
    if (b.projection) return { value: round1(projPoints(b.projection, scoring)), basis: "projection" };
    if (b.seasonStats.length) {
      return {
        value: round1(mean(b.seasonStats.map((s) => actualPoints(s, scoring)))),
        basis: "season average (no projection on file)",
      };
    }
    return { value: null, basis: "no stored data" };
  }

  private sourceTimestamps(bundles: Bundle[]): Record<string, string> {
    const ts: Record<string, string> = {};
    const latest = (cur: string | undefined, next: string): string =>
      !cur || next > cur ? next : cur;
    for (const b of bundles) {
      if (b.projection) ts.projections = latest(ts.projections, b.projection.meta.sourceUpdatedAt);
      if (b.latestWeekly) ts.stats = latest(ts.stats, b.latestWeekly.meta.sourceUpdatedAt);
      if (b.injury) ts.injuries = latest(ts.injuries, b.injury.meta.sourceUpdatedAt);
    }
    return ts;
  }

  private keyStatsFor(b: Bundle, scoring: ScoringFormat): KeyStat[] {
    const stats: KeyStat[] = [];
    if (b.projection) {
      stats.push({
        label: `${b.player.fullName} — projected pts (${scoring})`,
        value: String(round1(projPoints(b.projection, scoring))),
        playerId: b.player.playerId,
        source: b.projection.meta.source,
      });
    }
    if (b.latestWeekly) {
      stats.push({
        label: `${b.player.fullName} — snap share`,
        value: `${Math.round(b.latestWeekly.snapShare * 100)}%`,
        playerId: b.player.playerId,
        source: b.latestWeekly.meta.source,
      });
      if (b.player.position !== "QB") {
        stats.push({
          label: `${b.player.fullName} — target share`,
          value: `${Math.round(b.latestWeekly.targetShare * 100)}%`,
          playerId: b.player.playerId,
          source: b.latestWeekly.meta.source,
        });
      }
    }
    if (b.injury && b.injury.status !== "Healthy") {
      stats.push({
        label: `${b.player.fullName} — injury`,
        value: b.injury.bodyPart ? `${b.injury.status} (${b.injury.bodyPart})` : b.injury.status,
        playerId: b.player.playerId,
        source: b.injury.meta.source,
      });
    }
    return stats;
  }

  private missingWarning(bundles: Bundle[], requestedIds: string[]): string | null {
    const notFound = requestedIds.filter((id) => !bundles.some((b) => b.player.playerId === id));
    const noProjection = bundles.filter((b) => !b.projection).map((b) => b.player.fullName);
    const parts: string[] = [];
    if (notFound.length) parts.push(`No player record for: ${notFound.join(", ")}.`);
    if (noProjection.length)
      parts.push(
        `Current projection unavailable for: ${noProjection.join(", ")} — fell back to season averages where possible.`,
      );
    return parts.length ? parts.join(" ") : null;
  }

  private async persist(
    kind: RecommendationKind,
    leagueId: string | null,
    subjectIds: string[],
    grounded: GroundedRecommendation,
  ): Promise<void> {
    const rec: AiRecommendation = {
      id: randomUUID(),
      leagueId,
      kind,
      subjectPlayerIds: subjectIds,
      recommendation: grounded.recommendation,
      reasoning: grounded.reasoning,
      keyStatsUsed: grounded.keyStatsUsed,
      confidence: grounded.confidence,
      sourceTimestamps: grounded.sourceTimestamps,
      missingDataWarning: grounded.missingDataWarning,
      createdAt: new Date().toISOString(),
    };
    await this.store.insertRecommendation(rec);
  }

  // ---------------------------------------------------------------------------
  // START / SIT
  // ---------------------------------------------------------------------------
  async startSit(args: {
    playerIds: string[];
    scoring: ScoringFormat;
    season: number;
    week: number;
    leagueId?: string;
  }): Promise<GroundedRecommendation> {
    const bundles = (
      await Promise.all(args.playerIds.map((id) => this.bundle(id, args.season, args.week)))
    ).filter((b): b is Bundle => b !== undefined);

    if (bundles.length === 0) {
      return this.empty("No matching players were found in the database for the requested ids.");
    }

    const scored = bundles
      .map((b) => {
        const { value, basis } = this.valueOf(b, args.scoring);
        const adj = value === null ? null : round1(value * injuryMultiplier(b.injury?.status));
        return { b, value, adj, basis };
      })
      .sort((a, b) => (b.adj ?? -1) - (a.adj ?? -1));

    const startCount = Math.max(1, Math.ceil(scored.length / 2));
    const starters = scored.slice(0, startCount);
    const bench = scored.slice(startCount);

    const top = scored[0];
    const gap = scored.length > 1 && top?.adj != null && scored[1]?.adj != null ? top.adj - (scored[1]?.adj ?? 0) : 0;

    const recommendation =
      bench.length === 0
        ? `Start ${starters.map((s) => s.b.player.fullName).join(", ")}.`
        : `Start ${starters.map((s) => s.b.player.fullName).join(", ")}; ` +
          `sit ${bench.map((s) => s.b.player.fullName).join(", ")}.`;

    const lines = scored.map((s) => {
      const inj = s.b.injury && s.b.injury.status !== "Healthy" ? ` [${s.b.injury.status}]` : "";
      const val = s.value === null ? "no data" : `${s.value} pts (${s.basis})`;
      return `${s.b.player.fullName} (${s.b.player.position}): ${val}${inj}`;
    });
    const reasoning = `Ranked by stored ${args.scoring.toUpperCase()} value for ${args.season} week ${args.week}. ${lines.join(
      " · ",
    )}.`;

    const withData = scored.filter((s) => s.value !== null).length;
    const completeness = withData / scored.length;
    const confidence = clamp(
      45 + completeness * 35 + clamp(gap * 2, 0, 20),
      5,
      95,
    );

    const grounded: GroundedRecommendation = {
      recommendation,
      reasoning,
      keyStatsUsed: bundles.flatMap((b) => this.keyStatsFor(b, args.scoring)),
      confidence: Math.round(confidence),
      sourceTimestamps: this.sourceTimestamps(bundles),
      missingDataWarning: this.missingWarning(bundles, args.playerIds),
    };
    await this.persist("start_sit", args.leagueId ?? null, args.playerIds, grounded);
    return grounded;
  }

  // ---------------------------------------------------------------------------
  // TRADE
  // ---------------------------------------------------------------------------
  async trade(args: {
    give: string[];
    get: string[];
    scoring: ScoringFormat;
    season: number;
    week: number;
    leagueId?: string;
  }): Promise<GroundedRecommendation> {
    const giveB = (await Promise.all(args.give.map((id) => this.bundle(id, args.season, args.week)))).filter(
      (b): b is Bundle => b !== undefined,
    );
    const getB = (await Promise.all(args.get.map((id) => this.bundle(id, args.season, args.week)))).filter(
      (b): b is Bundle => b !== undefined,
    );

    if (giveB.length === 0 && getB.length === 0) {
      return this.empty("No matching players were found for either side of the trade.");
    }

    const sideValue = (bs: Bundle[]): number =>
      round1(bs.reduce((acc, b) => acc + (this.valueOf(b, args.scoring).value ?? 0), 0));
    const giveVal = sideValue(giveB);
    const getVal = sideValue(getB);
    const diff = round1(getVal - giveVal);
    const maxV = Math.max(giveVal, getVal, 1);
    const fairness = Math.round(clamp(100 - (Math.abs(diff) / maxV) * 100));

    let verdict: "Accept" | "Fair" | "Decline";
    if (diff > maxV * 0.08) verdict = "Accept";
    else if (diff < -maxV * 0.08) verdict = "Decline";
    else verdict = "Fair";

    const recommendation = `${verdict}: you ${diff >= 0 ? "gain" : "lose"} ${Math.abs(diff)} projected ${args.scoring.toUpperCase()} pts (give ${giveVal}, get ${getVal}).`;
    const reasoning =
      `Give ${giveB.map((b) => b.player.fullName).join(", ") || "nothing"} to receive ` +
      `${getB.map((b) => b.player.fullName).join(", ") || "nothing"}. ` +
      `Fairness ${fairness}/100 based on stored projected values for ${args.season} week ${args.week}.`;

    const all = [...giveB, ...getB];
    const withData = all.filter((b) => this.valueOf(b, args.scoring).value !== null).length;
    const confidence = clamp(40 + (withData / Math.max(all.length, 1)) * 40 + fairness * 0.1, 5, 95);

    const grounded: GroundedRecommendation = {
      recommendation,
      reasoning,
      keyStatsUsed: all.flatMap((b) => this.keyStatsFor(b, args.scoring)),
      confidence: Math.round(confidence),
      sourceTimestamps: this.sourceTimestamps(all),
      missingDataWarning: this.missingWarning(all, [...args.give, ...args.get]),
    };
    await this.persist("trade", args.leagueId ?? null, [...args.give, ...args.get], grounded);
    return grounded;
  }

  // ---------------------------------------------------------------------------
  // WAIVERS
  // ---------------------------------------------------------------------------
  async waivers(args: {
    scoring: ScoringFormat;
    season: number;
    week: number;
    position?: Player["position"];
    limit?: number;
    leagueId?: string;
  }): Promise<GroundedRecommendation> {
    const limit = args.limit ?? 5;

    // Exclude players already rostered in the league (if a league is provided).
    const rostered = new Set<string>();
    if (args.leagueId) {
      const rosters = await this.store.getLeagueRosters(args.leagueId);
      for (const r of rosters) for (const id of r.playerIds) rostered.add(id);
    }

    const players = await this.store.getPlayers(args.position ? { position: args.position } : {});
    const candidates = players.filter((p) => !rostered.has(p.playerId));

    const bundles = (
      await Promise.all(candidates.map((p) => this.bundle(p.playerId, args.season, args.week)))
    ).filter((b): b is Bundle => b !== undefined);

    const ranked = bundles
      .map((b) => ({ b, value: this.valueOf(b, args.scoring).value }))
      .filter((x) => x.value !== null)
      .sort((a, b) => (b.value ?? 0) - (a.value ?? 0))
      .slice(0, limit);

    if (ranked.length === 0) {
      return this.empty("No available players with stored projections/stats to recommend.");
    }

    const top = ranked.map((r, i) => `${i + 1}. ${r.b.player.fullName} (${r.b.player.position}, ${r.value} pts)`);
    const recommendation = `Top waiver targets: ${ranked.map((r) => r.b.player.fullName).join(", ")}.`;
    const reasoning =
      `Ranked ${ranked.length} available ${args.position ?? "player"}(s) by stored ${args.scoring.toUpperCase()} value ` +
      `for ${args.season} week ${args.week}${args.leagueId ? " (excluding rostered players)" : ""}. ${top.join(" · ")}.`;

    const rankedBundles = ranked.map((r) => r.b);
    const confidence = clamp(50 + Math.min(ranked.length, limit) * 6, 5, 90);

    const grounded: GroundedRecommendation = {
      recommendation,
      reasoning,
      keyStatsUsed: rankedBundles.flatMap((b) => this.keyStatsFor(b, args.scoring)),
      confidence: Math.round(confidence),
      sourceTimestamps: this.sourceTimestamps(rankedBundles),
      missingDataWarning:
        candidates.length > bundles.length
          ? `${candidates.length - bundles.length} candidate(s) skipped due to missing records.`
          : null,
    };
    await this.persist("waiver", args.leagueId ?? null, rankedBundles.map((b) => b.player.playerId), grounded);
    return grounded;
  }

  private empty(warning: string): GroundedRecommendation {
    return {
      recommendation: "No recommendation — insufficient data.",
      reasoning: "The recommendation engine only uses stored data and found nothing to evaluate.",
      keyStatsUsed: [],
      confidence: 0,
      sourceTimestamps: {},
      missingDataWarning: warning,
    };
  }
}
