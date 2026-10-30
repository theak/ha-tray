import AppKit
import HATrayCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore()
    private var statusItem: NSStatusItem!
    private var panel: PanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController(settings: settings)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "house", accessibilityDescription: "Home Assistant")
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        // Settings window arrives in the next task.
    }
}
