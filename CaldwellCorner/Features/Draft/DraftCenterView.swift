import SwiftUI
import Combine

struct DraftCenterView: View {
    @EnvironmentObject var state: AppState
    @State private var drafted: Set<UUID> = []
    @State private var pickNumber = 1
    @State private var timeRemaining = 60
    @State private var timerRunning = false

    private var available: [Player] {
        state.players.filter { !drafted.contains($0.id) }.sorted { $0.adp < $1.adp }
    }
    private var topRecommendation: Player? { available.first }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                draftBoard
                if let rec = topRecommendation {
                    recommendationCard(rec)
                }
                tierBoard
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Draft Center")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard timerRunning, timeRemaining > 0 else { return }
            timeRemaining -= 1
        }
    }

    private var draftBoard: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mock Draft").dsSectionTitle()
                    Text("Pick \(pickNumber) · Round \((pickNumber - 1) / 12 + 1)").dsCaption()
                }
                Spacer()
                ZStack {
                    Circle().stroke(Theme.Colors.stroke, lineWidth: 5).frame(width: 54, height: 54)
                    Circle().trim(from: 0, to: CGFloat(timeRemaining) / 60)
                        .stroke(timeRemaining < 15 ? Theme.Colors.negative : Theme.Colors.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 54, height: 54)
                    Text("\(timeRemaining)").dsNumeric(18)
                }
            }
            HStack(spacing: Theme.Spacing.sm) {
                Button { timerRunning.toggle() } label: {
                    Label(timerRunning ? "Pause" : "Start Clock", systemImage: timerRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Theme.Colors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    drafted.removeAll(); pickNumber = 1; timeRemaining = 60; timerRunning = false
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(Theme.Colors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private func recommendationCard(_ player: Player) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("AI Draft Coach", systemImage: "brain.head.profile")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)
            HStack {
                PlayerAvatar(name: player.name, position: player.position.rawValue, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(player.name).dsCardTitle().lineLimit(1)
                    Text("Best available · ADP \(String(format: "%.1f", player.adp))").dsCaption()
                }
                Spacer()
                Button { draft(player) } label: {
                    Text("Draft").font(.system(size: 14, weight: .semibold)).foregroundStyle(.black)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Theme.Colors.accent).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("Value pick at \(player.position.rawValue) — addresses roster construction and positional scarcity at this stage.")
                .dsCaption()
        }
        .card()
    }

    private var tierBoard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Available", subtitle: "Tier-based board")
            ForEach(available.prefix(20)) { p in
                HStack(spacing: Theme.Spacing.md) {
                    Text(String(format: "%.0f", p.adp)).dsNumeric(12, color: Theme.Colors.textTertiary).frame(width: 26)
                    PlayerAvatar(name: p.name, position: p.position.rawValue, size: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.name).dsCardTitle().lineLimit(1)
                        HStack(spacing: 6) {
                            PositionBadge(position: p.position.rawValue, compact: true)
                            Text(p.team).dsCaption()
                        }
                    }
                    Spacer()
                    Button { draft(p) } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.Colors.accent)
                    }
                    .buttonStyle(.plain)
                }
                .card(padding: Theme.Spacing.md)
            }
        }
    }

    private func draft(_ player: Player) {
        drafted.insert(player.id)
        pickNumber += 1
        timeRemaining = 60
    }
}
