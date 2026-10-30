import AppKit
import WebKit

/// `--debug-snapshot <dir>`: a few seconds after launch, writes a PNG of the web view
/// and a short page report into <dir>. Used to verify the app without screen recording access.
enum DebugSnapshot {
    static var directory: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--debug-snapshot"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1])
    }

    static func schedule(_ webView: WKWebView, after delay: TimeInterval = 8) {
        guard let dir = directory else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            webView.takeSnapshot(with: nil) { image, error in
                if let error { try? "\(error)".write(to: dir.appendingPathComponent("snapshot-error.txt"), atomically: true, encoding: .utf8) }
                guard let tiff = image?.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
                try? png.write(to: dir.appendingPathComponent("panel.png"))
            }
            let report = """
            (() => {
              const ha = document.querySelector("home-assistant");
              const main = ha?.shadowRoot?.querySelector("home-assistant-main");
              return JSON.stringify({
                url: location.href,
                connected: !!ha?.hass?.connected,
                user: ha?.hass?.user?.name ?? null,
                dockedSidebar: ha?.hass?.dockedSidebar ?? null,
                loginPage: location.pathname.startsWith("/auth"), visible: document.visibilityState, size: [innerWidth, innerHeight],
                sidebarModal: main?.hasAttribute("modal") ?? null,
              });
            })()
            """
            webView.evaluateJavaScript(report) { result, error in
                let text = (result as? String) ?? "error: \(String(describing: error))"
                try? text.write(to: dir.appendingPathComponent("report.json"), atomically: true, encoding: .utf8)
            }
        }
    }
}
