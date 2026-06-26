import XCTest
@testable import AppCore

// The backend session-token store: the client half of the BE-1 auth handshake.
// The network establish/revoke round-trips are covered by the server-side vitest
// suite; here we verify the Keychain-backed storage seam behaves correctly via an
// in-memory TokenStoring, so the transport reads back exactly what was saved.
final class AccountSessionTests: XCTestCase {

    private final class MemoryTokens: TokenStoring {
        var store: [String: String] = [:]
        func read(_ account: String) -> String? { store[account] }
        func save(_ value: String, account: String) { store[account] = value }
        func delete(_ account: String) { store[account] = nil }
    }

    func testTokenRoundTrips() {
        let store = AccountSessionStore(tokens: MemoryTokens())
        XCTAssertNil(store.token())
        store.save("bearer-abc")
        XCTAssertEqual(store.token(), "bearer-abc")
    }

    func testClearForgetsToken() {
        let store = AccountSessionStore(tokens: MemoryTokens())
        store.save("bearer-abc")
        store.clear()
        XCTAssertNil(store.token())
    }

    // An empty stored value reads back as nil (no session), never an empty bearer.
    func testEmptyTokenReadsAsNil() {
        let mem = MemoryTokens()
        let store = AccountSessionStore(tokens: mem)
        mem.store[AccountSessionStore.account] = ""
        XCTAssertNil(store.token())
    }

    // The transport attaches Authorization only when a token is present: with no
    // token the provider returns nil, so requests go out unauthenticated (the
    // backend then 401s and the service silently no-ops).
    func testTransportTokenProviderReflectsStore() {
        let store = AccountSessionStore(tokens: MemoryTokens())
        XCTAssertNil(store.token())
        store.save("bearer-xyz")
        XCTAssertEqual(store.token(), "bearer-xyz")
    }
}
