import type { LeagueSettings, PlayerMetrics, Position } from "../types/playerMetrics.js";
import type {
  DraftRecommendation,
  RankedRecommendation,
  StartSitRecommendation,
  TradeRecommendation,
  WaiverRecommendation,
} from "../types/recommendations.js";
import {
  clamp,
  futureScore,
  pct,
  playerValue,
  recommendationConfidence,
  startersAtPosition,
  winNowScore,
} from "./scoring.js";

/**
 * The AI recommendation engine. Consumes normalized PlayerMetrics (sourced from
 * Sleeper + nflverse and stored in the database) plus league settings, and
 * produces start/sit, trade, waiver and draft recommendations — each with a
 * score, confidence rating and plain-English reasoning.
 *
 * It is deterministic and fully grounded in the stored metrics (no fabricated
 * stats), matching the PRD's RAG / anti-hallucination requirement.
 */
export class RecommendationEngine {
  constructor(private readonly league: LeagueSettings) {}

  // ---------------------------------------------------------------------------
  // START / SIT
  // ---------------------------------------------------------------------------
  startSit(players: PlayerMetrics[]): StartSitRecommendation[] {
    const scored = players.map((m) => {
      const value = playerValue(m, this.league);
      // Matchup nudges the weekly call up or down.
      const matchupAdj = (50 - m.matchupDifficulty) / 5; // ~ -10..+10
      const score = clamp(value + matchupAdj);
      return { m, value, score };
    });

    const avg = mean(scored.map((s) => s.score));

    return scored
      .map(({ m, score }) => {
        let verdict: StartSitRecommendation["verdict"];
        if (m.injuryStatus === "Out" || m.injuryStatus === "IR") verdict = "Sit";
        else if (score >= 65) verdict = "Start";
        else if (score >= 48) verdict = "Flex";
        else verdict = "Sit";

        const confidence = recommendationConfidence(m, Math.abs(score - avg) * 2.5);
        return {
          kind: "start_sit" as const,
          playerId: m.playerId,
          name: m.name,
          position: m.position,
          verdict,
          projectedPoints: m.projectedPoints,
          score: round(score),
          confidence: round(confidence),
          reasoning: this.startSitReasoning(m, verdict),
        };
      })
      .sort((a, b) => b.score - a.score);
  }

  private startSitReasoning(m: PlayerMetrics, verdict: string): string {
    const matchup =
      m.matchupDifficulty <= 40 ? "a favorable matchup" :
      m.matchupDifficulty >= 60 ? "a tough matchup" : "a neutral matchup";
    const usage = `${pct(m.targetShare)} target share and ${pct(m.snapShare)} snap share`;
    const reg =
      m.regressionScore >= 65 ? " Some TD-driven regression risk tempers the ceiling." :
      m.breakoutScore >= 65 ? " Trending usage points to further upside." : "";
    if (m.injuryStatus === "Out" || m.injuryStatus === "IR") {
      return `${m.name} is ${m.injuryStatus.toLowerCase()} — do not start. Pivot to a healthy option.`;
    }
    return `${verdict}: ${usage} with ${matchup} (difficulty ${Math.round(
      m.matchupDifficulty,
    )}/100). Projected ${m.projectedPoints} pts on ${pct(
      m.redZoneUsage,
    )} red-zone usage.${reg}`;
  }

  // ---------------------------------------------------------------------------
  // WAIVER
  // ---------------------------------------------------------------------------
  waiver(available: PlayerMetrics[]): WaiverRecommendation[] {
    const budget = this.league.faabBudget ?? 100;
    const scored = available
      .map((m) => {
        // Waivers reward emerging opportunity + breakout, discount injuries.
        const value = playerValue(m, this.league);
        const score = clamp(0.45 * value + 0.4 * m.breakoutScore + 0.15 * (m.snapShare * 100));
        return { m, score };
      })
      .sort((a, b) => b.score - a.score);

    return scored.map(({ m, score }, idx) => {
      const faabBidPct = clamp(Math.round(score * 0.6), 0, 100);
      const confidence = recommendationConfidence(m, score - 40);
      return {
        kind: "waiver" as const,
        playerId: m.playerId,
        name: m.name,
        position: m.position,
        priority: idx + 1,
        faabBidPct,
        score: round(score),
        confidence: round(confidence),
        reasoning:
          `Priority ${idx + 1}: ${pct(m.snapShare)} snap share and a ${Math.round(
            m.breakoutScore,
          )}/100 breakout score signal a rising role. ` +
          `Bid ~${faabBidPct}% of FAAB ($${Math.round((faabBidPct / 100) * budget)} of $${budget}).`,
      };
    });
  }

