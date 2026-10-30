import Foundation

/// App settings. The token lives in `TokenStore`; everything else in `UserDefaults`.
public final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let tokens: TokenStore

    @Published public var baseURLString: String { didSet { defaults.set(baseURLString, forKey: "baseURLString") } }
    @Published public var token: String {
        didSet {
            if effectiveToken.isEmpty { tokens.delete() } else { try? tokens.save(effectiveToken) }
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

    /// The token with any pasted whitespace removed.
    public var effectiveToken: String { token.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Scheme, host and port of the entered URL; `nil` unless it is http(s) with a host.
    public var baseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = URLComponents(string: trimmed), ["http", "https"].contains(parsed.scheme),
              let host = parsed.host, !host.isEmpty else { return nil }
        var origin = URLComponents()
        origin.scheme = parsed.scheme
        origin.host = host
        origin.port = parsed.port
        return origin.url
    }

    public var isConfigured: Bool { baseURL != nil && !effectiveToken.isEmpty }
}
