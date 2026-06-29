import SwiftUI

/// Central design system for Caldwell Corner Fantasy Football.
/// Dark-mode-first, broadcast-inspired theme with an electric-green accent,
/// soft gradients, rounded cards and consistent motion.
enum Theme {

    // MARK: - Colors
    enum Colors {
        static let background = Color(hex: 0x090C11)
        static let backgroundTop = Color(hex: 0x10161F)
        static let surface = Color(hex: 0x141B24)
        static let surfaceElevated = Color(hex: 0x1C2530)
        static let surfaceHighlight = Color(hex: 0x222D3A)
        static let stroke = Color(hex: 0x273341)
        static let strokeSoft = Color(hex: 0x1B2530)

        static let accent = Color(hex: 0x1EF266)          // electric green
        static let accentDeep = Color(hex: 0x0FB94A)
        static let accentSecondary = Color(hex: 0xF2C200)  // gold
        static let info = Color(hex: 0x4DA3FF)
        static let violet = Color(hex: 0xB084FF)

        static let textPrimary = Color(hex: 0xF5F8FA)
        static let textSecondary = Color(hex: 0x9DB0C0)
        static let textTertiary = Color(hex: 0x647688)

        static let positive = Color(hex: 0x1EF266)
        static let warning = Color(hex: 0xFFB020)
        static let negative = Color(hex: 0xFF5470)

        // Position colors
        static func position(_ pos: String) -> Color {
            switch pos.uppercased() {
            case "QB": return Color(hex: 0xFF5470)
            case "RB": return Color(hex: 0x1EF266)
            case "WR": return Color(hex: 0x4DA3FF)
            case "TE": return Color(hex: 0xFFB020)
            case "K": return Color(hex: 0xB084FF)
            case "DEF", "DST": return Color(hex: 0x8A9BA8)
            default: return textSecondary
            }
        }

        /// Grade color from a 0...100 score.
        static func grade(_ score: Double) -> Color {
            switch score {
            case 85...: return positive
            case 70..<85: return accentSecondary
            case 50..<70: return warning
            default: return negative
            }
        }
    }

    // MARK: - Gradients
    enum Gradient {
        static var appBackground: LinearGradient {
            LinearGradient(colors: [Colors.backgroundTop, Colors.background],
                           startPoint: .top, endPoint: .bottom)
        }
        static var surface: LinearGradient {
            LinearGradient(colors: [Colors.surfaceHighlight.opacity(0.55), Colors.surface],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        static var accent: LinearGradient {
            LinearGradient(colors: [Colors.accent, Colors.accentDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        static var gold: LinearGradient {
            LinearGradient(colors: [Colors.accentSecondary, Colors.accent],
                           startPoint: .leading, endPoint: .trailing)
        }
        /// Soft top highlight used as a hairline on cards.
        static var hairline: LinearGradient {
            LinearGradient(colors: [Color.white.opacity(0.10), Colors.stroke.opacity(0.0)],
                           startPoint: .top, endPoint: .bottom)
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

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let card: CGFloat = 18
        static let pill: CGFloat = 999
    }

    // MARK: - Motion (150–250ms)
    enum Anim {
        static let tap = SwiftUI.Animation.easeOut(duration: 0.16)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.34, dampingFraction: 0.82)
        static let snappy = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.78)
    }

    // MARK: - Shadows
    enum Shadow {
        static let cardColor = Color.black.opacity(0.35)
        static let cardRadius: CGFloat = 14
        static let cardY: CGFloat = 8
    }

    // MARK: - Typography (SF Rounded scale)
    enum Typography {
        static func largeTitle() -> Font { .system(size: 28, weight: .heavy, design: .rounded) }
        static func title() -> Font { .system(size: 22, weight: .heavy, design: .rounded) }
        static func headline() -> Font { .system(size: 17, weight: .bold, design: .rounded) }
        static func body() -> Font { .system(size: 15, weight: .regular) }
        static func caption() -> Font { .system(size: 12, weight: .medium) }
        static func micro() -> Font { .system(size: 10, weight: .semibold) }
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

// MARK: - Reusable card container
struct CardModifier: ViewModifier {
    var padding: CGFloat = Theme.Spacing.lg
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Gradient.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Gradient.hairline, lineWidth: 1)
            )
            .shadow(color: Theme.Shadow.cardColor,
                    radius: elevated ? Theme.Shadow.cardRadius + 6 : Theme.Shadow.cardRadius,
                    x: 0, y: elevated ? Theme.Shadow.cardY + 4 : Theme.Shadow.cardY)
    }
}

extension View {
    func card(padding: CGFloat = Theme.Spacing.lg, elevated: Bool = false) -> some View {
        modifier(CardModifier(padding: padding, elevated: elevated))
    }

    /// Applies the standard dark gradient screen background with a subtle accent glow.
    func screenBackground() -> some View {
        self.background(AppBackground().ignoresSafeArea())
    }
}

/// Dark gradient + faint accent glow used behind every screen.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.Gradient.appBackground
            RadialGradient(
                colors: [Theme.Colors.accent.opacity(0.10), .clear],
                center: .topTrailing, startRadius: 8, endRadius: 360)
            RadialGradient(
                colors: [Theme.Colors.info.opacity(0.06), .clear],
                center: .bottomLeading, startRadius: 8, endRadius: 420)
        }
    }
}
