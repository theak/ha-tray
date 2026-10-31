import AppKit
import HATrayCore

/// The transient popover that hosts the dashboard.
final class PanelController: NSObject, NSPopoverDelegate {
    private let settings: SettingsStore
    private let popover = NSPopover()
    private let web: HAWebView
    private var loadedBase: URL?
    private var escapeMonitor: Any?
    private var isOpening = false
    private var lastClosed = Date.distantPast
    /// Called when the panel can't be used (not set up, or HA rejected the token).
    var onNeedsSettings: (() -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
        web = HAWebView(tokenProvider: { [settings] in settings.authFailed ? nil : settings.effectiveToken },
                        baseURLProvider: { [settings] in settings.baseURL })
        super.init()
        web.onTokenRejected = { [weak self] in self?.authenticationFailed() }
        popover.behavior = .transient
        popover.delegate = self
        let controller = NSViewController()
        controller.view = web.webView
        popover.contentViewController = controller
        DebugSnapshot.schedule(web.webView)
    }

    var isShown: Bool { popover.isShown }

    /// The dashboard currently loaded, for opening in a browser.
    var currentURL: URL? { web.webView.url }

    func toggle(relativeTo button: NSStatusBarButton) {
        if isShown {
            close()
        } else if Date().timeIntervalSince(lastClosed) > 0.3 {
            // A click on the status item first closes the transient popover on mouse-down;
            // don't let the same click's mouse-up reopen it.
            show(relativeTo: button)
        }
    }

    /// Picks the dashboard from the rules (bounded by the fetch timeout), then shows the popover.
    func show(relativeTo button: NSStatusBarButton) {
        guard !isOpening else { return }
        guard settings.canConnect, let base = settings.baseURL else {
            onNeedsSettings?()
            return
        }
        isOpening = true
        let rules = settings.rules
        let defaultPath = settings.defaultDashboardPath
        let client = HAClient(baseURL: base, token: settings.effectiveToken)
        Task { @MainActor in
            let fetch = await client.fetchStates(Array(Set(RuleEvaluator.activeRules(rules).map(\.entityID))))
            if fetch == .unauthorized {
                isOpening = false
                authenticationFailed()
                return
            }
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
        web.webView.pageZoom = settings.panelZoom
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        removeEscapeMonitor()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, let self, self.popover.isShown else { return event }
            self.close()
            return nil
        }
    }

    func close() {
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        lastClosed = Date()
        removeEscapeMonitor()
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
    }

    func reload() {
        guard settings.canConnect else { return onNeedsSettings?() ?? () }
        web.webView.reload()
    }

    /// Stops all traffic to HA until the user fixes or retries the token.
    private func authenticationFailed() {
        settings.authFailed = true
        close()
        web.unload()
        loadedBase = nil
        onNeedsSettings?()
    }
}
