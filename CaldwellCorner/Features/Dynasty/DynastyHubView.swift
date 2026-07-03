import SwiftUI

struct DynastyHubView: View {
    @EnvironmentObject var state: AppState
    @State private var tab: Tab = .rookies
    enum Tab: String, CaseIterable { case rookies = "Rookies", picks = "Pick Values", ageCurve = "Age Curve" }

    var body: some View {
        VStack(spacing: 0) {
            DSSegmented(items: Tab.allCases, title: { $0.rawValue }, selection: $tab)
                .padding(Theme.Spacing.lg)

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    switch tab {
                    case .rookies: rookies
                    case .picks: picks
                    case .ageCurve: ageCurve
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .screenBackground()
        .navigationTitle("Dynasty Hub")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rookies: some View {
        ForEach(state.rookies) { r in
            HStack(spacing: Theme.Spacing.md) {
                Text("\(r.rookieRank)").dsNumeric(15, color: Theme.Colors.accentSecondary).frame(width: 24)
                PlayerAvatar(name: r.name, position: r.position.rawValue, size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.name).dsCardTitle().lineLimit(1)
                    HStack(spacing: 6) {
                        PositionBadge(position: r.position.rawValue, compact: true)
                        Text(r.college).dsCaption()
                    }
                    Text("Comp: \(r.comp)").font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
                }
                Spacer()
                GradeRing(score: r.dynastyValue, size: 40)
            }
            .card(padding: Theme.Spacing.md)
        }
    }

    private var picks: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Future pick trade values. Use these to balance any trade involving draft capital.")
                .dsCallout().frame(maxWidth: .infinity, alignment: .leading)
            ForEach(state.pickValues) { pick in
                HStack {
                    Text(pick.label).dsCardTitle()
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Colors.surfaceElevated).frame(height: 7)
                            Capsule().fill(Theme.Colors.accent).frame(width: geo.size.width * CGFloat(pick.value / 80), height: 7)
                        }
                    }.frame(height: 7).frame(maxWidth: 120)
                    Text("\(Int(pick.value))").dsNumeric(15, color: Theme.Colors.accent).frame(width: 36, alignment: .trailing)
                }
                .card(padding: Theme.Spacing.md)
            }
        }
    }

    private var ageCurve: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Production peaks and decline windows by position. Buy ascending players, sell before the cliff.")
                .dsCallout()
            ForEach([("RB", "22-26", "27", Theme.Colors.position("RB")),
                     ("WR", "24-29", "30", Theme.Colors.position("WR")),
                     ("TE", "25-30", "31", Theme.Colors.position("TE")),
                     ("QB", "26-34", "36", Theme.Colors.position("QB"))], id: \.0) { pos, peak, cliff, color in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        PositionBadge(position: pos)
                        Text("Peak \(peak)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Text("Cliff ~\(cliff)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.negative)
                    }
                    AgeCurveBar(color: color)
                }
                .card(padding: Theme.Spacing.md)
            }
        }
    }
}

struct AgeCurveBar: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width, h = geo.size.height
                path.move(to: CGPoint(x: 0, y: h * 0.8))
                path.addCurve(to: CGPoint(x: w * 0.5, y: h * 0.1),
                              control1: CGPoint(x: w * 0.2, y: h * 0.6),
                              control2: CGPoint(x: w * 0.35, y: h * 0.1))
                path.addCurve(to: CGPoint(x: w, y: h * 0.9),
                              control1: CGPoint(x: w * 0.7, y: h * 0.1),
                              control2: CGPoint(x: w * 0.85, y: h * 0.7))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(height: 50)
    }
}
