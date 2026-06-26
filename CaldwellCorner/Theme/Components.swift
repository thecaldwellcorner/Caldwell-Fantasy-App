import SwiftUI

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

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Theme.Colors.position(position).opacity(0.6),
                             Theme.Colors.surfaceElevated],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.Colors.position(position).opacity(0.7), lineWidth: 1.5))
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
        .background(Theme.Colors.accentSecondary)
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
                Button(actionLabel, action: action)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accent)
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
        .background(Theme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
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
            .padding(.vertical, 14)
            .background(Theme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
    }
}

// MARK: - Grade ring
struct GradeRing: View {
    let score: Double      // 0...100
    var size: CGFloat = 64
    var label: String? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.stroke, lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.02, score / 100))
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
