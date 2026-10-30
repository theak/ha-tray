import XCTest
@testable import HATrayCore

final class TokenRequestLimiterTests: XCTestCase {
    func testAllowsTwoRequestsPerWindowThenRefuses() {
        var limiter = TokenRequestLimiter(maxRequests: 2, window: 60)
        let t0 = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(limiter.allow(at: t0))
        XCTAssertTrue(limiter.allow(at: t0.addingTimeInterval(5)))
        XCTAssertFalse(limiter.allow(at: t0.addingTimeInterval(10)))
    }

    func testRequestsOutsideWindowDontCount() {
        var limiter = TokenRequestLimiter(maxRequests: 2, window: 60)
        let t0 = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(limiter.allow(at: t0))
        XCTAssertTrue(limiter.allow(at: t0.addingTimeInterval(1800)))
        XCTAssertTrue(limiter.allow(at: t0.addingTimeInterval(3600)))
    }

    func testResetClearsHistory() {
        var limiter = TokenRequestLimiter(maxRequests: 1, window: 60)
        let t0 = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(limiter.allow(at: t0))
        limiter.reset()
        XCTAssertTrue(limiter.allow(at: t0.addingTimeInterval(1)))
    }
}
