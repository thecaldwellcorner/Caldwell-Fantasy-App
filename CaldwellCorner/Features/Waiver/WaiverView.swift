import SwiftUI

struct WaiverView: View {
    @EnvironmentObject var state: AppState
    @State private var faabBudget = 100.0

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("FAAB Budget Remaining")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                        Spacer()
                        Text("$\(Int(faabBudget))")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    Slider(value: $faabBudget, in: 0...100, step: 1)
                        .tint(Theme.Colors.accent)
                }
                .card()

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
                    Circle().fill(Theme.Colors.surfaceElevated).frame(width: 30, height: 30)
                    Text("\(target.priority)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.accentSecondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(target.playerName)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        if locked { PremiumBadge() }
                    }
                    HStack(spacing: 6) {
                        PositionBadge(position: target.position.rawValue, compact: true)
                        Text("\(target.team) · \(Int(target.rosteredPct))% rostered")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                Spacer()
                VStack(spacing: 0) {
                    Text("$\(Int(Double(target.faabBidPct) / 100.0 * budget))")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.Colors.accent)
                    Text("BID")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            if locked {
                Text("Unlock full waiver analysis with Premium.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(target.reason)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .card()
    }
}
