import SwiftUI

/// Central design system. Clean, flat, dark-mode-first — restrained palette,
/// consistent spacing/radius/typography, and subtle motion.
enum Theme {

    // MARK: - Colors
    enum Colors {
        static let background = Color(hex: 0x0B0E13)
        static let backgroundTop = Color(hex: 0x0B0E13)
        static let surface = Color(hex: 0x14181F)
        static let surfaceElevated = Color(hex: 0x1A1F27)
        static let surfaceHighlight = Color(hex: 0x222833)
        static let stroke = Color(hex: 0x252B34)
        static let strokeSoft = Color(hex: 0x1C222A)

        static let accent = Color(hex: 0x2BD46E)          // primary green (single hero accent)
        static let accentDeep = Color(hex: 0x16A856)
        static let accentSecondary = Color(hex: 0xE9B949)  // gold (used sparingly: premium)
        static let info = Color(hex: 0x5AA9FF)
        static let violet = Color(hex: 0x9E86FF)

        static let textPrimary = Color(hex: 0xF2F5F8)
        static let textSecondary = Color(hex: 0x9AA7B4)
        static let textTertiary = Color(hex: 0x66727E)

        static let positive = Color(hex: 0x2BD46E)
        static let warning = Color(hex: 0xF0B341)
        static let negative = Color(hex: 0xF2576E)

        /// Position colors — muted, used only as small accents.
        static func position(_ pos: String) -> Color {
            switch pos.uppercased() {
            case "QB": return Color(hex: 0xF2576E)
            case "RB": return Color(hex: 0x2BD46E)
            case "WR": return Color(hex: 0x5AA9FF)
            case "TE": return Color(hex: 0xF0B341)
            case "K": return Color(hex: 0x9E86FF)
            case "DEF", "DST": return Color(hex: 0x8A97A4)
            default: return textSecondary
            }
        }

        /// Grade color from a 0...100 score.
        static func grade(_ score: Double) -> Color {
            switch score {
            case 80...: return positive
            case 60..<80: return accentSecondary
            case 45..<60: return warning
            default: return negative
            }
        }
    }

    // MARK: - Gradients (used sparingly — scrims & avatars only)
    enum Gradient {
        static var accent: LinearGradient {
            LinearGradient(colors: [Colors.accent, Colors.accentDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        static var gold: LinearGradient {
            LinearGradient(colors: [Colors.accentSecondary, Colors.accentSecondary],
                           startPoint: .leading, endPoint: .trailing)
        }
        /// Bottom-up dark scrim for text legibility over imagery.
        static var bottomScrim: LinearGradient {
            LinearGradient(colors: [.clear, .black.opacity(0.75)],
                           startPoint: .center, endPoint: .bottom)
        }
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Radius (consistent)
    enum Radius {
        static let sm: CGFloat = 10
        static let control: CGFloat = 12   // buttons, inputs, segmented
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let card: CGFloat = 16
        static let pill: CGFloat = 999
    }

    // MARK: - Motion (subtle, 150–250ms)
    enum Anim {
        static let tap = SwiftUI.Animation.easeOut(duration: 0.16)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.24)
        static let spring = SwiftUI.Animation.spring(response: 0.36, dampingFraction: 0.9)
        static let snappy = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.86)
    }

    // MARK: - Shadow (very subtle, hero cards only)
    enum Shadow {
        static let cardColor = Color.black.opacity(0.25)
        static let cardRadius: CGFloat = 10
        static let cardY: CGFloat = 4
    }

    // MARK: - Typography (clean SF scale)
    enum Typography {
        static func screenTitle() -> Font { .system(size: 22, weight: .bold) }
        static func sectionTitle() -> Font { .system(size: 17, weight: .semibold) }
        static func cardTitle() -> Font { .system(size: 15, weight: .semibold) }
        static func body() -> Font { .system(size: 14, weight: .regular) }
        static func caption() -> Font { .system(size: 12, weight: .regular) }
        static func micro() -> Font { .system(size: 10, weight: .semibold) }
        /// Numeric emphasis (scores / points) — rounded reads well for digits.
        static func metric(_ size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Reusable card container (flat, consistent)
struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.lg
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Colors.stroke, lineWidth: 1)
            )
            .shadow(color: elevated ? Theme.Shadow.cardColor : .clear,
                    radius: elevated ? Theme.Shadow.cardRadius : 0,
                    x: 0, y: elevated ? Theme.Shadow.cardY : 0)
    }
}

extension View {
    func card(padding: CGFloat = Theme.Spacing.lg, elevated: Bool = false) -> some View {
        modifier(CardModifier(padding: padding, elevated: elevated))
    }

    /// Standard flat dark screen background.
    func screenBackground() -> some View {
        self.background(Theme.Colors.background.ignoresSafeArea())
    }
}

/// Kept for source compatibility; now a flat dark background.
struct AppBackground: View {
    var body: some View { Theme.Colors.background }
}
