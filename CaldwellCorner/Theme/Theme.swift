import SwiftUI

/// Central design system for Caldwell Corner Fantasy Football.
/// A dark, broadcast-inspired theme with an electric green accent.
enum Theme {

    // MARK: - Colors
    enum Colors {
        static let background = Color(hex: 0x0B0F14)
        static let surface = Color(hex: 0x141B24)
        static let surfaceElevated = Color(hex: 0x1C2530)
        static let stroke = Color(hex: 0x263241)

        static let accent = Color(hex: 0x1EF266)        // electric green
        static let accentSecondary = Color(hex: 0xF2C200) // gold
        static let info = Color(hex: 0x4DA3FF)

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
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let pill: CGFloat = 999
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
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .stroke(Theme.Colors.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = Theme.Spacing.lg) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// Applies the standard dark scrolling screen background.
    func screenBackground() -> some View {
        self.background(Theme.Colors.background.ignoresSafeArea())
    }
}
