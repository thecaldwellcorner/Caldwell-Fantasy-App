import SwiftUI

struct WaiverView: View {
    @EnvironmentObject var state: AppState
    @State private var faabBudget = 100.0

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("FAAB Budget Remaining").dsCallout().foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text("$\(Int(faabBudget))").dsNumeric(15, color: Theme.Colors.accent)
                    }
                    Slider(value: $faabBudget, in: 0...100, step: 1).tint(Theme.Colors.accent)
                }
                .glassCard(radius: 18)

                ForEach(state.waivers.sorted { $0.priority < $1.priority }) { target in
                    WaiverCard(target: target, budget: faabBudget, locked: target.isPremium && !state.isPremium)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Waiver Assistant")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WaiverCard: View {
    let target: WaiverTarget
    let budget: Double
    let locked: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle().fill(Theme.Colors.surfaceElevated).frame(width: 32, height: 32)
                    Text("\(target.priority)").dsNumeric(14, color: Theme.Colors.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(target.playerName).dsCardTitle().lineLimit(1)
                        if locked { PremiumBadge() }
                    }
                    HStack(spacing: 6) {
                        PositionBadge(position: target.position.rawValue, compact: true)
                        Text("\(target.team) · \(Int(target.rosteredPct))% rostered").dsCaption()
                    }
                }
                Spacer()
                VStack(spacing: 1) {
                    Text("$\(Int(Double(target.faabBidPct) / 100.0 * budget))").dsNumeric(18, color: Theme.Colors.accent)
                    DSEyebrow(text: "Bid")
                }
            }
            Text(locked ? "Unlock full waiver analysis with Premium." : target.reason)
                .dsCallout()
                .foregroundStyle(locked ? Theme.Colors.textTertiary : Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassCard(radius: 18)
    }
}
