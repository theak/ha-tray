import AppKit
import HATrayCore
import SwiftUI

final class SettingsWindowController {
    private let settings: SettingsStore
    private var window: NSWindow?

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            window.title = "HA Tray Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        if let view = window?.contentView { DebugSnapshot.schedule(view, name: "settings.png", after: 4) }
    }
}