  // ---------------------------------------------------------------------------
  // DRAFT
  // ---------------------------------------------------------------------------
  draft(available: PlayerMetrics[]): DraftRecommendation[] {
    // Replacement level per position = value of the last startable starter
    // across the league, so VOR reflects positional scarcity.
    const byPos = new Map<Position, number[]>();
    for (const m of available) {
      const arr = byPos.get(m.position) ?? [];
      arr.push(playerValue(m, this.league));
      byPos.set(m.position, arr);
    }
    const replacement = new Map<Position, number>();
    for (const [pos, values] of byPos) {
      values.sort((a, b) => b - a);
      const starters = Math.max(1, Math.round(startersAtPosition(pos, this.league) * this.league.teamCount));
      replacement.set(pos, values[Math.min(values.length - 1, starters)] ?? 0);
    }

    return available
      .map((m) => {
        const value = playerValue(m, this.league);
        const repl = replacement.get(m.position) ?? 0;
        const vor = value - repl;
        const score = clamp(50 + vor); // VOR centered at the replacement line
        const confidence = recommendationConfidence(m, vor);
        return {
          kind: "draft" as const,
          playerId: m.playerId,
          name: m.name,
          position: m.position,
          valueOverReplacement: round(vor),
          score: round(score),
          confidence: round(confidence),
          reasoning:
            `${m.name} offers ${round(vor)} points of value over a replacement ${m.position} ` +
            `in this ${this.league.teamCount}-team ${this.league.scoring.toUpperCase()}${
              this.league.superflex ? " Superflex" : ""
            } league. ` +
            `Projected ${m.projectedPoints} pts with a ${Math.round(m.breakoutScore)}/100 breakout score.`,
        };
      })
      .sort((a, b) => b.valueOverReplacement - a.valueOverReplacement);
  }

  // ---------------------------------------------------------------------------
  // DYNASTY / KEEPER (long-horizon)
  // ---------------------------------------------------------------------------
  dynasty(players: PlayerMetrics[]): RankedRecommendation[] {
    // Dynasty leans heavily on long-term/future value.
    return this.rankLongHorizon(players, "dynasty", (m) => 0.3 * winNowScore(m) + 0.7 * futureScore(m));
  }

  keeper(players: PlayerMetrics[]): RankedRecommendation[] {
    // Keeper balances this season's production with next-year retention value.
    return this.rankLongHorizon(players, "keeper", (m) => 0.55 * winNowScore(m) + 0.45 * futureScore(m));
  }

  private rankLongHorizon(
    players: PlayerMetrics[],
    kind: "dynasty" | "keeper",
    rankScore: (m: PlayerMetrics) => number,
  ): RankedRecommendation[] {
    const scored = players
      .map((m) => {
        const winNow = winNowScore(m);
        const future = futureScore(m);
        const score = clamp(rankScore(m));
        const riskNum = m.regressionScore + (m.injuryStatus !== "Healthy" ? 15 : 0);
        const riskRating: RankedRecommendation["riskRating"] =
          riskNum < 35 ? "Low" : riskNum < 55 ? "Medium" : "High";
        return { m, winNow, future, score, riskRating };
      })
      .sort((a, b) => b.score - a.score);

    return scored.map(({ m, winNow, future, score, riskRating }, idx) => {
      const lean =
        future > winNow
          ? "long-term asset — youth and breakout upside drive the value"
          : "win-now asset — current production leads the value";
      const ageNote = m.age !== null ? ` Age ${m.age}.` : "";
      return {
        kind,
        playerId: m.playerId,
        name: m.name,
        position: m.position,
        rank: idx + 1,
        winNowValue: round(winNow),
        futureValue: round(future),
        riskRating,
        score: round(score),
        confidence: recommendationConfidence(m, score - 50),
        reasoning:
          `#${idx + 1} ${kind} value: ${m.name} grades as a ${lean} ` +
          `(win-now ${round(winNow)}, future ${round(future)}).${ageNote} Risk: ${riskRating}.`,
      };
    });
  }

