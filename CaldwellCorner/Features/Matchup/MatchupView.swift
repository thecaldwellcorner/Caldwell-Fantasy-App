import SwiftUI

struct MatchupView: View {
    @EnvironmentObject var state: AppState

    private var model: MatchupModel { MatchupModel(state: state) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                scoreboard.appear()
                winBar.appear(delay: 0.03)
                boomBust.appear(delay: 0.06)
                positionBreakdown.appear(delay: 0.09)
                gameEnvironment.appear(delay: 0.12)
                aiSummary.appear(delay: 0.15)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var scoreboard: some View {
        let m = model
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            DSEyebrow(text: "Week \(m.week) Matchup")
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(m.userName).dsCallout()
                    BigScore(value: m.userScore, dimmed: false)
                }
                Spacer()
                ZStack {
                    Circle().fill(Theme.Colors.surfaceElevated).frame(width: 46, height: 46)
                        .overlay(Circle().strokeBorder(Theme.Colors.stroke, lineWidth: 1))
                    Text("VS").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.textTertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(m.oppName).dsCallout()
                    BigScore(value: m.oppScore, dimmed: true)
                }
            }
        }
    }

    private var winBar: some View {
        let m = model
        return VStack(spacing: 8) {
            HStack {
                Text("WIN \(m.winPct)%").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.positive)
                Spacer()
                Text("LOSE \(100 - m.winPct)%").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.textTertiary)
            }
            ProgressBar(fraction: Double(m.winPct) / 100, tint: Theme.Colors.accent)
        }
    }

    private var boomBust: some View {
        let m = model
        return HStack(spacing: Theme.Spacing.md) {
            highlightCard(tag: "Boom Player", tagColor: Theme.Colors.positive,
                          name: m.boomName, detail: m.boomDetail)
            highlightCard(tag: "Bust Risk", tagColor: Theme.Colors.negative,
                          name: m.bustName, detail: m.bustDetail)
        }
    }

    private func highlightCard(tag: String, tagColor: Color, name: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            DSEyebrow(text: tag, color: tagColor)
            Text(name).dsCardTitle().lineLimit(1)
            Text(detail).dsCaption().lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .strokeBorder(tagColor.opacity(0.45), lineWidth: 1))
    }

    private var positionBreakdown: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            DSEyebrow(text: "Position Breakdown")
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(model.rows) { row in PositionRow(row: row) }
            }
        }
    }

    private var gameEnvironment: some View {
        let m = model
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            DSEyebrow(text: "Game Environment")
            HStack(spacing: 0) {
                envCell("O/U", m.overUnder)
                envDivider
                envCell("Spread", m.spread)
                envDivider
                envCell("Temp", m.temp)
            }
            .padding(.vertical, Theme.Spacing.md)
            .glassCard(padding: 0, radius: 18)
        }
    }

    private var envDivider: some View { Rectangle().fill(Theme.Colors.stroke).frame(width: 1, height: 34) }
    private func envCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            DSEyebrow(text: label)
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var aiSummary: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.accent)
                DSEyebrow(text: "AI Summary", color: Theme.Colors.accent)
            }
            Text(model.summary).dsBody().fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
    }
}

// MARK: - Position row
struct PositionRow: View {
    let row: MatchupRow
    private var userWins: Bool { row.userProj >= row.oppProj }
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(row.slot)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 40, height: 26)
                .background(Theme.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(row.userName).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
                Text(row.oppName).dsCaption()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", row.userProj)).dsNumeric(14, color: Theme.Colors.positive)
                Text(String(format: "%.1f", row.oppProj)).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Theme.Colors.textTertiary)
            }
            Circle().fill(userWins ? Theme.Colors.accent : Theme.Colors.textTertiary.opacity(0.5)).frame(width: 7, height: 7)
        }
        .card(padding: Theme.Spacing.md)
    }
}

// MARK: - Model (derived from existing data)
struct MatchupRow: Identifiable {
    let id = UUID()
    let slot: String
    let userName: String
    let oppName: String
    let userProj: Double
    let oppProj: Double
}

private struct MatchupModel {
    let week: Int
    let userName: String
    let oppName: String
    let userScore: Double
    let oppScore: Double
    let winPct: Int
    let rows: [MatchupRow]
    let boomName: String
    let boomDetail: String
    let bustName: String
    let bustDetail: String
    let overUnder: String
    let spread: String
    let temp: String
    let summary: String

