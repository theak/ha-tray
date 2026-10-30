import HATrayCore
import WebKit

/// A web view that logs into Home Assistant via the frontend's external-auth
/// protocol and starts with the sidebar hidden. Links that leave HA open in the browser.
final class HAWebView: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    private let tokenProvider: () -> String?
    private let baseURLProvider: () -> URL?
    private var tokenRequests = TokenRequestLimiter()
    /// Called when the page keeps asking for the token, i.e. HA is rejecting it.
    var onTokenRejected: (() -> Void)?

    /// Runs before HA's frontend boots so it reads the sidebar preference on startup.
    private static let hideSidebarScript = #"localStorage.setItem("dockedSidebar", JSON.stringify("always_hidden"));"#

    init(tokenProvider: @escaping () -> String?, baseURLProvider: @escaping () -> URL?) {
        self.tokenProvider = tokenProvider
        self.baseURLProvider = baseURLProvider
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController.addUserScript(
            WKUserScript(source: Self.hideSidebarScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        // The frontend switches to external auth when this handler exists.
        let handler = WeakScriptMessageHandler(self)
        config.userContentController.add(handler, name: "getExternalAuth")
        config.userContentController.add(handler, name: "revokeExternalAuth")
    }

    func load(_ url: URL) {
        tokenRequests.reset()
        webView.load(URLRequest(url: url))
    }

    /// Unloads the dashboard so nothing keeps talking to HA.
    func unload() {
        webView.load(URLRequest(url: URL(string: "about:blank")!))
    }

    /// Normalized path of the page currently loaded, e.g. `lovelace/0`.
    var currentPath: String? {
        webView.url.map { HAURLs.normalizedPath($0.path) }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let callback = body["callback"] as? String,
              callback.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }),
              isTrustedFrame(message.frameInfo)
        else { return }

        switch message.name {
        case "getExternalAuth":
            guard tokenRequests.allow() else {
                webView.evaluateJavaScript("window.\(callback)(false);")
                onTokenRejected?()
                return
            }
            guard let token = tokenProvider(), !token.isEmpty,
                  let json = try? JSONSerialization.data(withJSONObject: ["access_token": token, "expires_in": 1800]),
                  let payload = String(data: json, encoding: .utf8)
            else {
                webView.evaluateJavaScript("window.\(callback)(false);")
                return
            }
            webView.evaluateJavaScript("window.\(callback)(true, \(payload));")
        case "revokeExternalAuth":
            webView.evaluateJavaScript("window.\(callback)(true);")
        default:
            break
        }
    }
}

extension HAWebView {
    /// Only HA's own top-level page may ask for the token.
    private func isTrustedFrame(_ frame: WKFrameInfo) -> Bool {
        guard frame.isMainFrame, let base = baseURLProvider() else { return false }
        let origin = frame.securityOrigin
        var components = URLComponents()
        components.scheme = origin.protocol
        components.host = origin.host
        components.port = origin.port == 0 ? nil : origin.port
        return HAURLs.isSameOrigin(components.url, as: base)
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard action.targetFrame?.isMainFrame != false,
              let url = action.request.url, ["http", "https"].contains(url.scheme),
              let base = baseURLProvider(), !HAURLs.isSameOrigin(url, as: base)
        else { return decisionHandler(.allow) }
        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }

    /// `target="_blank"` links and `window.open`: hand off to the browser.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { NSWorkspace.shared.open(url) }
        return nil
    }
}

/// `WKUserContentController` retains its handlers; this breaks the cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
