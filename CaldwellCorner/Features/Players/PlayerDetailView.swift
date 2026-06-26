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
                Text(player.name)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                HStack(spacing: 6) {
                    PositionBadge(position: player.position.rawValue)
                    Text("\(player.team) · #\(player.overallRank) OVR")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
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
        Text(player.injuryStatus.rawValue)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(player.injuryStatus.isConcern ? .black : Theme.Colors.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(player.injuryStatus.isConcern ? Theme.Colors.warning : Theme.Colors.surfaceElevated)
            .clipShape(Capsule())
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
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Colors.surfaceElevated).frame(height: 8)
                        Capsule()
                            .fill(LinearGradient(colors: [Theme.Colors.negative, Theme.Colors.accentSecondary, Theme.Colors.positive], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width, height: 8)
                    }
                }
                .frame(height: 8)
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
            Text(String(format: "%.1f", value))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.Colors.accent)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: Theme.Spacing.md)
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
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(String(format: fmt, value))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
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
            Text(k).font(.system(size: 13)).foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
            Text(v).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.vertical, 4)
    }

    private var blurb: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Scouting Report")
            Text(player.blurb)
                .font(.system(size: 14))
                .foregroundStyle(Theme.Colors.textSecondary)
                .card()
        }
    }
}

struct LockedMetricsCard: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24))
                .foregroundStyle(Theme.Colors.accentSecondary)
            Text("Advanced metrics are Premium")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("YPRR, target share, EPA, RAS and more.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}
