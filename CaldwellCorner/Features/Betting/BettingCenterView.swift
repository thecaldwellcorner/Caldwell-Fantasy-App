import SwiftUI

struct BettingCenterView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "location.fill").foregroundStyle(Theme.Colors.info)
                    Text("Sportsbook lines shown where legal in your region.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Spacer()
                }
                .card(padding: Theme.Spacing.md)

                ForEach(state.bettingProps) { prop in
                    BettingPropCard(prop: prop)
                }
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
                    Text(prop.playerName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(prop.market)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Text(prop.sportsbook)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            HStack(spacing: Theme.Spacing.sm) {
                lineButton("Over \(String(format: "%g", prop.line))", odds: oddsString(prop.overOdds), highlight: prop.aiPick == "Over")
                lineButton("Under \(String(format: "%g", prop.line))", odds: oddsString(prop.underOdds), highlight: prop.aiPick == "Under")
            }
            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "AI Pick", value: prop.aiPick, tint: Theme.Colors.accent)
                MetricChip(label: "EV", value: String(format: "+%.1f%%", prop.expectedValue), tint: Theme.Colors.positive)
                MetricChip(label: "Conf", value: "\(Int(prop.confidence))%", tint: Theme.Colors.info)
            }
        }
        .card()
    }
    private func lineButton(_ label: String, odds: String, highlight: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
            Text(odds).font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(highlight ? .black : Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(highlight ? Theme.Colors.accent : Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }
}
