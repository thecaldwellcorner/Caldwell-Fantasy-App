import SwiftUI

struct PlayerDetailView: View {
    @EnvironmentObject var state: AppState
    let player: Player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                valueRow
                projections
                advancedMetrics
                dynastyProfile
                blurb
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    state.toggleWatchlist(player.id)
                } label: {
                    Image(systemName: state.watchlist.contains(player.id) ? "star.fill" : "star")
                        .foregroundStyle(Theme.Colors.accentSecondary)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.lg) {
            PlayerAvatar(name: player.name, position: player.position.rawValue, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text(player.name).dsScreenTitle()
                HStack(spacing: 6) {
                    PositionBadge(position: player.position.rawValue)
                    Text("\(player.team) · #\(player.overallRank) OVR").dsCallout()
                }
                HStack(spacing: 6) {
                    statusPill
                    TrendIndicator(value: player.rankTrend)
                }
            }
            Spacer()
        }
    }

    private var statusPill: some View {
        Group {
            if player.injuryStatus.isConcern {
                Tag(text: player.injuryStatus.rawValue, color: Theme.Colors.warning, filled: true)
            } else {
                Tag(text: player.injuryStatus.rawValue, color: Theme.Colors.textSecondary)
            }
        }
    }

    private var valueRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            MetricChip(label: "ADP", value: String(format: "%.1f", player.adp))
            MetricChip(label: "Age", value: "\(player.age)")
            MetricChip(label: "Bye", value: "\(player.byeWeek)")
            MetricChip(label: "PPR", value: String(format: "%.0f", player.fantasyPointsPPR))
        }
    }

    private var projections: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "AI Projections")
            HStack(spacing: Theme.Spacing.md) {
                projColumn("Weekly", player.projWeekly)
                projColumn("Season", player.projSeason)
                projColumn("ROS", player.projRestOfSeason)
            }
            // floor/ceiling bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Floor \(Int(player.floor))")
                    Spacer()
                    Text("Median \(Int(player.projWeekly))")
                    Spacer()
                    Text("Ceiling \(Int(player.ceiling))")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
                Capsule().fill(Theme.Colors.accent.opacity(0.9)).frame(height: 6)
            }
            .card(padding: Theme.Spacing.md)

            HStack(spacing: Theme.Spacing.sm) {
                MetricChip(label: "Breakout", value: "\(Int(player.breakoutProbability))%", tint: Theme.Colors.positive)
                MetricChip(label: "Regress", value: "\(Int(player.regressionProbability))%", tint: Theme.Colors.warning)
                MetricChip(label: "Bust", value: "\(Int(player.bustProbability))%", tint: Theme.Colors.negative)
            }
        }
    }

    private func projColumn(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", value)).dsNumeric(20, color: Theme.Colors.accent)
            DSEyebrow(text: label)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
    }

    @ViewBuilder private var advancedMetrics: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Advanced Metrics", subtitle: state.isPremium ? nil : "Premium")
            if state.isPremium {
                let m = player.metrics
                VStack(spacing: 0) {
                    if player.position != .qb {
                        metricBar("Snap %", m.snapPct, max: 100)
                        metricBar("Target Share", m.targetShare, max: 35)
                        metricBar("Route Participation", m.routeParticipation, max: 100)
                        metricBar("Yards / Route Run", m.yardsPerRouteRun, max: 3, fmt: "%.2f")
                        metricBar("Red Zone Share", m.redZoneShare, max: 35)
                    }
                    metricBar("EPA / Play", m.epaPerPlay, max: 0.3, fmt: "%.2f")
                    metricBar("Success Rate", m.successRate, max: 60)
                    metricBar("Expected FP", m.expectedPoints, max: 25, fmt: "%.1f")
                    metricBar("RAS", m.ras, max: 10, fmt: "%.1f")
                }
                .card(padding: Theme.Spacing.md)
            } else {
                LockedMetricsCard()
            }
        }
    }

    private func metricBar(_ label: String, _ value: Double, max: Double, fmt: String = "%.0f") -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).dsCallout()
                Spacer()
                Text(String(format: fmt, value)).dsNumeric(13)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Colors.surfaceElevated).frame(height: 6)
                    Capsule().fill(Theme.Colors.position(player.position.rawValue))
                        .frame(width: geo.size.width * CGFloat(min(1, value / max)), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 6)
    }

    private var dynastyProfile: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Value Profile")
            HStack(spacing: Theme.Spacing.lg) {
                GradeRing(score: player.redraftValue, size: 70, label: "REDRAFT")
                GradeRing(score: player.dynastyValue, size: 70, label: "DYNASTY")
                GradeRing(score: player.keeperValue, size: 70, label: "KEEPER")
            }
            .frame(maxWidth: .infinity)
            .card()

            VStack(alignment: .leading, spacing: 6) {
                detailRow("College", player.college)
                detailRow("Draft Capital", player.draftCapital)
                detailRow("Breakout Age", String(format: "%.1f", player.metrics.breakoutAge))
                detailRow("College Dominator", String(format: "%.0f%%", player.metrics.collegeDominator))
                detailRow("Games Played", "\(player.gamesPlayed)")
            }
            .card(padding: Theme.Spacing.md)
        }
    }

    private func detailRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).dsCallout()
            Spacer()
            Text(v).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.vertical, 5)
    }

    private var blurb: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Scouting Report")
            Text(player.blurb).dsBody().fixedSize(horizontal: false, vertical: true).card()
        }
    }
}

struct LockedMetricsCard: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.fill").font(.system(size: 24)).foregroundStyle(Theme.Colors.accentSecondary)
            Text("Advanced metrics are Premium").dsCardTitle()
            Text("YPRR, target share, EPA, RAS and more.").dsCaption()
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}
