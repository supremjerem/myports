import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.refreshSeconds) private var refreshSeconds = 2.0
    @AppStorage(SettingsKey.loopbackOnly) private var loopbackOnly = false
    @AppStorage(SettingsKey.launchAtLogin) private var launchAtLogin = false

    @State private var loginItemRejected = false

    var body: some View {
        Form {
            Section("Scanning") {
                LabeledContent("Refresh every") {
                    HStack {
                        Slider(value: $refreshSeconds, in: 1...15, step: 1)
                            .frame(width: 160)
                        Text("\(Int(refreshSeconds)) s")
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                Toggle("Show loopback-bound ports only", isOn: $loopbackOnly)
            }

            Section("General") {
                Toggle("Launch MyPorts at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        let ok = LaunchAtLogin.setEnabled(newValue)
                        if !ok {
                            loginItemRejected = true
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if loginItemRejected {
                    Text(
                        "macOS blocked the change. Approve MyPorts in "
                            + "System Settings › General › Login Items."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("Version", value: AppInfo.versionString)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}
