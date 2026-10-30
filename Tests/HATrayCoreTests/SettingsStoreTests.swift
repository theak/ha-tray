import XCTest
@testable import HATrayCore

final class MemoryTokenStore: TokenStore {
    var token: String?
    var failLoad = false
    var failSave = false
    func load() throws -> String? {
        if failLoad { throw KeychainError(status: -25293) }
        return token
    }
    func save(_ token: String) throws {
        if failSave { throw KeychainError(status: -25308) }
        self.token = token
    }
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
        try? s.applyToken("secret")
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

    func testApplyTokenTrimsSavesAndClearsAuthFailure() throws {
        let s = makeStore()
        s.baseURLString = "http://ha:8123"
        s.authFailed = true
        try s.applyToken(" secret\n")
        XCTAssertEqual(tokens.token, "secret")
        XCTAssertEqual(s.token, "secret")
        XCTAssertFalse(s.authFailed)
        XCTAssertTrue(s.canConnect)
    }

    func testApplyEmptyTokenIsRejectedAndKeepsSavedToken() {
        tokens.token = "saved"
        let s = makeStore()
        XCTAssertThrowsError(try s.applyToken("  "))
        XCTAssertEqual(tokens.token, "saved")
    }

    func testAuthFailedPersistsAndBlocksConnecting() throws {
        let s = makeStore()
        s.baseURLString = "http://ha:8123"
        try s.applyToken("secret")
        s.authFailed = true
        XCTAssertFalse(s.canConnect)
        let t = makeStore()
        XCTAssertTrue(t.authFailed)
        XCTAssertTrue(t.isConfigured)
        XCTAssertFalse(t.canConnect)
    }

    func testLoadFailureIsReportedAndKeepsSavedToken() {
        tokens.token = "saved"
        tokens.failLoad = true
        let s = makeStore()
        XCTAssertEqual(s.token, "")
        XCTAssertNotNil(s.tokenError)
        XCTAssertEqual(tokens.token, "saved")
    }

    func testSaveFailureThrowsAndKeepsOldToken() {
        tokens.token = "old"
        let s = makeStore()
        tokens.failSave = true
        XCTAssertThrowsError(try s.applyToken("new"))
        XCTAssertEqual(s.token, "old")
    }

    func testBaseURLKeepsOnlySchemeHostPort() {
        let s = makeStore()
        s.baseURLString = "http://ha:8123/lovelace/0?x=1\n"
        XCTAssertEqual(s.baseURL?.absoluteString, "http://ha:8123")
    }
}
