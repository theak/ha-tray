import Foundation

/// App settings. The token lives in `TokenStore`; everything else in `UserDefaults`.
public final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let tokens: TokenStore

    @Published public var baseURLString: String { didSet { defaults.set(baseURLString, forKey: "baseURLString") } }
    /// The saved token. Change it only through `applyToken` after validating it with HA.
    @Published public private(set) var token: String
    /// The last keychain read failure, for display in Settings.
    @Published public private(set) var tokenError: String?
    /// HA rejected the token. No requests are made until a new token is applied or a retry succeeds.
    @Published public var authFailed: Bool { didSet { defaults.set(authFailed, forKey: "authFailed") } }
    @Published public var defaultDashboardPath: String { didSet { defaults.set(defaultDashboardPath, forKey: "defaultDashboardPath") } }
    @Published public var rules: [DashboardRule] { didSet { defaults.set(try? JSONEncoder().encode(rules), forKey: "rules") } }
    @Published public var panelWidth: Double { didSet { defaults.set(panelWidth, forKey: "panelWidth") } }
    @Published public var panelHeight: Double { didSet { defaults.set(panelHeight, forKey: "panelHeight") } }
    /// Page zoom for the dashboard; below 1 fits more of it in the panel.
    @Published public var panelZoom: Double { didSet { defaults.set(panelZoom, forKey: "panelZoom") } }

    public init(defaults: UserDefaults = .standard, tokens: TokenStore = KeychainTokenStore()) {
        self.defaults = defaults
        self.tokens = tokens
        baseURLString = defaults.string(forKey: "baseURLString") ?? ""
        do {
            token = try tokens.load() ?? ""
        } catch {
            token = ""
            tokenError = error.localizedDescription
        }
        authFailed = defaults.bool(forKey: "authFailed")
        defaultDashboardPath = defaults.string(forKey: "defaultDashboardPath") ?? "lovelace/0"
        rules = defaults.data(forKey: "rules").flatMap { try? JSONDecoder().decode([DashboardRule].self, from: $0) } ?? []
        panelWidth = defaults.object(forKey: "panelWidth") as? Double ?? 420
        panelHeight = defaults.object(forKey: "panelHeight") as? Double ?? 700
        panelZoom = defaults.object(forKey: "panelZoom") as? Double ?? 1.0
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

    /// Whether requests to HA may be made right now.
    public var canConnect: Bool { isConfigured && !authFailed }

    /// Saves a token the caller has already validated against HA, and clears any auth failure.
    public func applyToken(_ candidate: String) throws {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HAError.unauthorized }
        try tokens.save(trimmed)
        token = trimmed
        tokenError = nil
        authFailed = false
    }
}
