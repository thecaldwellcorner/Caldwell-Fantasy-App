import Foundation

/// Builds grounded `PlayerMetrics` from the player dataset + a team-context
/// table. In production these come from the backend ingestion pipeline
/// (Sleeper + nflverse); here they are derived deterministically so the engine
/// and AI assistant operate on real, consistent advanced metrics.
enum MockMetrics {

    struct TeamContext {
        var epa: Double; var oline: Int; var implied: Double
        var spread: Double; var proe: Double; var schedule: Double
    }

    private static let teams: [String: TeamContext] = [
        "KC": .init(epa: 0.18, oline: 8, implied: 25.5, spread: -6, proe: 0.02, schedule: 52),
        "BUF": .init(epa: 0.17, oline: 12, implied: 26.0, spread: -7, proe: 0.03, schedule: 48),
        "DET": .init(epa: 0.20, oline: 3, implied: 27.0, spread: -6, proe: -0.01, schedule: 50),
        "MIA": .init(epa: 0.14, oline: 18, implied: 24.5, spread: -3, proe: 0.05, schedule: 47),
        "CIN": .init(epa: 0.15, oline: 22, implied: 24.0, spread: -2.5, proe: 0.06, schedule: 49),
        "SF": .init(epa: 0.19, oline: 6, implied: 25.0, spread: -5, proe: -0.03, schedule: 53),
        "DAL": .init(epa: 0.12, oline: 10, implied: 23.5, spread: -3, proe: 0.02, schedule: 55),
        "ATL": .init(epa: 0.08, oline: 9, implied: 23.0, spread: -1.5, proe: -0.02, schedule: 45),
        "BAL": .init(epa: 0.16, oline: 14, implied: 25.0, spread: -4, proe: -0.05, schedule: 50),
        "NYJ": .init(epa: 0.02, oline: 20, implied: 19.5, spread: 1, proe: 0.04, schedule: 58),
        "LAR": .init(epa: 0.10, oline: 16, implied: 23.5, spread: -1, proe: 0.03, schedule: 50),
        "JAX": .init(epa: 0.00, oline: 19, implied: 21.0, spread: 1.5, proe: 0.02, schedule: 60),
        "ARI": .init(epa: 0.06, oline: 24, implied: 22.5, spread: 2, proe: 0.01, schedule: 52),
        "CHI": .init(epa: 0.04, oline: 21, implied: 21.5, spread: 1, proe: 0.03, schedule: 49),
        "HOU": .init(epa: 0.13, oline: 17, implied: 24.0, spread: -3, proe: 0.04, schedule: 51),
        "MIN": .init(epa: 0.11, oline: 15, implied: 23.5, spread: -2, proe: 0.05, schedule: 50),
        "IND": .init(epa: 0.07, oline: 11, implied: 22.5, spread: -1, proe: -0.01, schedule: 53),
        "LV": .init(epa: 0.01, oline: 23, implied: 20.5, spread: 2.5, proe: 0.02, schedule: 55),
        "WAS": .init(epa: 0.12, oline: 13, implied: 24.0, spread: -2, proe: 0.03, schedule: 48),
        "NYG": .init(epa: -0.03, oline: 26, implied: 19.0, spread: 3, proe: 0.05, schedule: 57),
        "PHI": .init(epa: 0.15, oline: 5, implied: 25.5, spread: -5, proe: -0.04, schedule: 51),
    ]

    private static let neutral = TeamContext(epa: 0.02, oline: 16, implied: 22.0,
                                             spread: 0, proe: 0.0, schedule: 50)

