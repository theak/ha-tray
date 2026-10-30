import Foundation

/// "If `entityID` is on, show `dashboardPath`."
public struct DashboardRule: Codable, Identifiable, Equatable {
    public var id: UUID
    public var entityID: String
    public var dashboardPath: String

    public init(id: UUID = UUID(), entityID: String, dashboardPath: String) {
        self.id = id
        self.entityID = entityID
        self.dashboardPath = dashboardPath
    }
}

/// Entity states keyed by entity ID. Entities that failed individually are absent.
public enum StateFetchResult: Equatable {
    case states([String: String])
    case failed
}

public enum RuleEvaluator {
    /// The dashboard path to show, or `nil` to leave the web view where it is.
    public static func target(rules: [DashboardRule], fetch: StateFetchResult, defaultPath: String) -> String? {
        guard !rules.isEmpty else { return defaultPath }
        guard case .states(let states) = fetch else { return nil }
        return rules.first { states[$0.entityID] == "on" }?.dashboardPath ?? defaultPath
    }
}
