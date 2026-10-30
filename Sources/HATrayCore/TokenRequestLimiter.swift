import Foundation

/// Caps how often the dashboard may ask for the token. A long-lived token only needs
/// re-sending on expiry, so a burst of requests means HA keeps rejecting it — and each
/// rejection counts toward HA's IP ban.
public struct TokenRequestLimiter {
    let maxRequests: Int
    let window: TimeInterval
    private var recent: [Date] = []

    public init(maxRequests: Int = 2, window: TimeInterval = 60) {
        self.maxRequests = maxRequests
        self.window = window
    }

    public mutating func allow(at now: Date = Date()) -> Bool {
        recent.removeAll { now.timeIntervalSince($0) >= window }
        guard recent.count < maxRequests else { return false }
        recent.append(now)
        return true
    }

    public mutating func reset() {
        recent.removeAll()
    }
}
