import AppKit
import CoreImage
import Foundation
import Observation
import PortsRemote

/// Runs the `PortsRemote` agent inside the menu-bar app and exposes what the
/// Settings UI needs: run state, the current pairing code, paired clients and
/// recent activity.
@MainActor
@Observable
final class RemoteAccessController {
    enum RunState: Equatable {
        case stopped
        case starting
        case running(host: String, port: Int)
        case failed(String)
    }

    private(set) var state: RunState = .stopped
    private(set) var fingerprint: String?
    private(set) var pairingURL: String?
    private(set) var pairingQR: NSImage?
    private(set) var pairedClients: [TokenRecord] = []
    private(set) var recentActivity: [AuditEntry] = []

    /// Bind to the whole LAN rather than loopback only.
    var allowLAN = false {
        didSet { Task { await restartIfRunning() } }
    }

    private var config: RemoteConfig {
        var config = RemoteConfig()
        config.bindHost = allowLAN ? "0.0.0.0" : "127.0.0.1"
        return config
    }

    private var agent: PortsAgent?
    private var runTask: Task<Void, Never>?
    private var advertiser: BonjourAdvertiser?

    // MARK: Lifecycle

    func start() async {
        guard case .stopped = state else { return }
        state = .starting
        let config = self.config
        let agent = PortsAgent(config: config)
        self.agent = agent

        do {
            let identity = try agent.resolveIdentity()
            fingerprint = identity.fingerprint

            let advertiser = BonjourAdvertiser(
                name: ProcessInfo.processInfo.hostName,
                port: config.port,
                fingerprint: identity.fingerprint,
                apiVersion: RemoteConfig.apiVersion
            )
            advertiser.start()
            self.advertiser = advertiser

            let application = try agent.buildApplication(identity: identity)
            runTask = Task {
                do { try await application.run() } catch {}
            }

            state = .running(host: agent.advertisedHost, port: config.port)
            await refreshPairingCode()
            await refreshClientsAndActivity()
        } catch {
            state = .failed(error.localizedDescription)
            await stop()
        }
    }

    func stop() async {
        runTask?.cancel()
        runTask = nil
        advertiser?.stop()
        advertiser = nil
        agent = nil
        pairingURL = nil
        pairingQR = nil
        if case .failed = state {} else { state = .stopped }
    }

    private func restartIfRunning() async {
        guard case .running = state else { return }
        await stop()
        await start()
    }

    // MARK: Pairing

    func refreshPairingCode() async {
        guard let agent, let fingerprint else { return }
        let payload = await agent.makePairingPayload(fingerprint: fingerprint)
        let url = payload.urlString()
        pairingURL = url
        pairingQR = Self.qrImage(from: url)
    }

    // MARK: Clients & activity

    func refreshClientsAndActivity() async {
        let store = FileTokenStore(fileURL: config.tokensFileURL)
        pairedClients = (try? await store.allRecords()) ?? []
        let log = FileAuditLog(fileURL: config.auditLogURL)
        recentActivity = await log.recentEntries(limit: 20).reversed()
    }

    func revoke(_ record: TokenRecord) async {
        let store = FileTokenStore(fileURL: config.tokensFileURL)
        try? await store.revoke(id: record.id)
        await refreshClientsAndActivity()
    }

    // MARK: QR rendering

    private static func qrImage(from string: String) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 220, height: 220))
    }
}
