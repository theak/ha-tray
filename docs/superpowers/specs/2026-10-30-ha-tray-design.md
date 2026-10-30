# HA Tray — Design

## Intent

A macOS menu bar app that shows the user's Home Assistant dashboard in a small popover. Click the tray icon (or press a global shortcut), see the right dashboard for the moment, click away to dismiss. It should feel like a native quick-glance panel, not a browser window.

Why: the full HA web UI is too heavy for a quick check, the official Companion app opens a full window, and the one known desktop tray app (iprodanovbg/homeassistant-desktop, Electron) is archived.

## Goals (V1)

1. **Permanent login.** Set the HA URL and a long-lived access token once at setup; never see a login screen afterward.
2. **Minimal chrome.** The HA sidebar is hidden so the dashboard renders well in a small panel.
3. **Conditional dashboard.** Each time the panel opens, pick the dashboard from an ordered list of rules based on HA entity states; fall back to a default.
4. **Polish.** Global keyboard shortcut to toggle the panel; launch at login.

## Non-goals (V1)

- Hiding the HA top header/toolbar (sidebar only for now).
- Local Mac state as a condition (power source, Wi-Fi, displays). Possible V2.
- Switching dashboards live while the panel is open.
- Local vs. remote URL switching — always one URL.
- Distribution (notarization, auto-update, App Store). Personal build only.
- Reporting Mac sensors to HA.

## Anti-goals

- A login page ever appearing in normal use.
- The dashboard changing underneath the user while they're looking at it.
- Background polling / work when the panel is closed (beyond the idle loaded web view, see below).
- A Dock icon or app-switcher presence.

## Behavior

### First run / setup
If no URL or token is stored, the settings window opens automatically. Fields: HA URL (e.g. `http://homeassistant.local:8123`), long-lived access token. A "Test connection" button calls `GET {url}/api/` with the token and shows success/failure. Token is stored in the macOS Keychain; everything else in `UserDefaults`.

### Opening the panel
Triggered by left-click on the status item or the global shortcut (toggle: pressing again closes it).

1. Fetch states of the entities referenced by rules via REST (`GET /api/states/<entity_id>` with bearer token).
2. Walk rules top to bottom; the first rule whose entity state is `on` wins. Its dashboard path is the target. An entity that can't be fetched (404, error) simply doesn't match — evaluation continues with the next rule. If no rule matches, target = default dashboard path.
3. If the web view isn't already showing the target path, navigate to it. Then show the popover.

Rule evaluation happens only on open. Showing the popover should not wait noticeably on the fetch — keep a short timeout (~1.5 s). *(Design call)* On a total fetch failure or timeout, don't navigate: show whatever the web view already has (or the default dashboard if nothing is loaded yet). A result that arrives after the popover is shown is ignored — the dashboard never changes while visible.

### Closing
Popover is `transient`: clicking outside closes it. Escape also closes it.

### Web view lifetime
The `WKWebView` is kept alive between opens for instant display (HA's frontend holds its own websocket and reconnects itself after sleep). Nothing else runs in the background. The user accepted this tradeoff.

### Right-click menu on the status item
Open in Browser (current dashboard URL), Reload, Settings…, Quit.

### Settings window
- HA URL, token (secure field), Test connection.
- Default dashboard path (e.g. `lovelace/0`).
- Rules list: each row = entity ID + dashboard path. Add, remove, drag to reorder. Entity ID can be typed; a picker populated from `GET /api/states` filtered to `switch.`, `input_boolean.`, `light.`, `binary_sensor.`, `fan.` is nice-to-have.
- Panel size (width × height), default 420 × 700.
- Global shortcut recorder.
- Launch at login toggle.

## Technical decisions (made)

- **Native Swift / SwiftUI**, AppKit where needed. `LSUIElement = YES` (no Dock icon). `NSStatusItem` + `NSPopover` hosting a `WKWebView`.
- **Auth via HA's external auth protocol.** Load dashboard URLs with `?external_auth=1`. The frontend calls `window.webkit.messageHandlers.getExternalAuth.postMessage({callback, force})`; the app responds by evaluating `window[callback](true, {access_token: <LLAT>, expires_in: <large>})`. Also handle `revokeExternalAuth` (respond success, no-op). The long-lived token never needs refreshing. Do **not** register an `externalBus` handler unless needed — when present, the frontend switches into companion-app mode and expects more messages.
- **Sidebar hiding** via a `WKUserScript` at document start that sets HA's sidebar preference in `localStorage` (key `dockedSidebar`, value `"always_hidden"` — builder must verify the exact key/serialization against the current HA frontend). Fallback if that doesn't take: injected CSS/JS on the `home-assistant` → `home-assistant-main` shadow DOM.
- **Persistent web storage**: `WKWebsiteDataStore.default()`.
- **Launch at login**: `SMAppService.mainApp`.
- **Global shortcut**: `sindresorhus/KeyboardShortcuts` via Swift Package Manager.
- **Rule semantics V1**: condition is "entity state == `on`". Only one entity per rule.
- **Project location**: `ha-tray`, Xcode project (Xcode 27.1, Swift 6.4 available). Builder's call: create the project via `xcodegen` or a hand-written `.xcodeproj`/SwiftPM app bundle — whatever builds cleanly from the command line with `xcodebuild`.

## Testing

- The user's real HA instance is available: `$HA_URL` (`http://homeassistant.local:8123`) and `$HA_TOKEN` (long-lived token) are in the shell env. Read-only use only — tests must not toggle entities.
- Unit-test the pure parts: rule evaluation (ordered, first-match, missing entity = no match, total failure = no navigation), URL building (`external_auth=1`, path joining), settings persistence.
- Manual verification: app launches with no Dock icon, popover shows the dashboard logged in without a login page, sidebar hidden, rule switching on reopen, click-outside closes, shortcut toggles, launch-at-login toggle registers.

## Left to the builder

- App icon / status bar glyph (an SF Symbol such as `house` is fine).
- Exact settings layout.
- Error presentation (e.g. a small inline message in the popover if HA is unreachable).
- Code structure and file layout.
