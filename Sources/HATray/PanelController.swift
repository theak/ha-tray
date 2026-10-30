import AppKit
import HATrayCore

/// The transient popover that hosts the dashboard.
final class PanelController {
    private let settings: SettingsStore
    private let popover = NSPopover()
    private let web: HAWebView
    private var loadedBase: URL?
    private var escapeMonitor: Any?
    private var isOpening = false

    init(settings: SettingsStore) {
        self.settings = settings
        web = HAWebView(tokenProvider: { [settings] in settings.token })
        popover.behavior = .transient
        let controller = NSViewController()
        controller.view = web.webView
        popover.contentViewController = controller
        DebugSnapshot.schedule(web.webView)
    }

    var isShown: Bool { popover.isShown }

    /// The dashboard currently loaded, for opening in a browser.
    var currentURL: URL? { web.webView.url }

    func toggle(relativeTo button: NSStatusBarButton) {
        isShown ? close() : show(relativeTo: button)
    }

    /// Picks the dashboard from the rules (bounded by the fetch timeout), then shows the popover.
    func show(relativeTo button: NSStatusBarButton) {
        guard let base = settings.baseURL, !isOpening else { return }
        isOpening = true
        let rules = settings.rules
        let defaultPath = settings.defaultDashboardPath
        let client = HAClient(baseURL: base, token: settings.token)
        Task { @MainActor in
            let fetch = await client.fetchStates(Array(Set(rules.map(\.entityID))))
            var target = RuleEvaluator.target(rules: rules, fetch: fetch, defaultPath: defaultPath)
            if loadedBase != base || web.webView.url == nil {
                loadedBase = base
                target = target ?? defaultPath
            } else if let t = target, HAURLs.isShowing(currentPath: web.currentPath, target: t) {
                target = nil
            }
            if let target { web.load(HAURLs.dashboard(base: base, path: target)) }
            isOpening = false
            present(relativeTo: button)
        }
    }

    private func present(relativeTo button: NSStatusBarButton) {
        popover.contentSize = NSSize(width: settings.panelWidth, height: settings.panelHeight)
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, let self, self.popover.isShown else { return event }
            self.close()
            return nil
        }
    }

    func close() {
        popover.performClose(nil)
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }

    func reload() {
        web.webView.reload()
    }
}
