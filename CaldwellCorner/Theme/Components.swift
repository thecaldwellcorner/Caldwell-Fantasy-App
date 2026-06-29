import SwiftUI

// MARK: - Interaction: press feedback
/// Adds a subtle scale + dim on press (≈160ms) for a tactile, premium feel.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Theme.Anim.tap, value: configuration.isPressed)
    }
}

extension View {
    /// Apply to Buttons / NavigationLinks for a tactile press animation.
    func pressable(scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressableButtonStyle(scale: scale))
    }

    /// Fade + slide-up entrance animation.
    func appear(delay: Double = 0) -> some View {
        modifier(AppearModifier(delay: delay))
    }

    /// Shimmer sweep, used on redacted / loading placeholders.
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

struct AppearModifier: ViewModifier {
    @State private var shown = false
    var delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .onAppear {
                withAnimation(Theme.Anim.standard.delay(delay)) { shown = true }
            }
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var x: CGFloat = -1
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geo in
                LinearGradient(colors: [.clear, .white.opacity(0.12), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * 0.9)
                    .offset(x: x * geo.size.width)
                    .allowsHitTesting(false)
            }
        )
        .onAppear {
            withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) { x = 1.2 }
        }
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
                    LinearGradient(colors: [.clear, .white.opacity(0.10), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.8)
                        .offset(x: x * geo.size.width)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { x = 1.2 }
            }
    }
}

/// A card-shaped skeleton row used while content loads.
struct SkeletonCard: View {
    var lines: Int = 3
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            SkeletonView(cornerRadius: 999).frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<lines, id: \.self) { i in
                    SkeletonView()
                        .frame(height: 10)
                        .frame(maxWidth: i == lines - 1 ? 120 : .infinity, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .card(padding: Theme.Spacing.md)
    }
}

// MARK: - Position badge
struct PositionBadge: View {
    let position: String
    var compact: Bool = false

    var body: some View {
        Text(position.uppercased())
            .font(.system(size: compact ? 10 : 12, weight: .heavy, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 2 : 4)
            .background(Theme.Colors.position(position))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - Player avatar (initials, position tinted)
struct PlayerAvatar: View {
    let name: String
    let position: String
    var size: CGFloat = 44

    var body: some View {
        Text(name.initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Theme.Colors.position(position).opacity(0.65),
                             Theme.Colors.surfaceElevated],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.Colors.position(position).opacity(0.7), lineWidth: 1.5))
    }
}

// MARK: - Premium lock pill
struct PremiumBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
            Text("PRO")
        }
        .font(.system(size: 10, weight: .heavy, design: .rounded))
        .foregroundStyle(.black)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Theme.Gradient.gold)
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
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
            Spacer()
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .semibold))
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
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            LinearGradient(colors: [Theme.Colors.surfaceHighlight.opacity(0.6), Theme.Colors.surfaceElevated],
                           startPoint: .top, endPoint: .bottom))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .strokeBorder(Theme.Colors.strokeSoft, lineWidth: 1))
    }
}

// MARK: - Primary button
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
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.Gradient.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .shadow(color: Theme.Colors.accent.opacity(0.35), radius: 12, y: 6)
        }
        .pressable(scale: 0.98)
    }
}

// MARK: - Grade ring
struct GradeRing: View {
    let score: Double      // 0...100
    var size: CGFloat = 64
    var label: String? = nil
    @State private var animated = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.stroke, lineWidth: 6)
            Circle()
                .trim(from: 0, to: animated ? max(0.02, score / 100) : 0)
                .stroke(Theme.Colors.grade(score),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(score))")
                    .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let label {
                    Text(label)
                        .font(.system(size: size * 0.14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear { withAnimation(Theme.Anim.spring.delay(0.05)) { animated = true } }
    }
}

// MARK: - Trend arrow
struct TrendIndicator: View {
    let value: Double  // positive = up
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
            Text(String(format: "%.0f", abs(value)))
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(value >= 0 ? Theme.Colors.positive : Theme.Colors.negative)
    }
}

// MARK: - Empty / Pro gating overlay card
struct ProGateCard: View {
    let feature: String
    var onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.Colors.accentSecondary)
            Text("\(feature) is a Premium feature")
                .font(.system(size: 16, weight: .bold, design: .rounded))
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
