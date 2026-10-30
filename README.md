# HA Tray

A macOS menu bar app that shows your Home Assistant dashboard in a small popover.

- Logs in with a long-lived access token (stored in the Keychain) via HA's external-auth protocol — no login page.
- Hides the HA sidebar so dashboards fit a small panel.
- Picks the dashboard each time the panel opens, from rules like "if `input_boolean.bedtime` is on, show `lovelace/bedroom`".
- Global shortcut to toggle the panel; optional launch at login.

## Build & install

Requires Xcode (Swift 6 toolchain), macOS 14+.

```sh
make install   # builds, ad-hoc signs, copies to ~/Applications/HA Tray.app and launches
make run       # build and launch from build/
make test      # unit tests (a read-only live test runs when HA_URL/HA_TOKEN are set)
```

## Setup

On first launch the Settings window opens. Enter your HA URL (e.g. `http://homeassistant.local:8123`) and a long-lived access token (HA → Profile → Security → Long-lived access tokens), then **Test Connection**.

Right-click the menu bar icon for Open in Browser, Reload, Settings…, and Quit.

## Dashboard rules

Dashboard paths are what follows the host in the URL: `lovelace/0`, `lovelace/bedroom` (a view with a custom path), or `dashboard-cameras` (a separate dashboard).

When the panel opens, the app fetches the rule entities' states (1.5 s timeout). The first rule, top to bottom, whose entity state is exactly `on` wins; otherwise the default dashboard is used. If HA can't be reached, the panel shows whatever it showed last. The dashboard never changes while the panel is open.

## Notes

- Rebuilding changes the ad-hoc signature, so macOS may ask once to let the new build read the Keychain token — choose "Always Allow".
- Debug flags: `--show-panel`, `--show-settings`, `--debug-snapshot <dir>` (writes PNGs and a page report to `<dir>`).
