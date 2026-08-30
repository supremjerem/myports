import PortsRemote
import SwiftUI

/// The "Remote Access" tab of Settings: toggle the agent, show a pairing QR,
/// manage paired clients and review recent activity.
struct RemoteAccessView: View {
    @Bindable var controller: RemoteAccessController

    private var isRunning: Bool {
        if case .running = controller.state { return true }
        return false
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enable remote access", isOn: enabledBinding)
                Toggle(
                    "Reachable on the local network (not just this Mac)", isOn: $controller.allowLAN
                )
                .disabled(!isRunning)
                statusRow
            } footer: {
                Text(
                    "Runs an HTTPS agent so the MyPorts iOS app or a browser can view and "
                        + "kill ports on this Mac. Killing over the network is powerful — only "
                        + "pair devices you trust, and revoke them when done."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if isRunning {
                pairingSection
                clientsSection
                activitySection
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .task {
            if isRunning { await controller.refreshClientsAndActivity() }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { isRunning || controller.state == .starting },
            set: { on in
                Task { on ? await controller.start() : await controller.stop() }
            }
        )
    }

    @ViewBuilder
    private var statusRow: some View {
        switch controller.state {
        case .stopped:
            Label("Stopped", systemImage: "circle").foregroundStyle(.secondary)
        case .starting:
            Label("Starting…", systemImage: "circle.dotted")
        case .running(let host, let port):
            Label("https://\(host):\(port)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }

    private var pairingSection: some View {
        Section("Pair a device") {
            HStack(alignment: .top, spacing: 16) {
                Group {
                    if let qr = controller.pairingQR {
                        Image(nsImage: qr)
                            .resizable()
                            .interpolation(.none)
                            .frame(width: 160, height: 160)
                    } else {
                        RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                            .frame(width: 160, height: 160)
                            .overlay(ProgressView())
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(
                        "Scan this in the MyPorts iOS app. The code is single-use and expires in about 10 minutes."
                    )
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    if let fingerprint = controller.fingerprint {
                        Text("Certificate: \(fingerprint.prefix(16))…")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Button("New pairing code") {
                        Task { await controller.refreshPairingCode() }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var clientsSection: some View {
        Section("Paired devices") {
            if controller.pairedClients.isEmpty {
                Text("No devices paired yet.").foregroundStyle(.secondary)
            } else {
                ForEach(controller.pairedClients) { client in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(client.label)
                            Text(
                                "added \(client.createdAt.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Revoke", role: .destructive) {
                            Task { await controller.revoke(client) }
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            Button("Refresh") { Task { await controller.refreshClientsAndActivity() } }
                .buttonStyle(.link)
        }
    }

    private var activitySection: some View {
        Section("Recent activity") {
            if controller.recentActivity.isEmpty {
                Text("Nothing yet.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(controller.recentActivity.enumerated()), id: \.offset) { _, entry in
                    HStack(spacing: 8) {
                        Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(summary(for: entry)).font(.caption)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func summary(for entry: AuditEntry) -> String {
        var parts = [entry.action]
        if let label = entry.tokenLabel { parts.append("· \(label)") }
        if let port = entry.port { parts.append("· port \(port)") }
        if let outcome = entry.outcome { parts.append("→ \(outcome)") }
        return parts.joined(separator: " ")
    }
}
