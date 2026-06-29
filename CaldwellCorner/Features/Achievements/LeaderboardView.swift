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
                Podium(entries: podium).animation(Theme.Anim.spring, value: scope)
                youRow
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(rest) { entry in
                        LeaderboardRow(entry: entry).transition(.opacity)
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
                DSEyebrow(text: "Your Rank")
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
            if entries.count > 1 { pillar(entries[1], height: 92, place: 2) }
            if let first = entries.first { pillar(first, height: 116, place: 1) }
            if entries.count > 2 { pillar(entries[2], height: 76, place: 3) }
        }
        .frame(maxWidth: .infinity)
    }

    private func pillar(_ e: LeaderboardEntry, height: CGFloat, place: Int) -> some View {
        let medal: Color = place == 1 ? Theme.Colors.accentSecondary : place == 2 ? Color(hex: 0xC0C6CE) : Color(hex: 0xCD7F32)
        return VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                LeaderAvatar(name: e.name, rarity: e.topRarity, size: 50)
                if place == 1 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11)).foregroundStyle(.black)
                        .padding(4).background(medal).clipShape(Circle())
                }
            }
            Text(e.name.split(separator: " ").first.map(String.init) ?? e.name)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary).lineLimit(1)
            Text("\(e.ap) AP").dsCaption()
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(Theme.Colors.surface)
                .frame(height: height)
                .overlay(Text("\(place)").dsNumeric(24, color: medal))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).strokeBorder(Theme.Colors.stroke, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Rarity-tinted avatar
struct LeaderAvatar: View {
    let name: String
    let rarity: AchievementRarity
    var size: CGFloat = 38
    var body: some View {
        Text(name.initials)
            .font(.system(size: size * 0.36, weight: .bold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: size, height: size)
            .background(Theme.Colors.surfaceElevated)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(AchievementStyle.color(rarity).opacity(0.7), lineWidth: 1.5))
    }
}

// MARK: - Row
struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(entry.rank)")
                .dsNumeric(15, color: entry.isUser ? Theme.Colors.accent : Theme.Colors.textTertiary)
                .frame(width: 28)
            MovementIndicator(movement: entry.movement)
            LeaderAvatar(name: entry.name, rarity: entry.topRarity, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).dsCardTitle()
                    .foregroundStyle(entry.isUser ? Theme.Colors.accent : Theme.Colors.textPrimary).lineLimit(1)
                Text("Lvl \(entry.level) · \(entry.topRarity.rawValue)").dsCaption()
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.ap)").dsNumeric(15)
                Text("AP").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.md)
        .background(entry.isUser ? Theme.Colors.accent.opacity(0.10) : Theme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .strokeBorder(entry.isUser ? Theme.Colors.accent.opacity(0.5) : Theme.Colors.stroke, lineWidth: 1))
    }
}

// MARK: - Movement indicator (calm, static)
struct MovementIndicator: View {
    let movement: Int
    var body: some View {
        Group {
            if movement > 0 {
                label("arrow.up", "\(movement)", Theme.Colors.positive)
            } else if movement < 0 {
                label("arrow.down", "\(-movement)", Theme.Colors.negative)
            } else {
                Image(systemName: "minus").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .frame(width: 26)
    }
    private func label(_ icon: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 1) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(value).font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
    }
}
