import SwiftUI

struct InjuryCenterView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(state.injuries) { report in InjuryCard(report: report) }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Injury Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InjuryCard: View {
    let report: InjuryReport
    private var statusColor: Color {
        switch report.status {
        case .healthy: return Theme.Colors.positive
        case .questionable: return Theme.Colors.warning
        case .doubtful, .out, .ir: return Theme.Colors.negative
        }
    }
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                PlayerAvatar(name: report.playerName, position: report.position.rawValue, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.playerName).dsCardTitle().lineLimit(1)
                    HStack(spacing: 6) {
                        PositionBadge(position: report.position.rawValue, compact: true)
                        Text("\(report.team) · \(report.injury)").dsCaption()
                    }
                }
                Spacer()
                Tag(text: report.status.rawValue, color: statusColor, filled: true)
            }
            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "Practice", value: report.practiceReport)
                MetricChip(label: "Return", value: report.expectedReturn)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(report.fantasyImpact).dsCallout()
                if report.replacementSuggestion != "—" {
                    Label("Replacements: \(report.replacementSuggestion)", systemImage: "arrow.triangle.swap")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }
}
