import Foundation

/// Minimal Supabase Auth (GoTrue) client for ANONYMOUS sessions. The RLS
/// policies on the fantasy_* tables require an authenticated user, so the app
/// signs in anonymously and reuses that session across launches. Uses only the
/// public publishable key (no secret keys). The authenticated user's UUID is
/// used as `app_user_id` — never a random or hardcoded UUID.
actor SupabaseAuth {
    static let shared = SupabaseAuth()

    struct Session: Codable {
        let accessToken: String
        let refreshToken: String
        let userId: String
        let expiresAt: Date
        /// Valid with a 60s safety margin.
        var isValid: Bool { expiresAt > Date().addingTimeInterval(60) }
    }

    enum AuthError: LocalizedError {
        case notConfigured
        case anonymousDisabled
        case http(Int, String)
        case transport(Error)
        case decoding

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Supabase isn't configured (URL/anon key)."
            case .anonymousDisabled:
                return "Anonymous sign-in is disabled for this project. Enable it in Supabase → Authentication → Providers → Anonymous."
            case .http(let code, _):
                return "Supabase auth failed (HTTP \(code))."
            case .transport(let e):
                return "Network error: \(e.localizedDescription)"
            case .decoding:
                return "Supabase auth returned an unexpected response."
            }
        }
    }

    private var session: Session?
    private let sessionKey = "ciq.supabaseSession"

    init() {
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let saved = try? JSONDecoder().decode(Session.self, from: data) {
            session = saved
        }
    }

    /// The current authenticated user id (nil until a session exists).
    func currentUserId() -> String? { session?.userId }

    /// Ensure a valid session exists (refresh if expired, else sign in
    /// anonymously). Reused across launches via persisted tokens.
    @discardableResult
    func ensureSession() async throws -> Session {
        if let s = session, s.isValid {
            return s
        }
        if let s = session, let refreshed = try? await refresh(s.refreshToken) {
            save(refreshed)
            #if DEBUG
            print("🔐 Supabase auth: refreshed session for user id \(refreshed.userId)")
            #endif
            return refreshed
        }
        let created = try await signInAnonymously()
        save(created)
        #if DEBUG
        print("🔐 Supabase auth: signed in anonymously — user id \(created.userId)")
        #endif
        return created
    }

    func accessToken() async throws -> String { try await ensureSession().accessToken }

    // MARK: - Requests

    private struct TokenResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let user: User?
        struct User: Decodable { let id: String }
    }

    private func signInAnonymously() async throws -> Session {
        try await postAuth(path: "/signup", jsonBody: Data("{}".utf8))
    }

    private func refresh(_ refreshToken: String) async throws -> Session {
        let body = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        return try await postAuth(path: "/token?grant_type=refresh_token", jsonBody: body)
    }

    private func postAuth(path: String, jsonBody: Data) async throws -> Session {
        guard SupabaseConfig.isConfigured,
              let root = URL(string: SupabaseConfig.baseURL.trimmingCharacters(in: .whitespaces))
        else { throw AuthError.notConfigured }

        let authBase = root.appendingPathComponent("auth").appendingPathComponent("v1")
        guard let url = URL(string: authBase.absoluteString + path) else { throw AuthError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let key = SupabaseConfig.anonKey
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonBody

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.transport(error)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            #if DEBUG
            print("❌ Supabase auth HTTP \(http.statusCode): \(body.prefix(300))")
            #endif
            if http.statusCode == 422, body.lowercased().contains("anonymous") {
                throw AuthError.anonymousDisabled
            }
            throw AuthError.http(http.statusCode, body)
        }

        guard let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data),
              let accessToken = decoded.access_token,
              let refreshToken = decoded.refresh_token,
              let userId = decoded.user?.id
        else { throw AuthError.decoding }

        return Session(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId,
            expiresAt: Date().addingTimeInterval(Double(decoded.expires_in ?? 3600))
        )
    }

    private func save(_ session: Session) {
        self.session = session
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }
}
