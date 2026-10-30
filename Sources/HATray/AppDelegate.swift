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
        }
        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.statusItemClicked() }
        }
    }

    @objc private func statusItemClicked() {
        guard let button = statusItem.button else { return }
        panel.toggle(relativeTo: button)
    }
}
