import XCTest
@testable import AppCore

// Tests for the M3/M5 integration modules' pure logic: reminder preferences,
// the BYO-coach-key store, and the RemoteCoach HTTP-status → CoachError mapping
// (the network call is stubbed via URLProtocol so no real request is made).

// MARK: - ReminderSettings

final class ReminderSettingsTests: XCTestCase {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "ReminderSettingsTests.\(UUID().uuidString)")!
    }

    // A fresh install has every reminder off, with sensible default times.
    func testDefaultsAreOff() {
        let s = ReminderSettings.load(defaults())
        XCTAssertFalse(s.dailyEnabled)
        XCTAssertFalse(s.goalEnabled)
        XCTAssertFalse(s.inactivityEnabled)
        XCTAssertFalse(s.anyEnabled)
        XCTAssertEqual(s.dailyHour, ReminderSettings.defaultDailyHour)
        XCTAssertEqual(s.inactivityHours, ReminderSettings.defaultInactivityHours)
    }

    // save() then load() round-trips every field exactly.
    func testSaveLoadRoundTrip() {
        let d = defaults()
        let s = ReminderSettings(dailyEnabled: true, dailyHour: 7, dailyMinute: 30,
                                 goalEnabled: true, inactivityEnabled: true, inactivityHours: 4)
        s.save(d)
        XCTAssertEqual(ReminderSettings.load(d), s)
        XCTAssertTrue(ReminderSettings.load(d).anyEnabled)
    }

    // An explicitly-set midnight (hour 0) is preserved, not mistaken for "unset".
    func testMidnightDailyHourPreserved() {
        let d = defaults()
        ReminderSettings(dailyEnabled: true, dailyHour: 0, dailyMinute: 0).save(d)
        XCTAssertEqual(ReminderSettings.load(d).dailyHour, 0)
    }
}

// MARK: - CoachKeyStore

final class CoachKeyStoreTests: XCTestCase {
    private final class MemoryTokens: TokenStoring {
        var store: [String: String] = [:]
        func read(_ account: String) -> String? { store[account] }
        func save(_ value: String, account: String) { store[account] = value }
        func delete(_ account: String) { store[account] = nil }
    }

    // With no key saved, the store reports not-connected.
    func testEmptyIsNotConnected() {
        let s = CoachKeyStore(store: MemoryTokens())
        XCTAssertNil(s.key)
        XCTAssertFalse(s.isConnected)
    }

    // Saving a key trims surrounding whitespace and reports connected.
    func testSaveTrimsAndConnects() {
        let s = CoachKeyStore(store: MemoryTokens())
        s.save("  sk-ant-abc  ")
        XCTAssertEqual(s.key, "sk-ant-abc")
        XCTAssertTrue(s.isConnected)
    }

    // clear() removes the key.
    func testClear() {
        let s = CoachKeyStore(store: MemoryTokens())
        s.save("sk-ant-xyz")
        s.clear()
        XCTAssertNil(s.key)
        XCTAssertFalse(s.isConnected)
    }

    // A whitespace-only entry trims to empty, so it's treated as no key.
    func testWhitespaceSaveIsNotConnected() {
        let s = CoachKeyStore(store: MemoryTokens())
        s.save("    ")
        XCTAssertNil(s.key)
        XCTAssertFalse(s.isConnected)
    }
}

// MARK: - RemoteCoach status mapping

final class RemoteCoachTests: XCTestCase {
    private func makeCoach() -> RemoteCoach {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return RemoteCoach(endpoint: URL(string: "https://example.com/api/coach")!,
                           session: URLSession(configuration: config))
    }

    private func respond(status: Int, body: String) {
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
    }

    override func tearDown() {
        StubURLProtocol.responder = nil
        super.tearDown()
    }

    // A 200 with a valid body decodes into a CoachReply.
    func testSuccessDecodes() async throws {
        respond(status: 200, body: #"{"text":"Easy walk today.","mood":"recovery","safetyFlag":true}"#)
        let reply = try await makeCoach().reply(to: "should I rest?", context: .empty, apiKey: "k")
        XCTAssertEqual(reply.text, "Easy walk today.")
        XCTAssertEqual(reply.mood, .recovery)
        XCTAssertTrue(reply.safetyFlag)
    }

    // 401 is the only status that means "your key was rejected".
    func test401IsInvalidKey() async {
        respond(status: 401, body: "{}")
        await assertThrows(.invalidKey)
    }

    // 429 maps to rateLimited.
    func test429IsRateLimited() async {
        respond(status: 429, body: "{}")
        await assertThrows(.rateLimited)
    }

    // A 400 is a server-side/request bug, NOT the user's key — must not say "invalid key".
    func test400IsServerNotInvalidKey() async {
        respond(status: 400, body: "{}")
        await assertThrows(.server)
    }

    // A 200 with malformed JSON is a server error (caller falls back to the mock).
    func testMalformedBodyIsServer() async {
        respond(status: 200, body: "not json")
        await assertThrows(.server)
    }

    private func assertThrows(_ expected: CoachError,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await makeCoach().reply(to: "hi", context: .empty, apiKey: "k")
            XCTFail("expected \(expected) to be thrown", file: file, line: line)
        } catch let error as CoachError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected error \(error)", file: file, line: line)
        }
    }
}

/// Minimal URLProtocol stub: returns whatever `responder` produces for a request.
private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responder: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let responder = StubURLProtocol.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = responder(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
