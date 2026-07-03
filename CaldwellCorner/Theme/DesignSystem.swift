import SwiftUI

// MARK: - Typography (the single source of truth for text styles)
// Apply these instead of inline `.font(.system(...))` so every screen matches.
extension View {
    /// 22 / semibold / primary — screen & hero titles.
    func dsScreenTitle() -> some View {
        font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
    }
    /// 17 / semibold / primary — section titles.
    func dsSectionTitle() -> some View {
        font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
    }
    /// 15 / semibold / primary — card & row titles.
    func dsCardTitle() -> some View {
        font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.Colors.textPrimary)
    }
    /// 14 / regular / secondary — body copy.
    func dsBody() -> some View {
        font(.system(size: 14)).foregroundStyle(Theme.Colors.textSecondary)
    }
    /// 13 / regular / secondary — supporting copy.
    func dsCallout() -> some View {
        font(.system(size: 13)).foregroundStyle(Theme.Colors.textSecondary)
    }
    /// 12 / regular / tertiary — captions & metadata.
    func dsCaption() -> some View {
        font(.system(size: 12)).foregroundStyle(Theme.Colors.textTertiary)
    }
    /// Rounded numeric emphasis for stats/scores.
    func dsNumeric(_ size: CGFloat, color: Color = Theme.Colors.textPrimary) -> some View {
        font(.system(size: size, weight: .semibold, design: .rounded)).foregroundStyle(color)
    }
    /// Consistent horizontal screen padding.
    func dsScreenPadding() -> some View { padding(.horizontal, Theme.Spacing.lg) }
}

/// Small uppercase eyebrow/label text (e.g. "FINAL CALL", "LIVE").
struct DSEyebrow: View {
    let text: String
    var color: Color = Theme.Colors.textTertiary
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

// MARK: - Glass card (material + depth + top-edge lighting)
/// Frosted, elevated surface that matches the Caldwell IQ design language:
/// a translucent material tint, a subtle top sheen, a light top-edge hairline,
/// an optional violet glow for hero cards, and a soft drop shadow for depth.
struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.lg
    var radius: CGFloat = 18
    var hero: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .padding(padding)
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Theme.Colors.surface.opacity(hero ? 0.62 : 0.72))
                    // Top sheen
                    shape.fill(
                        LinearGradient(colors: [Color.white.opacity(hero ? 0.07 : 0.05), .clear],
                                       startPoint: .top, endPoint: .center))
                    // Hero: soft violet lighting near the top
                    if hero {
                        Ellipse()
                            .fill(Theme.Colors.accent.opacity(0.22))
                            .frame(height: 150)
                            .blur(radius: 55)
                            .offset(y: -70)
                            .blendMode(.plusLighter)
                    }
                }
            }
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(0.16), Theme.Colors.stroke.opacity(0.5)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
            )
            .shadow(color: .black.opacity(hero ? 0.45 : 0.32),
                    radius: hero ? 22 : 14, x: 0, y: hero ? 12 : 7)
    }
}

extension View {
    func glassCard(padding: CGFloat = Theme.Spacing.lg, radius: CGFloat = 18, hero: Bool = false) -> some View {
        modifier(GlassCardModifier(padding: padding, radius: radius, hero: hero))
    }
}

// MARK: - Icon badge (icon in a tinted rounded square) — used everywhere
struct DSIconBadge: View {
    let systemName: String
    var tint: Color = Theme.Colors.accent
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

// MARK: - Segmented control (custom, consistent across the app)
struct DSSegmented<T: Hashable>: View {
    let items: [T]
    let title: (T) -> String
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                let active = item == selection
                Text(title(item))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(active ? .black : Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(active ? Theme.Colors.accent : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(Theme.Anim.quick) { selection = item } }
            }
        }
        .padding(4)
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            .strokeBorder(Theme.Colors.strokeSoft, lineWidth: 1))
    }
}

// MARK: - Filter chip (consistent pill toggles across the app)
struct FilterChip: View {
    let title: String
    let selected: Bool
    var color: Color = Theme.Colors.accent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .black : Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 7)
                .background(selected ? color : Theme.Colors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.Colors.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Secondary / ghost button
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.Colors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                .strokeBorder(Theme.Colors.stroke, lineWidth: 1))
        }
        .pressable()
    }
}

// MARK: - Disclosure row (settings / navigation rows)
struct DSNavRow: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var tint: Color = Theme.Colors.accent

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 26)
            Text(title).dsBody().foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            if let detail { Text(detail).dsCaption() }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.textTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, Theme.Spacing.lg)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty state
struct DSEmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text(title).dsCardTitle()
            if let message {
                Text(message).dsCaption().multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
        .padding(.horizontal, Theme.Spacing.xl)
    }
}
