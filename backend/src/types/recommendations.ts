import type { Position } from "./playerMetrics.js";

export type RecommendationKind =
  | "start_sit"
  | "trade"
  | "waiver"
  | "draft"
  | "dynasty"
  | "keeper";

/** Shared shape: every recommendation has a score, confidence and reasoning. */
export interface BaseRecommendation {
  kind: RecommendationKind;
  /** 0..100 — strength of the recommendation. */
  score: number;
  /** 0..100 — how confident the engine is, given data quality + variance. */
  confidence: number;
  /** Human-readable, plain-English explanation grounded in the metrics. */
  reasoning: string;
}

export interface StartSitRecommendation extends BaseRecommendation {
  kind: "start_sit";
  playerId: string;
  name: string;
  position: Position;
  verdict: "Start" | "Flex" | "Sit";
  projectedPoints: number;
}

export interface WaiverRecommendation extends BaseRecommendation {
  kind: "waiver";
  playerId: string;
  name: string;
  position: Position;
  priority: number;
  /** Suggested FAAB bid as a percentage of remaining budget (0..100). */
  faabBidPct: number;
}

export interface DraftRecommendation extends BaseRecommendation {
  kind: "draft";
  playerId: string;
  name: string;
  position: Position;
  /** Value over replacement at the position, used for tiering. */
  valueOverReplacement: number;
}

export interface TradeRecommendation extends BaseRecommendation {
  kind: "trade";
  verdict: "Accept" | "Fair" | "Decline";
  /** Trade grade for the side receiving sideB (0..100). */
  tradeGrade: number;
  fairnessScore: number;
  winNowScore: number;
  futureScore: number;
  riskRating: "Low" | "Medium" | "High";
  sideAValue: number;
  sideBValue: number;
}

/** Long-horizon recommendation used by dynasty + keeper modes. */
export interface RankedRecommendation extends BaseRecommendation {
  kind: "dynasty" | "keeper";
  playerId: string;
  name: string;
  position: Position;
  rank: number;
  winNowValue: number;
  futureValue: number;
  riskRating: "Low" | "Medium" | "High";
}
