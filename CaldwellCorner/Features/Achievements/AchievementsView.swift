import SwiftUI

// MARK: - Rarity styling
enum AchievementStyle {
    static func color(_ r: AchievementRarity) -> Color {
        switch r {
        case .common: return Theme.Colors.textSecondary
        case .rare: return Theme.Colors.info
        case .epic: return Theme.Colors.violet
        case .legendary: return Theme.Colors.accentSecondary
        case .mythic: return Theme.Colors.negative
        }
    }
    /// Flat rarity fill (kept as a gradient type for source compatibility).
    static func gradient(_ r: AchievementRarity) -> LinearGradient {
        LinearGradient(colors: [color(r).opacity(0.85), color(r).opacity(0.85)],
                       startPoint: .top, endPoint: .bottom)
    }
}

struct AchievementsView: View {
    @EnvironmentObject var state: AppState
    @State private var category: AchievementCategory?

    private var summary: Progression.Summary { state.progression }

    private var filtered: [Achievement] {
        let base = category == nil ? state.achievements : state.achievements.filter { $0.category == category }
        return base.sorted { lhs, rhs in
            if lhs.unlocked != rhs.unlocked { return lhs.unlocked && !rhs.unlocked }
            if lhs.rarity.order != rhs.rarity.order { return lhs.rarity.order > rhs.rarity.order }
            return lhs.ap > rhs.ap
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                progressionCard.appear()
                leaderboardLink.appear(delay: 0.05)
                rarityBreakdown.appear(delay: 0.08)
                categoryFilter
                achievementsList
                activitySection
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressionCard: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.lg) {
                LevelBadge(level: summary.level, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    DSEyebrow(text: summary.levelTitle, color: Theme.Colors.accent)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(summary.totalAP)").dsNumeric(28)
                        Text("AP").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Text("\(summary.unlockedCount)/\(summary.totalCount) unlocked · \(Int(summary.completion * 100))%").dsCaption()
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Level \(summary.level)")
                    Spacer()
                    Text("\(summary.apIntoLevel) / \(summary.apForNextLevel) AP to Lvl \(summary.level + 1)")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
                ProgressBar(fraction: summary.progressInLevel)
            }
        }
        .card(elevated: true)
    }

    private var leaderboardLink: some View {
        NavigationLink { LeaderboardView() } label: {
            HStack(spacing: Theme.Spacing.md) {
                DSIconBadge(systemName: "chart.bar.fill", tint: Theme.Colors.accentSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leaderboards").dsCardTitle()
                    Text("Global · League · Weekly · Season · All-Time").dsCaption()
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
            }
            .card(padding: Theme.Spacing.md)
        }
    }

    private var rarityBreakdown: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(AchievementRarity.allCases) { r in
                VStack(spacing: 4) {
                    Text("\(summary.rarityCounts[r] ?? 0)").dsNumeric(16, color: AchievementStyle.color(r))
                    DSEyebrow(text: r.rawValue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(Theme.Colors.stroke, lineWidth: 1))
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "All", selected: category == nil) {
                    withAnimation(Theme.Anim.quick) { category = nil }
                }
                ForEach(AchievementCategory.allCases) { c in
                    FilterChip(title: c.rawValue, selected: category == c) {
                        withAnimation(Theme.Anim.quick) { category = category == c ? nil : c }
                    }
                }
            }
        }
    }

    private var achievementsList: some View {
        LazyVStack(spacing: Theme.Spacing.sm) {
            ForEach(filtered) { a in
                AchievementRow(achievement: a)
                    .transition(.opacity)
            }
        }
        .animation(Theme.Anim.quick, value: category)
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Recent Activity")
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(state.achievementActivity) { ActivityRow(activity: $0) }
            }
        }
    }
}

// MARK: - Level badge
struct LevelBadge: View {
    let level: Int
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            Circle().fill(Theme.Colors.accent)
            VStack(spacing: -2) {
                Text("LVL").font(.system(size: size * 0.15, weight: .bold)).foregroundStyle(.black.opacity(0.6))
                Text("\(level)").font(.system(size: size * 0.4, weight: .bold, design: .rounded)).foregroundStyle(.black)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Progress bar
struct ProgressBar: View {
    let fraction: Double
    var tint: Color = Theme.Colors.accent
    @State private var animated = false
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.surfaceElevated)
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.85), tint],
                                         startPoint: .leading, endPoint: .trailing))
                    .shadow(color: tint.opacity(0.55), radius: 5, y: 0)
                    .frame(width: geo.size.width * CGFloat(animated ? max(0.0, min(1, fraction)) : 0))
            }
        }
        .frame(height: 8)
        .onAppear { withAnimation(Theme.Anim.spring.delay(0.1)) { animated = true } }
    }
}

// MARK: - Achievement row
struct AchievementRow: View {
    let achievement: Achievement
    private var color: Color { AchievementStyle.color(achievement.rarity) }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            DSIconBadge(systemName: achievement.displayIcon,
                        tint: achievement.unlocked ? color : Theme.Colors.textTertiary, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(achievement.displayTitle).dsCardTitle().lineLimit(1)
                    if achievement.unlocked {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(Theme.Colors.positive)
                    }
                }
                Text(achievement.displayDetail).dsCaption().lineLimit(2)
                if achievement.unlocked {
                    Text(unlockedLabel).font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
                } else if !achievement.isMasked {
                    HStack(spacing: 6) {
                        ProgressBar(fraction: achievement.fraction, tint: color)
                        Text("\(achievement.progress)/\(achievement.target)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            Spacer(minLength: 4)

            VStack(spacing: 5) {
                Tag(text: achievement.rarity.rawValue, color: color, filled: true)
                Text("+\(achievement.ap)").dsNumeric(13, color: achievement.unlocked ? Theme.Colors.accent : Theme.Colors.textTertiary)
                DSEyebrow(text: "AP")
            }
        }
        .card(padding: Theme.Spacing.md)
        .opacity(achievement.unlocked ? 1 : 0.9)
    }

    private var unlockedLabel: String {
        guard let d = achievement.unlockedDate else { return "Unlocked" }
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return "Unlocked \(f.string(from: d))"
    }
}

// MARK: - Activity row
struct ActivityRow: View {
    let activity: AchievementActivity
    private var icon: String {
        switch activity.kind {
        case .unlock: return "rosette"
        case .progress: return "chart.bar.fill"
        case .levelUp: return "arrow.up.circle.fill"
        case .rankUp: return "chevron.up.circle.fill"
        }
    }
    private var tint: Color {
        if let r = activity.rarity { return AchievementStyle.color(r) }
        switch activity.kind {
        case .levelUp: return Theme.Colors.accent
        case .rankUp: return Theme.Colors.info
        default: return Theme.Colors.textSecondary
        }
    }
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(tint).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title).dsCardTitle()
                Text(activity.detail).dsCaption()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if activity.ap > 0 { Text("+\(activity.ap) AP").dsNumeric(12, color: Theme.Colors.accent) }
                Text(activity.date.relativeShort).font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}
