import SwiftUI

// MARK: - Interaction: press feedback
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.98
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(Theme.Anim.tap, value: configuration.isPressed)
    }
}

extension View {
    func pressable(scale: CGFloat = 0.98) -> some View {
        buttonStyle(PressableButtonStyle(scale: scale))
    }

    /// Subtle fade + slight rise on appear.
    func appear(delay: Double = 0) -> some View {
        modifier(AppearModifier(delay: delay))
    }

    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

struct AppearModifier: ViewModifier {
    @State private var shown = false
    var delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 8)
            .onAppear { withAnimation(Theme.Anim.standard.delay(delay)) { shown = true } }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var x: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.08), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.85)
                    .offset(x: x * geo.size.width)
                    .allowsHitTesting(false)
            }
        )
        .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { x = 1.2 } }
    }
}

// MARK: - Loading skeleton
struct SkeletonView: View {
    var cornerRadius: CGFloat = Theme.Radius.sm
    @State private var x: CGFloat = -1
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.Colors.surfaceElevated)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white.opacity(0.07), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.8)
                        .offset(x: x * geo.size.width)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear { withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { x = 1.2 } }
    }
}

struct SkeletonCard: View {
    var lines: Int = 3
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            SkeletonView(cornerRadius: 999).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<lines, id: \.self) { i in
                    SkeletonView()
                        .frame(height: 9)
                        .frame(maxWidth: i == lines - 1 ? 120 : .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .card(padding: Theme.Spacing.md)
    }
}

// MARK: - Tag / pill (reusable)
struct Tag: View {
    let text: String
    var color: Color = Theme.Colors.textSecondary
    var filled: Bool = false

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(filled ? .black : color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Group {
                    if filled { color } else { color.opacity(0.14) }
                }
            )
            .clipShape(Capsule())
    }
}

// MARK: - Position badge
struct PositionBadge: View {
    let position: String
    var compact: Bool = false

    var body: some View {
        Text(position.uppercased())
            .font(.system(size: compact ? 10 : 11, weight: .bold))
            .foregroundStyle(Theme.Colors.position(position))
            .padding(.horizontal, compact ? 6 : 7)
            .padding(.vertical, compact ? 2 : 3)
            .background(Theme.Colors.position(position).opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Player avatar (initials, position-tinted ring)
struct PlayerAvatar: View {
    let name: String
    let position: String
    var size: CGFloat = 44

    var body: some View {
        Text(name.initials)
            .font(.system(size: size * 0.34, weight: .bold))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: size, height: size)
            .background(Theme.Colors.surfaceElevated)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.Colors.position(position).opacity(0.6), lineWidth: 1.5))
    }
}

// MARK: - Premium pill
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
            Text("PRO")
        }
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(Theme.Colors.accentSecondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Theme.Colors.accentSecondary.opacity(0.16))
        .clipShape(Capsule())
    }
}

// MARK: - Section header
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .pressable()
            }
        }
    }
}

// MARK: - Stat pill / metric chip
struct MetricChip: View {
    let label: String
    let value: String
    var tint: Color = Theme.Colors.textPrimary

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .strokeBorder(Theme.Colors.strokeSoft, lineWidth: 1))
    }
}

// MARK: - Primary button (solid, consistent)
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .pressable()
    }
}

// MARK: - Grade ring (static, calm)
struct GradeRing: View {
    let score: Double      // 0...100
    var size: CGFloat = 64
    var label: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(Theme.Colors.stroke, lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.02, score / 100))
                .stroke(Theme.Colors.grade(score), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(score))")
                    .font(.system(size: size * 0.32, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let label {
                    Text(label)
                        .font(.system(size: size * 0.13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Trend arrow
struct TrendIndicator: View {
    let value: Double
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(String(format: "%.0f", abs(value)))
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(value >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
    }
}

// MARK: - Pro gating card
struct ProGateCard: View {
    let feature: String
    var onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundStyle(Theme.Colors.accentSecondary)
            Text("\(feature) is a Premium feature")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Unlock unlimited AI, advanced projections, dynasty tools, the Draft Guide and more.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Go Premium", systemImage: "crown.fill", action: onUpgrade)
        }
        .card()
    }
}
