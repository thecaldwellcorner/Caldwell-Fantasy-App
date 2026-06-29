import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var state: AppState
    @State private var scope: LeaderboardScope = .global

    private var entries: [LeaderboardEntry] { state.leaderboard(scope) }
    private var podium: [LeaderboardEntry] { Array(entries.prefix(3)) }
    private var rest: [LeaderboardEntry] { Array(entries.dropFirst(3)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                scopePicker
                Podium(entries: podium)
                    .animation(Theme.Anim.spring, value: scope)
                youRow
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(rest) { entry in
                        LeaderboardRow(entry: entry)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity))
                    }
                }
                .animation(Theme.Anim.spring, value: scope)
            }
            .padding(Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Leaderboards")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(LeaderboardScope.allCases) { s in
                    FilterChip(title: s.rawValue, selected: scope == s) {
                        withAnimation(Theme.Anim.spring) { scope = s }
                    }
                }
            }
        }
    }

    @ViewBuilder private var youRow: some View {
        if let me = entries.first(where: { $0.isUser }) {
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR RANK").font(.system(size: 10, weight: .heavy)).foregroundStyle(Theme.Colors.textTertiary)
                LeaderboardRow(entry: me)
            }
        }
    }
}

// MARK: - Podium (top 3)
struct Podium: View {
    let entries: [LeaderboardEntry]
    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if entries.count > 1 { pillar(entries[1], height: 96, place: 2) }
            if let first = entries.first { pillar(first, height: 120, place: 1) }
            if entries.count > 2 { pillar(entries[2], height: 80, place: 3) }
        }
        .frame(maxWidth: .infinity)
    }

    private func pillar(_ e: LeaderboardEntry, height: CGFloat, place: Int) -> some View {
        let medal: Color = place == 1 ? Theme.Colors.accentSecondary : place == 2 ? Color(hex: 0xC0C6CE) : Color(hex: 0xCD7F32)
        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Circle().fill(AchievementStyle.gradient(e.topRarity)).frame(width: 52, height: 52)
                    .overlay(Text(e.name.initials).font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.black))
                Image(systemName: "crown.fill")
                    .font(.system(size: 12)).foregroundStyle(.black)
                    .padding(4).background(medal).clipShape(Circle())
                    .opacity(place == 1 ? 1 : 0)
            }
            Text(e.name.split(separator: " ").first.map(String.init) ?? e.name)
                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.Colors.textPrimary).lineLimit(1)
            Text("\(e.ap) AP").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.Colors.textSecondary)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [medal.opacity(0.5), Theme.Colors.surface], startPoint: .top, endPoint: .bottom))
                .frame(height: height)
                .overlay(Text("\(place)").font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(medal))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.Colors.stroke, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Row
struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(entry.rank)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(entry.isUser ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .frame(width: 30)

            MovementIndicator(movement: entry.movement)

            Circle().fill(AchievementStyle.gradient(entry.topRarity)).frame(width: 38, height: 38)
                .overlay(Text(entry.name.initials).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.black))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isUser ? Theme.Colors.accent : Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text("Lvl \(entry.level) · \(entry.topRarity.rawValue)")
                    .font(.system(size: 11)).foregroundStyle(Theme.Colors.textTertiary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.ap)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("AP")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(entry.isUser ? Theme.Colors.accent.opacity(0.10) : Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .strokeBorder(entry.isUser ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.stroke, lineWidth: 1))
    }
}

// MARK: - Animated movement arrow
struct MovementIndicator: View {
    let movement: Int
    @State private var bounce = false

    var body: some View {
        Group {
            if movement > 0 {
                label("arrow.up", "\(movement)", Theme.Colors.positive)
            } else if movement < 0 {
                label("arrow.down", "\(-movement)", Theme.Colors.negative)
            } else {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(width: 28)
        .onAppear {
            guard movement != 0 else { return }
            withAnimation(Theme.Anim.snappy.repeatCount(2, autoreverses: true)) { bounce = true }
        }
    }

    private func label(_ icon: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 1) {
            Image(systemName: icon).font(.system(size: 9, weight: .heavy))
            Text(value).font(.system(size: 10, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(color)
        .offset(y: bounce ? (movement > 0 ? -2 : 2) : 0)
    }
}
