import HATrayCore
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @State private var connectionStatus: String?
    @State private var entities: [String] = []
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    private static let ruleDomains: Set<String> = ["switch", "input_boolean", "light", "binary_sensor", "fan"]

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Home Assistant URL", text: $settings.baseURLString, prompt: Text("http://homeassistant.local:8123"))
                SecureField("Long-lived access token", text: $settings.token)
                HStack {
                    Button("Test Connection") { testConnection() }
                        .disabled(!settings.isConfigured)
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
        .task(id: settings.isConfigured) { await loadEntities() }
    }

    private func client() -> HAClient? {
        settings.baseURL.map { HAClient(baseURL: $0, token: settings.effectiveToken) }
    }

    private func testConnection() {
        guard let client = client() else { return }
        connectionStatus = "Testing…"
        Task {
            let error = await client.testConnection()
            connectionStatus = error.map { "✗ \($0.localizedDescription)" } ?? "✓ Connected"
            if error == nil { await loadEntities() }
        }
    }

    private func loadEntities() async {
        guard settings.isConfigured, let client = client() else { return }
        entities = (try? await client.allEntities(domains: Self.ruleDomains)) ?? entities
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
