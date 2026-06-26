import SwiftUI

struct StartSitView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Text("AI-driven lineup recommendations using matchups, Vegas lines, weather and usage trends.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(state.startSit) { advice in
                    StartSitCard(advice: advice)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Start / Sit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StartSitCard: View {
    let advice: StartSitAdvice
    private var recColor: Color {
        switch advice.recommendation {
        case "Start": return Theme.Colors.positive
        case "Sit": return Theme.Colors.negative
        default: return Theme.Colors.accentSecondary
        }
    }
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                PlayerAvatar(name: advice.playerName, position: advice.position.rawValue, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(advice.playerName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    HStack(spacing: 6) {
                        PositionBadge(position: advice.position.rawValue, compact: true)
                        Text("\(advice.team) \(advice.opponent)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(advice.recommendation.uppercased())
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(recColor)
                        .clipShape(Capsule())
                    Text("\(Int(advice.confidence))% conf")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "Proj", value: String(format: "%.1f", advice.projection))
                MetricChip(label: "Matchup", value: advice.matchupGrade, tint: Theme.Colors.info)
                MetricChip(label: "O/U", value: String(format: "%.0f", advice.vegasTotal))
                MetricChip(label: "Weather", value: advice.weather)
            }
            Text(advice.reasoning)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }
}
