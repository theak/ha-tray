import HATrayCore
import WebKit

/// A web view that logs into Home Assistant via the frontend's external-auth
/// protocol and starts with the sidebar hidden.
final class HAWebView: NSObject, WKScriptMessageHandler {
    let webView: WKWebView
    private let tokenProvider: () -> String?

    /// Runs before HA's frontend boots so it reads the sidebar preference on startup.
    private static let hideSidebarScript = #"localStorage.setItem("dockedSidebar", JSON.stringify("always_hidden"));"#

    init(tokenProvider: @escaping () -> String?) {
        self.tokenProvider = tokenProvider
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.userContentController.addUserScript(
            WKUserScript(source: Self.hideSidebarScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        // The frontend switches to external auth when this handler exists.
        let handler = WeakScriptMessageHandler(self)
        config.userContentController.add(handler, name: "getExternalAuth")
        config.userContentController.add(handler, name: "revokeExternalAuth")
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    /// Normalized path of the page currently loaded, e.g. `lovelace/0`.
    var currentPath: String? {
        webView.url.map { HAURLs.normalizedPath($0.path) }
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let callback = body["callback"] as? String,
              callback.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
        else { return }

        switch message.name {
        case "getExternalAuth":
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

/// `WKUserContentController` retains its handlers; this breaks the cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(_ target: WKScriptMessageHandler) { self.target = target }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}
