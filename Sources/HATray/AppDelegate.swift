import AppKit
import Combine
import HATrayCore
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private var statusItem: NSStatusItem!
    private var panel: PanelController!
    private var settingsWindow: SettingsWindowController!
    private var authObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController(settings: settings)
        settingsWindow = SettingsWindowController(settings: settings)
        panel.onNeedsSettings = { [weak self] in self?.settingsWindow.show() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            authObserver = settings.$authFailed.sink { failed in
                button.image = NSImage(
                    systemSymbolName: failed ? "exclamationmark.triangle.fill" : "house.fill",
                    accessibilityDescription: failed ? "Home Assistant: authentication failed" : "Home Assistant")
            }
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            guard let self, let button = self.statusItem.button else { return }
            self.panel.toggle(relativeTo: button)
        }
        if !settings.isConfigured || CommandLine.arguments.contains("--show-settings") {
            settingsWindow.show()
        }
        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.statusItemClicked() }
        }
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showMenu()
        } else {
            panel.toggle(relativeTo: button)
        }
    }

    private func showMenu() {
        panel.close()
        let menu = NSMenu()
        if settings.authFailed {
            menu.addItem(withTitle: "Authentication failed — check token", action: nil, keyEquivalent: "")
            menu.addItem(.separator())
        }
        menu.addItem(withTitle: "Open in Browser", action: #selector(openInBrowser), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reload", action: #selector(reload), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Quit HA Tray", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        // Attach only while open so left clicks keep going to the action.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openInBrowser() {
        if let url = panel.currentURL ?? settings.baseURL.map({ HAURLs.dashboard(base: $0, path: settings.defaultDashboardPath) }) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func reload() {
        panel.reload()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }
}