    @MainActor
    init(state: AppState) {
        let league = state.selectedLeague
        week = league?.currentWeek ?? 11
        let userTeam = league?.userTeam
        let opp = league?.standings.first(where: { !$0.isUser })
        userName = userTeam?.name ?? "My Team"
        oppName = opp?.name ?? "Opponent"

        func shortName(_ full: String) -> String {
            let parts = full.split(separator: " ")
            guard let first = parts.first?.first else { return full }
            return "\(first). \(parts.dropFirst().joined(separator: " "))"
        }

        // User starters (ordered QB, RB, RB, WR, WR, TE, FLEX)
        let roster = userTeam.map { state.rosterPlayers(for: $0) } ?? []
        let starterSlots = ["QB", "RB", "WR", "TE", "FLEX"]
        let starters = roster.filter { starterSlots.contains($0.slot) }
        let userIDs = Set(starters.map { $0.player.id })

        // Derived opponent lineup from the player pool (excludes user starters)
        func pool(_ p: Position) -> [Player] {
            state.players.filter { $0.position == p && !userIDs.contains($0.id) }
                .sorted { $0.overallRank < $1.overallRank }
        }
        var qbs = pool(.qb), rbs = pool(.rb), wrs = pool(.wr), tes = pool(.te)
        func nextOpp(for slot: String) -> Player? {
            switch slot {
            case "QB": return qbs.isEmpty ? nil : qbs.removeFirst()
            case "RB": return rbs.isEmpty ? nil : rbs.removeFirst()
            case "WR": return wrs.isEmpty ? nil : wrs.removeFirst()
            case "TE": return tes.isEmpty ? nil : tes.removeFirst()
            default:   // FLEX → best remaining RB/WR/TE
                let candidates = [rbs.first, wrs.first, tes.first].compactMap { $0 }
                guard let best = candidates.min(by: { $0.overallRank < $1.overallRank }) else { return nil }
                if best.position == .rb, !rbs.isEmpty { rbs.removeFirst() }
                else if best.position == .wr, !wrs.isEmpty { wrs.removeFirst() }
                else if !tes.isEmpty { tes.removeFirst() }
                return best
            }
        }
        func label(_ slot: String, _ counter: inout [String: Int]) -> String {
            if slot == "RB" || slot == "WR" {
                counter[slot, default: 0] += 1
                return "\(slot)\(counter[slot]!)"
            }
            return slot
        }
        var counters: [String: Int] = [:]
        var builtRows: [MatchupRow] = []
        var uSum = 0.0, oSum = 0.0
        for entry in starters {
            let opp = nextOpp(for: entry.slot)
            let oProj = opp?.projWeekly ?? max(6, entry.player.projWeekly - 2)
            uSum += entry.player.projWeekly
            oSum += oProj
            builtRows.append(MatchupRow(
                slot: label(entry.slot, &counters),
                userName: shortName(entry.player.name),
                oppName: shortName(opp?.name ?? "—"),
                userProj: entry.player.projWeekly,
                oppProj: oProj))
        }
        rows = builtRows
        userScore = (uSum * 10).rounded() / 10
        oppScore = (oSum * 10).rounded() / 10
        winPct = max(1, min(99, Int((50 + (uSum - oSum) * 1.7).rounded())))

        // Boom / bust from real player attributes
        let boom = starters.max(by: { $0.player.ceiling < $1.player.ceiling })?.player
        boomName = boom?.name ?? "—"
        boomDetail = boom.map { "Proj \(Int($0.ceiling))+ pt ceiling" } ?? "High upside"
        let bust = starters.min(by: { $0.player.floor < $1.player.floor })?.player
        bustName = bust?.name ?? "—"
        if let b = bust {
            bustDetail = b.injuryStatus.isConcern ? "\(b.injuryStatus.rawValue) · monitor status" : "Low \(Int(b.floor))-pt floor · volatile role"
        } else { bustDetail = "Volatile role" }

        // Game environment (synthesized for display)
        overUnder = String(format: "%.1f", ((userScore + oppScore) / 5).rounded() + 2)
        let favored = uSum >= oSum ? (userTeam?.name.prefix(3).uppercased() ?? "US") : (opp?.name.prefix(3).uppercased() ?? "OPP")
        spread = "\(favored) -\(String(format: "%.1f", abs(uSum - oSum) / 3))"
        temp = week >= 12 ? "28°F ❄️" : "64°F"

        let topRow = builtRows.max(by: { ($0.userProj - $0.oppProj) < ($1.userProj - $1.oppProj) })
        let edge = topRow.map { "\($0.userName) (\($0.slot))" } ?? "your stars"
        summary = "Strong win probability driven by your edge at \(edge). Your starters out-project the field by \(String(format: "%.1f", uSum - oSum)) points. Weather is the main swing factor — monitor game-time conditions before Sunday's lock."
    }
}