  // ---------------------------------------------------------------------------
  // TRADE
  // ---------------------------------------------------------------------------
  trade(sideAGive: PlayerMetrics[], sideBGet: PlayerMetrics[]): TradeRecommendation {
    const sumValue = (xs: PlayerMetrics[]) =>
      xs.reduce((acc, m) => acc + playerValue(m, this.league), 0);

    const sideAValue = round(sumValue(sideAGive));
    const sideBValue = round(sumValue(sideBGet));

    const maxV = Math.max(sideAValue, sideBValue, 1);
    const fairnessScore = round(clamp(100 - (Math.abs(sideAValue - sideBValue) / maxV) * 100));

    const ratio = sideBValue / Math.max(sideAValue, 1);
    const tradeGrade = round(clamp(50 + (ratio - 1) * 70));

    const winNow = round(mean(sideBGet.map(winNowScore)) || 0);
    const future = round(mean(sideBGet.map(futureScore)) || 0);

    const avgReg = mean(sideBGet.map((m) => m.regressionScore)) || 0;
    const injuryFlag = sideBGet.some(
      (m) => m.injuryStatus !== "Healthy" && m.injuryStatus !== "Questionable",
    );
    const riskNum = avgReg + (injuryFlag ? 15 : 0);
    const riskRating: TradeRecommendation["riskRating"] =
      riskNum < 35 ? "Low" : riskNum < 55 ? "Medium" : "High";

    let verdict: TradeRecommendation["verdict"];
    if (tradeGrade >= 58) verdict = "Accept";
    else if (tradeGrade <= 43) verdict = "Decline";
    else verdict = "Fair";

    const confidence = round(
      clamp(
        0.6 * (mean([...sideAGive, ...sideBGet].map((m) => m.confidenceScore)) || 50) +
          0.4 * clamp(Math.abs(tradeGrade - 50) * 2),
      ),
    );

    return {
      kind: "trade",
      verdict,
      tradeGrade,
      fairnessScore,
      winNowScore: winNow,
      futureScore: future,
      riskRating,
      sideAValue,
      sideBValue,
      score: tradeGrade,
      confidence,
      reasoning: this.tradeReasoning(sideAGive, sideBGet, {
        sideAValue, sideBValue, winNow, future, riskRating, verdict,
      }),
    };
  }

  private tradeReasoning(
    give: PlayerMetrics[],
    get: PlayerMetrics[],
    s: {
      sideAValue: number; sideBValue: number; winNow: number; future: number;
      riskRating: string; verdict: string;
    },
  ): string {
    const giveNames = give.map((m) => m.name).join(", ") || "nothing";
    const getNames = get.map((m) => m.name).join(", ") || "nothing";
    const diff = s.sideBValue - s.sideAValue;
    const lean =
      Math.abs(diff) < 6
        ? "The values are essentially even, so it comes down to roster fit and timeline."
        : diff > 0
          ? "You acquire more total value, so this projects as a win for your side."
          : "You give up more total value, so the upside or roster fit needs to justify it.";
    const timeline =
      s.future > s.winNow
        ? "The package you receive skews toward the future — strong for a contender being built around youth and breakout upside."
        : "The package you receive skews win-now — strong if you're pushing for a title this season.";
    return `Give ${giveNames} to receive ${getNames}. ${lean} ${timeline} Risk is rated ${s.riskRating} based on injury status and regression risk.`;
  }
}

function mean(xs: number[]): number {
  return xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : 0;
}

const round = (v: number): number => Math.round(v * 10) / 10;
