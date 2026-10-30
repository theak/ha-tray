import XCTest
@testable import HATrayCore

final class HAURLsTests: XCTestCase {
    func testDashboardJoinsTrailingAndLeadingSlashes() {
        let url = HAURLs.dashboard(base: URL(string: "http://ha:8123/")!, path: "/lovelace/0")
        XCTAssertEqual(url.absoluteString, "http://ha:8123/lovelace/0")
    }

    func testDashboardWithoutSlashes() {
        let url = HAURLs.dashboard(base: URL(string: "http://ha:8123")!, path: "lovelace/0")
        XCTAssertEqual(url.absoluteString, "http://ha:8123/lovelace/0")
    }

    func testAPI() {
        let url = HAURLs.api(base: URL(string: "http://ha:8123/")!, "states/input_boolean.x")
        XCTAssertEqual(url.absoluteString, "http://ha:8123/api/states/input_boolean.x")
    }

    func testNormalizedPath() {
        XCTAssertEqual(HAURLs.normalizedPath("/lovelace/bedroom/"), "lovelace/bedroom")
    }

    func testIsShowingMatchesExactAndRedirectedSubpath() {
        XCTAssertTrue(HAURLs.isShowing(currentPath: "lovelace/bedroom", target: "/lovelace/bedroom"))
        XCTAssertTrue(HAURLs.isShowing(currentPath: "dashboard-cameras/0", target: "dashboard-cameras"))
        XCTAssertFalse(HAURLs.isShowing(currentPath: "lovelace-music/0", target: "lovelace"))
        XCTAssertFalse(HAURLs.isShowing(currentPath: "lovelace/30", target: "lovelace/3"))
        XCTAssertFalse(HAURLs.isShowing(currentPath: nil, target: "lovelace/0"))
    }

    func testIsSameOrigin() {
        let base = URL(string: "http://homeassistant.local:8123")!
        XCTAssertTrue(HAURLs.isSameOrigin(URL(string: "http://homeassistant.local:8123/lovelace/0"), as: base))
        XCTAssertFalse(HAURLs.isSameOrigin(URL(string: "https://evil.example/x"), as: base))
        XCTAssertFalse(HAURLs.isSameOrigin(URL(string: "http://homeassistant.local:8124/"), as: base))
        XCTAssertFalse(HAURLs.isSameOrigin(URL(string: "https://homeassistant.local:8123/"), as: base))
        XCTAssertFalse(HAURLs.isSameOrigin(nil, as: base))
    }
}