    private static func clamp(_ v: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double {
        max(lo, min(hi, v))
    }

    /// Players whose live data is intentionally unavailable (demonstrates the
    /// "Current data unavailable" guardrail end-to-end).
    private static let missingDataPlayers: Set<String> = ["Jonathon Brooks"]

    static let all: [PlayerMetrics] = MockPlayers.all.map { build(from: $0) }

    private static func build(from p: Player) -> PlayerMetrics {
        let ctx = teams[p.team] ?? neutral
        let a = p.metrics
        let isPass = p.position == .wr || p.position == .te
        let isRB = p.position == .rb

        let targetShare = a.targetShare / 100
        let snapShare = a.snapPct / 100
        let realizedPerGame = p.fantasyPointsPPR / Double(max(1, p.gamesPlayed))
        let matchupEPAAllowed = (50 - ctx.schedule) / 150

        let missing = missingDataPlayers.contains(p.name)

        if missing {
            // Sparse row: identity only, flagged so the engine refuses to score it.
            return PlayerMetrics(
                playerId: p.id.uuidString, name: p.name, position: p.position, team: p.team,
                age: p.age, season: 2024, week: 7,
                targetShare: 0, targetsPerRouteRun: 0, yardsPerRouteRun: 0, routeParticipation: 0,
                airYardsShare: 0, firstReadShare: 0, redZoneTargets: 0, endZoneTargets: 0,
                rushShare: 0, goalLineShare: 0, explosivePlayRate: 0, missedTacklesForced: 0,
                yardsAfterContact: 0, expectedFantasyPoints: 0, fantasyPointsOverExpected: 0,
                snapShare: 0, injuryStatus: p.injuryStatus,
                teamPassRateOverExpected: ctx.proe, teamEPAperPlay: ctx.epa,
                offensiveLineRank: ctx.oline, impliedTeamTotal: ctx.implied, spread: ctx.spread,
                matchupEPAAllowed: matchupEPAAllowed, scheduleDifficulty: ctx.schedule,
                regressionScore: 50, breakoutScore: p.breakoutProbability, confidenceScore: 18,
                dataLastUpdated: Date().addingTimeInterval(-3600 * 5),
                dataSources: ["Sleeper"], hasCurrentData: false)
        }

        return PlayerMetrics(
            playerId: p.id.uuidString, name: p.name, position: p.position, team: p.team,
            age: p.age, season: 2024, week: 7,
            targetShare: round3(targetShare),
            targetsPerRouteRun: a.targetsPerRouteRun,
            yardsPerRouteRun: a.yardsPerRouteRun,
            routeParticipation: round3(a.routeParticipation / 100),
            airYardsShare: round3(isPass ? clamp(targetShare * 1.05 + (a.yardsPerRouteRun - 1.5) * 0.03, 0, 0.6) : clamp(targetShare * 0.5, 0, 0.3)),
            firstReadShare: round3(clamp(targetShare * 0.92, 0, 0.6)),
            redZoneTargets: isPass ? Int((a.redZoneShare / 100 * 22).rounded()) : Int((a.redZoneShare / 100 * 6).rounded()),
            endZoneTargets: isPass ? Int((a.redZoneShare / 100 * 9).rounded()) : Int((a.redZoneShare / 100 * 3).rounded()),
            rushShare: round3(isRB ? clamp(snapShare * 0.85, 0, 0.95) : (p.position == .qb ? 0.05 : 0)),
            goalLineShare: round3(isRB ? clamp(a.redZoneShare / 100, 0, 0.9) : 0),
            explosivePlayRate: round3(clamp(0.06 + (a.yardsPerRouteRun > 0 ? (a.yardsPerRouteRun - 1.5) * 0.02 : a.epaPerPlay * 0.1), 0, 0.3)),
            missedTacklesForced: isRB ? Int((a.successRate * 0.6).rounded()) : Int((a.successRate * 0.1).rounded()),
            yardsAfterContact: round2(isRB ? max(0, 2.0 + a.epaPerPlay * 4 + (a.ras - 7) * 0.1) : 0),
            expectedFantasyPoints: round1(a.expectedPoints),
            fantasyPointsOverExpected: round1(realizedPerGame - a.expectedPoints),
            snapShare: round3(snapShare),
            injuryStatus: p.injuryStatus,
            teamPassRateOverExpected: ctx.proe,
            teamEPAperPlay: ctx.epa,
            offensiveLineRank: ctx.oline,
            impliedTeamTotal: ctx.implied,
            spread: ctx.spread,
            matchupEPAAllowed: round3(matchupEPAAllowed),
            scheduleDifficulty: ctx.schedule,
            regressionScore: p.regressionProbability,
            breakoutScore: p.breakoutProbability,
            confidenceScore: clamp(55 + Double(p.gamesPlayed) * 5 + (snapShare > 0 ? 8 : 0) + ((a.yardsPerRouteRun > 0 || p.position == .qb) ? 7 : 0), 0, 100),
            dataLastUpdated: Date().addingTimeInterval(-3600 * 4),
            dataSources: ["Sleeper", "nflverse / nflfastR", "Caldwell Projection Model"],
            hasCurrentData: true)
    }

    private static func round1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
    private static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }
    private static func round3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
}
