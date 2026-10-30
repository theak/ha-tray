import HATrayCore
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var connectionStatus: String?
    @State private var tokenDraft = ""
    @State private var isTesting = false
    /// A pasted token HA already rejected; not re-sent, since each rejection counts toward HA's IP ban.
    @State private var rejectedDraft: String?
    @State private var entities: [String] = []
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    private static let ruleDomains: Set<String> = ["switch", "input_boolean", "light", "binary_sensor", "fan"]

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Home Assistant URL", text: $settings.baseURLString, prompt: Text("http://homeassistant.local:8123"))
                SecureField("Long-lived access token", text: $tokenDraft,
                            prompt: Text(settings.token.isEmpty ? "Paste token" : "Saved — paste to replace"))
                if let tokenError = settings.tokenError {
                    Text(tokenError).foregroundStyle(.red)
                }
                if settings.authFailed {
                    Text("Home Assistant rejected the saved token, so HA Tray has stopped contacting it. Save a new token or retry.")
                        .foregroundStyle(.red)
                }
                HStack {
                    Button("Save & Test Token") { saveToken() }
                        .disabled(isTesting || settings.baseURL == nil
                                  || tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || tokenDraft == rejectedDraft)
                    Button(settings.authFailed ? "Retry" : "Test Connection") { testSavedToken() }
                        .disabled(isTesting || !settings.isConfigured)
                    if let connectionStatus { Text(connectionStatus).foregroundStyle(.secondary) }
                }
            }

            Section {
                TextField("Default dashboard", text: $settings.defaultDashboardPath, prompt: Text("lovelace/0"))
                ForEach(Array($settings.rules.enumerated()), id: \.element.id) { index, $rule in
                    RuleRow(
                        rule: $rule,
                        entities: entities,
                        onMoveUp: index > 0 ? { settings.rules.swapAt(index, index - 1) } : nil,
                        onDelete: { settings.rules.remove(at: index) }
                    )
                }
                Button("Add Rule") {
                    settings.rules.append(DashboardRule(entityID: "", dashboardPath: ""))
                }
            } header: {
                Text("Dashboards")
            } footer: {
                Text("When the panel opens, the first rule (top to bottom) whose entity is on picks the dashboard; otherwise the default is used.")
                    .foregroundStyle(.secondary)
            }

            Section("Panel") {
                Stepper("Width: \(Int(settings.panelWidth))", value: $settings.panelWidth, in: 300...1200, step: 20)
                Stepper("Height: \(Int(settings.panelHeight))", value: $settings.panelHeight, in: 300...1400, step: 20)
            }

            Section("General") {
                KeyboardShortcuts.Recorder("Toggle panel:", name: .togglePanel)
                Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                if let launchAtLoginError { Text(launchAtLoginError).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: 680)
        .task(id: settings.canConnect) { await loadEntities() }
    }

    private func client(token: String? = nil) -> HAClient? {
        settings.baseURL.map { HAClient(baseURL: $0, token: token ?? settings.effectiveToken) }
    }

    /// Validates the pasted token with one request; saves it only if HA accepts it.
    private func saveToken() {
        let candidate = tokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client = client(token: candidate) else { return }
        isTesting = true
        connectionStatus = "Testing…"
        Task {
            defer { isTesting = false }
            if let error = await client.testConnection() {
                if error == .unauthorized { rejectedDraft = tokenDraft }
                connectionStatus = "✗ \(error.localizedDescription) — not saved"
                return
            }
            do {
                try settings.applyToken(candidate)
                tokenDraft = ""
                connectionStatus = "✓ Saved"
            } catch {
                connectionStatus = "✗ \(error.localizedDescription)"
            }
        }
    }

    /// One request with the saved token; clears or sets the auth-failure stop.
    private func testSavedToken() {
        guard let client = client() else { return }
        isTesting = true
        connectionStatus = "Testing…"
        Task {
            defer { isTesting = false }
            let error = await client.testConnection()
            if error == .unauthorized { settings.authFailed = true }
            if error == nil { settings.authFailed = false }
            connectionStatus = error.map { "✗ \($0.localizedDescription)" } ?? "✓ Connected"
        }
    }

    private func loadEntities() async {
        guard settings.canConnect, let client = client() else { return }
        do {
            entities = try await client.allEntities(domains: Self.ruleDomains)
        } catch HAError.unauthorized {
            settings.authFailed = true
        } catch {}
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled { try service.register() } else { try service.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        if service.status == .requiresApproval {
            launchAtLoginError = "Approve HA Tray in System Settings → Login Items."
            SMAppService.openSystemSettingsLoginItems()
        }
        launchAtLogin = service.status == .enabled
    }
}

private struct RuleRow: View {
    @Binding var rule: DashboardRule
    let entities: [String]
    let onMoveUp: (() -> Void)?
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button { onMoveUp?() } label: { Image(systemName: "arrow.up") }
                .buttonStyle(.borderless)
                .disabled(onMoveUp == nil)
                .help("Move up")
            TextField("Entity", text: $rule.entityID, prompt: Text("input_boolean.bedtime"))
                .labelsHidden()
            Menu {
                ForEach(entities, id: \.self) { id in
                    Button(id) { rule.entityID = id }
                }
            } label: {
                Image(systemName: "chevron.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(entities.isEmpty)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            TextField("Dashboard", text: $rule.dashboardPath, prompt: Text("lovelace/bedroom"))
                .labelsHidden()
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}
