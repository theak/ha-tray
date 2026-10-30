import XCTest
@testable import HATrayCore

final class MemoryTokenStore: TokenStore {
    var token: String?
    func load() -> String? { token }
    func save(_ token: String) throws { self.token = token }
    func delete() { token = nil }
}

final class SettingsStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var tokens: MemoryTokenStore!

    override func setUp() {
        let suite = "SettingsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        tokens = MemoryTokenStore()
    }

    func makeStore() -> SettingsStore { SettingsStore(defaults: defaults, tokens: tokens) }

    func testDefaults() {
        let s = makeStore()
        XCTAssertEqual(s.defaultDashboardPath, "lovelace/0")
        XCTAssertEqual(s.panelWidth, 420)
        XCTAssertEqual(s.panelHeight, 700)
        XCTAssertEqual(s.rules, [])
        XCTAssertFalse(s.isConfigured)
    }

    func testRoundTrip() {
        let s = makeStore()
        let rule = DashboardRule(entityID: "input_boolean.bedtime", dashboardPath: "lovelace/bedroom")
        s.baseURLString = "http://homeassistant.local:8123"
        s.token = "secret"
        s.defaultDashboardPath = "lovelace/home"
        s.rules = [rule]
        s.panelWidth = 500
        s.panelHeight = 800

        let t = makeStore()
        XCTAssertEqual(t.baseURLString, "http://homeassistant.local:8123")
        XCTAssertEqual(t.token, "secret")
        XCTAssertEqual(tokens.token, "secret")
        XCTAssertEqual(t.defaultDashboardPath, "lovelace/home")
        XCTAssertEqual(t.rules, [rule])
        XCTAssertEqual(t.panelWidth, 500)
        XCTAssertEqual(t.panelHeight, 800)
        XCTAssertTrue(t.isConfigured)
    }

    func testBaseURLRequiresSchemeAndHost() {
        let s = makeStore()
        s.baseURLString = "ha:8123"
        XCTAssertNil(s.baseURL)
        s.baseURLString = " http://homeassistant.local:8123 "
        XCTAssertEqual(s.baseURL?.absoluteString, "http://homeassistant.local:8123")
    }

    func testEmptyTokenDeletes() {
        let s = makeStore()
        s.token = "x"
        s.token = ""
        XCTAssertNil(tokens.token)
    }

    func testTokenIsTrimmedWhenSaved() {
        let s = makeStore()
        s.token = "secret\n"
        XCTAssertEqual(tokens.token, "secret")
        XCTAssertEqual(s.effectiveToken, "secret")
    }

    func testBaseURLKeepsOnlySchemeHostPort() {
        let s = makeStore()
        s.baseURLString = "http://ha:8123/lovelace/0?x=1\n"
        XCTAssertEqual(s.baseURL?.absoluteString, "http://ha:8123")
    }
}
