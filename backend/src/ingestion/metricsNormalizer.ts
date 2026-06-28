import type { PlayerMetrics, Position } from "../types/playerMetrics.js";
import type {
  NflverseWeeklyStat,
  SleeperPlayer,
  TeamEpaContext,
} from "../datasources/types.js";

export const clamp = (v: number, lo = 0, hi = 100): number =>
  Math.max(lo, Math.min(hi, v));

const round1 = (v: number): number => Math.round(v * 10) / 10;

/**
 * Normalizes raw trusted-source data into the canonical PlayerMetrics model and
 * derives the projection / regression / breakout / confidence scores used by the
 * RecommendationEngine. All inputs come from Sleeper + nflverse — never scraped.
 */
export interface NormalizeInput {
  player: SleeperPlayer;
  weekly: NflverseWeeklyStat;
  /** Offensive EPA context for the player's team (optional). */
  teamContext?: TeamEpaContext;
  /** Defensive EPA the upcoming opponent allows vs this position (optional). */
  opponentDefenseEpaAllowed?: number;
}

/** Map team offensive EPA/play (~ -0.2..0.3) onto a 0..100 scale. */
export function epaToContextScore(offenseEpaPerPlay: number): number {
  return clamp(((offenseEpaPerPlay + 0.2) / 0.5) * 100);
}

/** Map opponent defensive EPA allowed onto a 0 (easy) .. 100 (hard) difficulty. */
export function epaToMatchupDifficulty(defenseEpaAllowed: number): number {
  // Lower EPA allowed by the defense = tougher matchup.
  return clamp(((0.2 - defenseEpaAllowed) / 0.5) * 100);
}

const injuryMultiplier: Record<PlayerMetrics["injuryStatus"], number> = {
  Healthy: 1,
  Questionable: 0.85,
  Doubtful: 0.4,
  Out: 0,
  IR: 0,
};

/**
 * Expected fantasy points from *opportunity only* (sustainable inputs).
 * Compared against realized points to gauge regression / breakout risk.
 */
export function expectedFromOpportunity(pos: Position, w: NflverseWeeklyStat): number {
  switch (pos) {
    case "WR":
    case "TE":
      return (
        w.targetShare * 38 +
        w.airYardsShare * 10 +
        w.redZoneTouches / Math.max(1, w.teamRedZonePlays) * 16 +
        snapShare(w) * 4
      );
    case "RB":
      return (
        snapShare(w) * 8 +
        (w.redZoneTouches / Math.max(1, w.teamRedZonePlays)) * 22 +
        w.targetShare * 18 +
        w.carries * 0.45
      );
    case "QB":
      return (
        w.passingYards * 0.04 +
        w.passingTds * 4 +
        w.rushingYards * 0.1 +
        w.rushingTds * 6 -
        w.interceptions
      );
    default:
      return w.fantasyPointsPpr;
  }
}

function snapShare(w: NflverseWeeklyStat): number {
  if (w.teamOffenseSnaps > 0) return clamp(w.offenseSnaps / w.teamOffenseSnaps, 0, 1);
  // Fallback: approximate from target share for pass-catchers.
  return clamp(w.targetShare * 3, 0, 1);
}

export function normalize(input: NormalizeInput): PlayerMetrics {
  const { player, weekly: w, teamContext, opponentDefenseEpaAllowed } = input;
  const position = (player.position ?? w.position ?? "WR") as Position;

  const redZoneUsage =
    w.teamRedZonePlays > 0 ? clamp(w.redZoneTouches / w.teamRedZonePlays, 0, 1) : 0;
  const snaps = snapShare(w);
  const routesRun = w.routes > 0 ? w.routes : Math.round(snaps * 35);

  const epaTeamContext = teamContext
    ? epaToContextScore(teamContext.offenseEpaPerPlay)
    : 50;
  const matchupDifficulty =
    opponentDefenseEpaAllowed !== undefined
      ? epaToMatchupDifficulty(opponentDefenseEpaAllowed)
      : 50;

  const efo = Math.max(0, expectedFromOpportunity(position, w));
  const realized = Math.max(0, w.fantasyPointsPpr);

  // Projection: blend sustainable opportunity with realized output, then adjust
  // for matchup, team context and injury availability.
  const matchupMult = 1 + (50 - matchupDifficulty) / 250; // ~0.8..1.2
  const teamMult = 0.9 + epaTeamContext / 500; // ~0.9..1.1
  const injuryMult = injuryMultiplier[player.injuryStatus];
  const projectedPoints = round1(
    (0.55 * efo + 0.45 * realized) * matchupMult * teamMult * injuryMult,
  );

  // Regression: realized far above opportunity (often TD-driven) → likely to fall.
  const diff = realized - efo;
  const tdRate =
    (w.receivingTds + w.rushingTds + w.passingTds) /
    Math.max(1, w.targets + w.carries + w.passingYards / 12);
  const regressionScore = clamp(50 + diff * 2.2 + tdRate * 40);

  // Breakout: strong/expanding opportunity not yet reflected in output, plus youth.
  const youthBonus = player.age !== null ? clamp((25 - player.age) * 4, 0, 20) : 8;
  const opportunityLevel = clamp(
    (w.targetShare * 100 + snaps * 100 + redZoneUsage * 100) / 2.4,
  );
  const breakoutScore = clamp(0.5 * opportunityLevel + (efo - realized) * 1.8 + youthBonus);

  // Confidence: data completeness + sample size − injury uncertainty.
  const fields = [w.targetShare, w.airYardsShare, snaps, redZoneUsage, w.fantasyPointsPpr];
  const completeness = fields.filter((v) => v > 0).length / fields.length;
  const sample = clamp(Math.max(routesRun / 30, w.carries / 18, w.offenseSnaps / 45), 0, 1);
  const injuryPenalty = player.injuryStatus === "Healthy" ? 0 : 18;
  const confidenceScore = clamp(40 + completeness * 30 + sample * 30 - injuryPenalty);

  return {
    playerId: player.playerId,
    name: player.fullName || w.playerName,
    position,
    team: player.team ?? w.team ?? "FA",
    age: player.age,
    season: w.season,
    week: w.week,
    targetShare: round3(w.targetShare),
    airYards: Math.round(w.receivingAirYards),
    routesRun,
    snapShare: round3(snaps),
    redZoneUsage: round3(redZoneUsage),
    epaTeamContext: round1(epaTeamContext),
    matchupDifficulty: round1(matchupDifficulty),
    injuryStatus: player.injuryStatus,
    projectedPoints,
    regressionScore: round1(regressionScore),
    breakoutScore: round1(breakoutScore),
    confidenceScore: round1(confidenceScore),
    updatedAt: new Date().toISOString(),
  };
}

const round3 = (v: number): number => Math.round(v * 1000) / 1000;
