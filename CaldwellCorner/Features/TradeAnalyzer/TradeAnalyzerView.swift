import SwiftUI

struct TradeAnalyzerView: View {
    @EnvironmentObject var state: AppState
    @State private var sideA: [Player] = []
    @State private var sideB: [Player] = []
    @State private var picking: Side?
    @State private var result: TradeEvaluation?

    enum Side { case a, b }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Text("Build a trade to get a grade, fairness score and AI breakdown from your league's settings.")
                    .dsCallout()
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let league = state.selectedLeague {
                    HStack(spacing: 6) {
                        Image(systemName: league.platform.systemImage)
                        Text("\(league.name) · \(league.scoring.rawValue)\(league.isSuperflex ? " · SF" : "")")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                tradeSide(title: "You Give", players: $sideA, side: .a, tint: Theme.Colors.negative)
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textTertiary)
                tradeSide(title: "You Get", players: $sideB, side: .b, tint: Theme.Colors.positive)

                PrimaryButton(title: "Analyze Trade", systemImage: "wand.and.stars") {
                    withAnimation {
                        result = TradeEngine.evaluate(sideA: sideA, sideB: sideB, league: state.selectedLeague)
                    }
                }
                .disabled(sideA.isEmpty && sideB.isEmpty)
                .opacity(sideA.isEmpty && sideB.isEmpty ? 0.5 : 1)

                if let result {
                    TradeResultCard(result: result)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Trade Analyzer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $picking) { side in
            PlayerPickerView { player in
                if side == .a { sideA.append(player) } else { sideB.append(player) }
                result = nil
            }
        }
    }

    private func tradeSide(title: String, players: Binding<[Player]>, side: Side, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                DSEyebrow(text: title, color: tint)
                Spacer()
                let total = players.wrappedValue.map { ($0.dynastyValue) }.reduce(0, +)
                if !players.wrappedValue.isEmpty {
                    Text("Value \(Int(total))").dsCaption()
                }
            }
            ForEach(players.wrappedValue) { p in
                HStack {
                    PlayerAvatar(name: p.name, position: p.position.rawValue, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).dsCardTitle().lineLimit(1)
                        Text("\(p.position.rawValue) · \(p.team)").dsCaption()
                    }
                    Spacer()
                    Button {
                        players.wrappedValue.removeAll { $0.id == p.id }
                        result = nil
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(Theme.Colors.negative)
                    }
                }
                .padding(.vertical, 4)
            }
            Button { picking = side } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add player")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

extension TradeAnalyzerView.Side: Identifiable { var id: Int { self == .a ? 0 : 1 } }

struct TradeResultCard: View {
    let result: TradeEvaluation
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.lg) {
                GradeRing(score: result.tradeGrade, size: 80, label: "GRADE")
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.verdict).dsSectionTitle()
                    HStack(spacing: 4) {
                        Text("Risk").dsCaption()
                        Text(result.riskRating).font(.system(size: 12, weight: .semibold)).foregroundStyle(riskColor)
                    }
                }
                Spacer()
            }

            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "Fairness", value: "\(Int(result.fairnessScore))", tint: Theme.Colors.grade(result.fairnessScore))
                MetricChip(label: "Win Now", value: "\(Int(result.winNowScore))")
                MetricChip(label: "Future", value: "\(Int(result.futureScore))")
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("AI Breakdown", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
                Text(result.explanation).dsBody().fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }
    private var riskColor: Color {
        switch result.riskRating {
        case "Low": return Theme.Colors.positive
        case "Medium": return Theme.Colors.warning
        default: return Theme.Colors.negative
        }
    }
}

struct PlayerPickerView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    let onSelect: (Player) -> Void

    private var filtered: [Player] {
        let list = search.isEmpty ? state.players : state.players.filter { $0.name.localizedCaseInsensitiveContains(search) }
        return list.sorted { $0.overallRank < $1.overallRank }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(filtered) { p in
                        Button {
                            onSelect(p)
                            dismiss()
                        } label: {
                            PlayerRow(player: p)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search players")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.Colors.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
