import Foundation

// MARK: - Backend session token (Sign in with Apple → bearer)
//
// The account-sync backend authenticates every request with a bearer token, not
// the (non-secret) Apple user id. This is the client half of that handshake:
//
//   1. At sign-in the app has Apple's short-lived identity token (a JWT).
//   2. `establish(identityToken:)` POSTs it once to /api/account/session, which
//      verifies it server-side and returns a long-lived bearer token.
//   3. The bearer is stored in the Keychain and attached as `Authorization:
//      Bearer …` on every account/* request (see URLSessionAccountSyncTransport).
//   4. `revoke()` deletes it server-side and locally on sign-out.
//
// All of this is OPTIONAL and best-effort: if establishment fails (offline, no
// backend), account sync simply stays off and the app remains fully local. The
// Keychain + HTTP seams are injectable so the logic is unit-testable.

/// Keychain-backed storage for the bearer session token, reusing the
/// `TokenStoring` seam so tests can inject an in-memory store.
public struct AccountSessionStore {
    public static let account = "otterpace.accountSessionToken"

    private let tokens: TokenStoring
    public init(tokens: TokenStoring = KeychainTokenStore()) { self.tokens = tokens }

    public func token() -> String? {
        let value = tokens.read(Self.account)
        return (value?.isEmpty == false) ? value : nil
    }
    public func save(_ token: String) { tokens.save(token, account: Self.account) }
    public func clear() { tokens.delete(Self.account) }
}

/// Establishes and revokes the backend session. Network + storage are injected so
/// this is testable without a real backend or Keychain.
public final class AccountSessionService {
    private let store: AccountSessionStore
    private let session: URLSession
    private let base: URL

    public init(store: AccountSessionStore = AccountSessionStore(),
                session: URLSession = .shared,
                base: URL = AccountSyncConfig.apiBase) {
        self.store = store
        self.session = session
        self.base = base
    }

    /// The current bearer token, if a session has been established.
    public func currentToken() -> String? { store.token() }

    /// Exchange an Apple identity token for a backend bearer and store it. Returns
    /// true on success. Best-effort: any failure leaves sync simply disabled.
    @discardableResult
    public func establish(identityToken: String) async -> Bool {
        guard !identityToken.isEmpty else { return false }
        var request = URLRequest(url: base.appendingPathComponent("account/session"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["identityToken": identityToken])
        do {
            let (data, resp) = try await session.data(for: request)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = obj["token"] as? String, !token.isEmpty
            else { return false }
            store.save(token)
            return true
        } catch {
            return false
        }
    }

    /// Revoke the session server-side (best-effort) and forget it locally.
    public func revoke() async {
        if let token = store.token() {
            var request = URLRequest(url: base.appendingPathComponent("account/session"))
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await session.data(for: request)
        }
        store.clear()
    }
}
