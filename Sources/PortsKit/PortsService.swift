import Foundation

/// The entry point to PortsKit: one object that scans ports, builds monitors and
/// kills processes. Every collaborator is injectable for testing; the defaults
/// wire up the real `lsof`/`kill` implementations.
public struct PortsService: Sendable {
    public let scanner: PortScanner
    public let killer: PortKiller

    public init(scanner: PortScanner = PortScanner(), killer: PortKiller = PortKiller()) {
        self.scanner = scanner
        self.killer = killer
    }

    /// A one-shot snapshot of listening TCP ports.
    public func snapshot() async throws -> [ListeningPort] {
        try await scanner.scan()
    }

    /// A monitor that polls on `interval`. Call `start()` on the returned actor
    /// to begin, and iterate `snapshots`.
    public func makeMonitor(interval: Duration = .seconds(2)) -> PortsMonitor {
        PortsMonitor(scanner: scanner, interval: interval)
    }
}
