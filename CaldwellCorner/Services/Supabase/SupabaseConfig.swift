import Foundation

/// Configuration for the app's read-only connection to Supabase.
///
/// SECURITY: The iOS app uses ONLY the public **anon / publishable** key. That
/// key is designed to be shipped in clients and is safe to embed here. The
/// **service_role** key must NEVER appear in the app — it bypasses Row Level
/// Security and belongs only on the server (see `backend/scripts`).
///
/// Values resolve in this order:
///   1. `Info.plist` keys `SUPABASE_URL` / `SUPABASE_ANON_KEY` (recommended;
///      set them via build settings or an xcconfig so they're not hardcoded).
///   2. The fallback constants below (edit them for quick local testing).
enum SupabaseConfig {
    /// Fallbacks — replace with your project's values, or leave as-is and set
    /// the `Info.plist` keys instead. Find both in Supabase → Project Settings → API.
    private static let fallbackURL = "https://YOUR_PROJECT_REF.supabase.co"
    private static let fallbackAnonKey = "YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY"

    static var baseURL: String {
        infoValue("SUPABASE_URL") ?? fallbackURL
    }

    /// The public anon/publishable key. NOT the service_role key.
    static var anonKey: String {
        infoValue("SUPABASE_ANON_KEY") ?? fallbackAnonKey
    }

    /// The PostgREST base, e.g. `https://xyz.supabase.co/rest/v1`.
    static var restURL: URL? {
        URL(string: baseURL.trimmingCharacters(in: .whitespaces))?
            .appendingPathComponent("rest")
            .appendingPathComponent("v1")
    }

    /// True once real values are present (so we can show a helpful error state
    /// instead of firing requests at a placeholder host).
    static var isConfigured: Bool {
        let url = baseURL
        let key = anonKey
        return url.hasPrefix("https://")
            && !url.contains("YOUR_PROJECT")
            && !key.isEmpty
            && !key.contains("YOUR_")
    }

    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
