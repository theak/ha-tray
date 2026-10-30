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
}
