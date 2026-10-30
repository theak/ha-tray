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
    /// Rules with surrounding whitespace trimmed, dropping any with a blank entity or path.
    public static func activeRules(_ rules: [DashboardRule]) -> [DashboardRule] {
        rules.compactMap { rule in
            var rule = rule
            rule.entityID = rule.entityID.trimmingCharacters(in: .whitespacesAndNewlines)
            rule.dashboardPath = rule.dashboardPath.trimmingCharacters(in: .whitespacesAndNewlines)
            return rule.entityID.isEmpty || rule.dashboardPath.isEmpty ? nil : rule
        }
    }

    public static func target(rules: [DashboardRule], fetch: StateFetchResult, defaultPath: String) -> String? {
        let rules = activeRules(rules)
        guard !rules.isEmpty else { return defaultPath }
        guard case .states(let states) = fetch else { return nil }
        return rules.first { states[$0.entityID] == "on" }?.dashboardPath ?? defaultPath
    }
}
