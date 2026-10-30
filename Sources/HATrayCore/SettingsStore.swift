import Foundation

/// App settings. The token lives in `TokenStore`; everything else in `UserDefaults`.
public final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let tokens: TokenStore

    @Published public var baseURLString: String { didSet { defaults.set(baseURLString, forKey: "baseURLString") } }
    @Published public var token: String {
        didSet {
            if token.isEmpty { tokens.delete() } else { try? tokens.save(token) }
        }
    }
    @Published public var defaultDashboardPath: String { didSet { defaults.set(defaultDashboardPath, forKey: "defaultDashboardPath") } }
    @Published public var rules: [DashboardRule] { didSet { defaults.set(try? JSONEncoder().encode(rules), forKey: "rules") } }
    @Published public var panelWidth: Double { didSet { defaults.set(panelWidth, forKey: "panelWidth") } }
    @Published public var panelHeight: Double { didSet { defaults.set(panelHeight, forKey: "panelHeight") } }

    public init(defaults: UserDefaults = .standard, tokens: TokenStore = KeychainTokenStore()) {
        self.defaults = defaults
        self.tokens = tokens
        baseURLString = defaults.string(forKey: "baseURLString") ?? ""
        token = tokens.load() ?? ""
        defaultDashboardPath = defaults.string(forKey: "defaultDashboardPath") ?? "lovelace/0"
        rules = defaults.data(forKey: "rules").flatMap { try? JSONDecoder().decode([DashboardRule].self, from: $0) } ?? []
        panelWidth = defaults.object(forKey: "panelWidth") as? Double ?? 420
        panelHeight = defaults.object(forKey: "panelHeight") as? Double ?? 700
    }

    /// `nil` unless the string is an http(s) URL with a host.
    public var baseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), ["http", "https"].contains(url.scheme), url.host != nil else { return nil }
        return url
    }

    public var isConfigured: Bool { baseURL != nil && !token.isEmpty }
}
