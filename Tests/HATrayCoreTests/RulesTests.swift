import XCTest
@testable import HATrayCore

final class RulesTests: XCTestCase {
    let a = "input_boolean.a"
    let b = "input_boolean.b"
    var rules: [DashboardRule] {
        [
            DashboardRule(entityID: a, dashboardPath: "lovelace/bedroom"),
            DashboardRule(entityID: b, dashboardPath: "lovelace/kitchen"),
        ]
    }

    func target(_ fetch: StateFetchResult, rules: [DashboardRule]? = nil) -> String? {
        RuleEvaluator.target(rules: rules ?? self.rules, fetch: fetch, defaultPath: "lovelace/0")
    }

    func testFirstMatchingRuleWins() {
        XCTAssertEqual(target(.states([a: "on", b: "on"])), "lovelace/bedroom")
    }

    func testSkipsNonMatching() {
        XCTAssertEqual(target(.states([a: "off", b: "on"])), "lovelace/kitchen")
    }

    func testMissingEntityDoesNotMatch() {
        XCTAssertEqual(target(.states([b: "on"])), "lovelace/kitchen")
    }

    func testNoMatchReturnsDefault() {
        XCTAssertEqual(target(.states([a: "off"])), "lovelace/0")
    }

    func testOnlyExactOnMatches() {
        for state in ["unavailable", "unknown", "On", "true"] {
            XCTAssertEqual(target(.states([a: state, b: state])), "lovelace/0", state)
        }
    }

    func testTotalFailureReturnsNil() {
        XCTAssertNil(target(.failed))
    }

    func testNoRulesReturnsDefaultWithoutFetchFailureMattering() {
        XCTAssertEqual(target(.failed, rules: []), "lovelace/0")
    }
}
