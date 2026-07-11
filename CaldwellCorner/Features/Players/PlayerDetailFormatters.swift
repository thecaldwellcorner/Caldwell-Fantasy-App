import SwiftUI

/// Reusable formatting for player bio + stats. Single source of truth so height
/// conversion etc. is never duplicated.
enum PlayerFormat {
    /// Convert a height (total inches as Int/String, or an already-formatted
    /// value) into feet-inches, e.g. 73 -> 6'1". Returns "—" when unavailable.
    static func height(_ raw: String?) -> String {
        guard let raw else { return "—" }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "—" }
        if s.contains("'") || s.contains("\"") { return s }  // already formatted
        let inches: Int?
        if let i = Int(s) { inches = i } else if let d = Double(s) { inches = Int(d) } else { inches = nil }
        guard let total = inches, total > 0 else { return s }
        return "\(total / 12)'\(total % 12)\""
    }

    static func weight(_ raw: String?) -> String {
        guard let raw else { return "—" }
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "—" }
        return s.lowercased().contains("lb") ? s : "\(s) lb"
    }

    /// Format a number, or "—" when nil. `applicable == false` returns "—" too
    /// (so a stat that doesn't apply to a position never shows a fake 0).
    static func num(_ v: Double?, digits: Int = 0, applicable: Bool = true) -> String {
        guard applicable, let v else { return "—" }
        return String(format: "%.\(digits)f", v)
    }

    static func points(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.1f", v)
    }

    static func kickoff(_ iso: String?) -> String {
        guard let d = parseDate(iso) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · h:mm a"
        return f.string(from: d)
    }

    static func shortDate(_ iso: String?) -> String {
        guard let d = parseDate(iso) else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: d)
    }

    private static func parseDate(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }
}

/// A color grade for a stat cell. Dark-mode friendly (tinted backgrounds, not
/// oversaturated).
enum StatGrade {
    case strong, average, poor, neutral

    var fill: Color {
        switch self {
        case .strong: return Theme.Colors.positive.opacity(0.18)
        case .average: return Theme.Colors.warning.opacity(0.16)
        case .poor: return Theme.Colors.negative.opacity(0.16)
        case .neutral: return Theme.Colors.surfaceElevated
        }
    }
    var text: Color {
        switch self {
        case .strong: return Theme.Colors.positive
        case .average: return Theme.Colors.warning
        case .poor: return Theme.Colors.negative
        case .neutral: return Theme.Colors.textSecondary
        }
    }
}

/// Position-aware weekly grading. Uses reusable per-position thresholds instead
/// of expensive client-side percentile queries. Unavailable values grade neutral
/// (gray), and stats that aren't meaningful for a row are never colored red.
enum FantasyGrade {
    /// Grade a weekly fantasy-point total for a position.
    static func weeklyPoints(_ v: Double?, position: String) -> StatGrade {
        guard let v else { return .neutral }
        let (strong, average): (Double, Double)
        switch position.uppercased() {
        case "QB": (strong, average) = (22, 16)
        case "RB": (strong, average) = (18, 11)
        case "WR": (strong, average) = (16, 9)
        case "TE": (strong, average) = (12, 6)
        default: (strong, average) = (16, 9)
        }
        if v >= strong { return .strong }
        if v >= average { return .average }
        return .poor
    }

    /// Grade the primary yardage cell for a position (pass yds for QB, rush yds
    /// for RB, receiving yds for WR/TE).
    static func primaryYards(_ v: Double?, position: String) -> StatGrade {
        guard let v else { return .neutral }
        let (strong, average): (Double, Double)
        switch position.uppercased() {
        case "QB": (strong, average) = (280, 210)
        case "RB": (strong, average) = (85, 45)
        case "WR", "TE": (strong, average) = (85, 45)
        default: (strong, average) = (85, 45)
        }
        if v >= strong { return .strong }
        if v >= average { return .average }
        return .poor
    }

    /// Touchdowns: 2+ strong, 1 average, 0 is neutral (not "poor") since a
    /// zero-TD game isn't inherently bad.
    static func touchdowns(_ v: Double?) -> StatGrade {
        guard let v else { return .neutral }
        if v >= 2 { return .strong }
        if v >= 1 { return .average }
        return .neutral
    }
}
