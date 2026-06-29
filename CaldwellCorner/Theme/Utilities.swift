import Foundation

extension Date {
    /// Compact relative timestamp, e.g. "5m ago", "3h ago", "2d ago".
    var relativeShort: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 0 { return "soon" }
        let minutes = Int(interval / 60)
        if minutes < 60 { return "\(max(1, minutes))m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        return "\(hours / 24)d ago"
    }
}

extension String {
    /// Up-to-two-letter uppercase initials from the first two words.
    var initials: String {
        split(separator: " ")
            .compactMap { $0.first.map(String.init) }
            .prefix(2)
            .joined()
            .uppercased()
    }
}
