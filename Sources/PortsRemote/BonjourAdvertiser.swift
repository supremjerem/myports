import Foundation

/// Advertises the agent as `_myports._tcp` on the local network so the iOS app
/// can discover paired machines without typing an address.
///
/// Uses `NetService`, which is deprecated on macOS but still the least-friction
/// way to publish a Bonjour service alongside a NIO server.
public final class BonjourAdvertiser: NSObject, @unchecked Sendable {
    private var service: NetService?
    private let name: String
    private let port: Int
    private let txt: [String: String]

    public init(name: String, port: Int, fingerprint: String, apiVersion: Int) {
        self.name = name
        self.port = port
        self.txt = [
            "v": String(apiVersion),
            "fp": fingerprint,
            "host": ProcessInfo.processInfo.hostName,
        ]
    }

    public func start() {
        let service = NetService(
            domain: "local.", type: "_myports._tcp.", name: name, port: Int32(port))
        service.setTXTRecord(NetService.data(fromTXTRecord: txt.mapValues { Data($0.utf8) }))
        service.publish()
        self.service = service
    }

    public func stop() {
        service?.stop()
        service = nil
    }
}
