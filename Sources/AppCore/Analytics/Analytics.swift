import Foundation

// MARK: - Analytics (PostHog)
//
// Lightweight, dependency-free PostHog client: events are POSTed to PostHog's
// HTTP capture endpoint, so there's no SDK to vendor and it builds cross-platform.
//
// Configuration comes from Info.plist (`PostHogProjectKey`, optional `PostHogHost`).
// The project key is a write-only client key — safe to ship in the app. If no key
// is set (e.g. in tests / scenario captures / before you configure it), analytics
// is disabled and `capture` is a silent no-op — so it never makes network calls
// in the preview/test environment.
//
// Privacy note: events are keyed to a random anonymous identifier (Keychain), NOT
// to your name, email, or Apple ID. Health/activity data is never sent here — only
// product-usage events (screens opened, features connected). This is disclosed in
// the privacy policy (analytics is on by default per the product decision).
public final class Analytics {
    public static let shared = Analytics()

    private let projectKey: String
    private let host: URL
    private let distinctID: String
    private let enabled: Bool

    private init() {
        let info = Bundle.main.infoDictionary
        projectKey = (info?["PostHogProjectKey"] as? String) ?? ""
        let hostString = (info?["PostHogHost"] as? String) ?? "https://us.i.posthog.com"
        host = URL(string: hostString) ?? URL(string: "https://us.i.posthog.com")!
        enabled = !projectKey.isEmpty

        // Anonymous, stable per-install id (reuses the Keychain seam).
        let store = KeychainTokenStore()
        let account = "otterpace-analytics-id"
        if let existing = store.read(account), !existing.isEmpty {
            distinctID = existing
        } else {
            let fresh = UUID().uuidString
            store.save(fresh, account: account)
            distinctID = fresh
        }
    }

    /// Capture a product-usage event. No-op when unconfigured. Never send PII or
    /// health/activity data in `properties`.
    public func capture(_ event: String, _ properties: [String: String] = [:]) {
        guard enabled else { return }
        var props = properties
        props["$lib"] = "otterpace-ios"
        let payload: [String: Any] = [
            "api_key": projectKey,
            "event": event,
            "distinct_id": distinctID,
            "properties": props,
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: host.appendingPathComponent("capture/"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        // Fire-and-forget on a detached task: a failed send must never affect the
        // app, and we don't read/log the response (it could echo request data).
        Task.detached { _ = try? await URLSession.shared.data(for: request) }
    }
}
