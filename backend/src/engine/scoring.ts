import type { LeagueSettings, PlayerMetrics, Position } from "../types/playerMetrics.js";

export const clamp = (v: number, lo = 0, hi = 100): number =>
  Math.max(lo, Math.min(hi, v));

export const pct = (v: number): string => `${Math.round(v * 100)}%`;

/** PPR receptions boost pass-catchers; standard rewards volume-light TD scorers. */
export function formatWeight(pos: Position, league: LeagueSettings): number {
  const isPassCatcher = pos === "WR" || pos === "TE";
  if (league.scoring === "ppr") return isPassCatcher ? 1.06 : 1.0;
  if (league.scoring === "standard") return isPassCatcher ? 0.94 : 1.03;
  return 1.0; // half_ppr
}

/** Core 0..100 valuation used by every recommendation type. */
export function playerValue(m: PlayerMetrics, league: LeagueSettings): number {
  const ptsScore = clamp(m.projectedPoints * 4);
  const opportunity = clamp(
    m.targetShare * 100 * 1.1 + m.snapShare * 100 * 0.55 + m.redZoneUsage * 100 * 0.8,
  );

  let value =
    0.5 * ptsScore +
    0.22 * opportunity +
    0.15 * m.breakoutScore -
    0.1 * m.regressionScore +
    0.08 * (m.epaTeamContext - 50);

  // League context adjustments.
  value *= formatWeight(m.position, league);
  if (league.superflex && m.position === "QB") value += 10;

  if (league.dynasty) {
    value += (m.breakoutScore - m.regressionScore) * 0.12;
    if (m.age !== null) value += clamp((26 - m.age) * 1.5, -12, 12);
  }

  // Availability.
  if (m.injuryStatus === "Out" || m.injuryStatus === "IR") value *= 0.15;
  else if (m.injuryStatus === "Doubtful") value *= 0.55;
  else if (m.injuryStatus === "Questionable") value *= 0.9;

  return clamp(value);
}

/** Win-now leans on near-term projected points and low regression risk. */
export function winNowScore(m: PlayerMetrics): number {
  return clamp(m.projectedPoints * 3.5 + (50 - m.regressionScore) * 0.5);
}

/** Future value leans on breakout upside and youth. */
export function futureScore(m: PlayerMetrics): number {
  const youth = m.age !== null ? clamp((27 - m.age) * 6, 0, 36) : 18;
  return clamp(m.breakoutScore * 0.6 + youth + (50 - m.regressionScore) * 0.2);
}

/** Confidence in a recommendation: metric quality + how decisive the gap is. */
export function recommendationConfidence(m: PlayerMetrics, decisiveness: number): number {
  return clamp(0.7 * m.confidenceScore + 0.3 * clamp(decisiveness));
}

/** Number of starters at a position implied by league roster slots (incl. FLEX share). */
export function startersAtPosition(pos: Position, league: LeagueSettings): number {
  const slots = league.rosterSlots;
  let count = slots[pos] ?? 0;
  if (pos === "RB" || pos === "WR" || pos === "TE") {
    count += (slots.FLEX ?? 0) / 3; // FLEX split across RB/WR/TE
  }
  if (pos === "QB") count += slots.SUPERFLEX ?? (league.superflex ? 1 : 0);
  return count;
}
