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
    static func gradient(_ r: AchievementRarity) -> LinearGradient {
        LinearGradient(colors: [color(r).opacity(0.9), color(r).opacity(0.45)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
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
                rarityBreakdown.appear(delay: 0.10)
                categoryFilter
                achievementsList
                activitySection.appear(delay: 0.05)
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Progression card
    private var progressionCard: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.lg) {
                LevelBadge(level: summary.level, size: 78)
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.levelTitle.uppercased())
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.Colors.accent)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(summary.totalAP)")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("AP")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Text("\(summary.unlockedCount)/\(summary.totalCount) unlocked · \(Int(summary.completion * 100))%")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textSecondary)
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
                ProgressBar(fraction: summary.progressInLevel, tint: Theme.Colors.accent)
            }
        }
        .card(elevated: true)
    }

    private var leaderboardLink: some View {
        NavigationLink { LeaderboardView() } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20)).foregroundStyle(.black)
                    .frame(width: 40, height: 40).background(Theme.Gradient.gold).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leaderboards").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Theme.Colors.textPrimary)
                    Text("Global · League · Weekly · Season · All-Time").font(.system(size: 12)).foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.Colors.textTertiary)
            }
            .card(padding: Theme.Spacing.md)
        }
    }

    private var rarityBreakdown: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(AchievementRarity.allCases) { r in
                VStack(spacing: 3) {
                    Text("\(summary.rarityCounts[r] ?? 0)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(AchievementStyle.color(r))
                    Text(r.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(AchievementStyle.color(r).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(AchievementStyle.color(r).opacity(0.4), lineWidth: 1))
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(title: "ALL", selected: category == nil) {
                    withAnimation(Theme.Anim.quick) { category = nil }
                }
                ForEach(AchievementCategory.allCases) { c in
                    FilterChip(title: c.rawValue, selected: category == c, color: Theme.Colors.accent) {
                        withAnimation(Theme.Anim.quick) { category = category == c ? nil : c }
                    }
                }
            }
        }
    }

    private var achievementsList: some View {
        LazyVStack(spacing: Theme.Spacing.md) {
            ForEach(filtered) { a in
                AchievementRow(achievement: a)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(Theme.Anim.spring, value: category)
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
            Circle().fill(Theme.Gradient.accent)
                .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 10, y: 4)
            Circle().strokeBorder(.white.opacity(0.25), lineWidth: 2)
            VStack(spacing: -2) {
                Text("LVL").font(.system(size: size * 0.16, weight: .heavy)).foregroundStyle(.black.opacity(0.7))
                Text("\(level)").font(.system(size: size * 0.42, weight: .heavy, design: .rounded)).foregroundStyle(.black)
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
                Capsule().fill(tint)
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
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AchievementStyle.gradient(achievement.rarity))
                    .opacity(achievement.unlocked ? 1 : 0.25)
                Image(systemName: achievement.displayIcon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(achievement.unlocked ? .black : Theme.Colors.textTertiary)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(achievement.displayTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    if achievement.unlocked {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(Theme.Colors.positive)
                    }
                }
                Text(achievement.displayDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(2)
                if achievement.unlocked {
                    Text(unlockedLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.Colors.textTertiary)
                } else if !achievement.isMasked {
                    HStack(spacing: 6) {
                        ProgressBar(fraction: achievement.fraction, tint: color)
                        Text("\(achievement.progress)/\(achievement.target)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            Spacer(minLength: 4)

            VStack(spacing: 4) {
                Text(achievement.rarity.rawValue.uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(color).clipShape(Capsule())
                Text("+\(achievement.ap)")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(achievement.unlocked ? Theme.Colors.accent : Theme.Colors.textTertiary)
                Text("AP").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .card(padding: Theme.Spacing.md)
        .opacity(achievement.unlocked ? 1 : 0.92)
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
            Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundStyle(tint).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
                Text(activity.detail).font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if activity.ap > 0 {
                    Text("+\(activity.ap) AP").font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(Theme.Colors.accent)
                }
                Text(activity.date.relativeShort).font(.system(size: 10)).foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .card(padding: Theme.Spacing.md)
    }
}
