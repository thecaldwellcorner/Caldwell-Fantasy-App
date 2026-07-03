import SwiftUI

struct BettingCenterView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "location.fill").font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                    Text("Sportsbook lines shown where legal in your region.").dsCaption()
                    Spacer()
                }
                .card(padding: Theme.Spacing.md)

                ForEach(state.bettingProps) { prop in BettingPropCard(prop: prop) }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Betting Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BettingPropCard: View {
    let prop: BettingProp
    private func oddsString(_ v: Int) -> String { v >= 0 ? "+\(v)" : "\(v)" }
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                PlayerAvatar(name: prop.playerName, position: prop.position.rawValue, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(prop.playerName).dsCardTitle().lineLimit(1)
                    Text(prop.market).dsCaption()
                }
                Spacer()
                Text(prop.sportsbook).font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
            }
            HStack(spacing: Theme.Spacing.sm) {
                lineButton("Over \(String(format: "%g", prop.line))", odds: oddsString(prop.overOdds), highlight: prop.aiPick == "Over")
                lineButton("Under \(String(format: "%g", prop.line))", odds: oddsString(prop.underOdds), highlight: prop.aiPick == "Under")
            }
            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "AI Pick", value: prop.aiPick, tint: Theme.Colors.accent)
                MetricChip(label: "EV", value: String(format: "+%.1f%%", prop.expectedValue), tint: Theme.Colors.positive)
                MetricChip(label: "Conf", value: "\(Int(prop.confidence))%")
            }
        }
        .card()
    }
    private func lineButton(_ label: String, odds: String, highlight: Bool) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(highlight ? .black : Theme.Colors.textPrimary)
            Text(odds).dsNumeric(14, color: highlight ? .black : Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(highlight ? Theme.Colors.accent : Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
}
