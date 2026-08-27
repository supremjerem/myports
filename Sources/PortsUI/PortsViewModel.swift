import Foundation
import Observation
import PortsKit

/// Drives the port list UI: owns the live snapshot, the search/sort/filter
/// controls, and the per-row kill escalation.
@MainActor
@Observable
public final class PortsViewModel {
    public private(set) var ports: [ListeningPort] = []
    public private(set) var lastErrorMessage: String?
    public private(set) var isRefreshing = false
    public private(set) var hasLoadedOnce = false

    public var searchText = ""
    public var sortOrder: PortSortOrder = .port
    public var showLoopbackOnly = false

    /// Kill phase per port id, so a row can render its own progress.
    public private(set) var killPhases: [String: KillPhase] = [:]

    private let service: PortsService
    private var monitor: PortsMonitor?
    private var streamTask: Task<Void, Never>?
    private var pollInterval: Duration
    private let isPreview: Bool

    public init(service: PortsService = PortsService(), pollInterval: Duration = .seconds(2)) {
        self.service = service
        self.pollInterval = pollInterval
        self.isPreview = false
    }

    /// A view model backed by static data, for previews, the demo window and
    /// screenshots. Monitoring and killing are inert.
    public init(previewPorts: [ListeningPort]) {
        self.service = PortsService()
        self.pollInterval = .seconds(2)
        self.isPreview = true
        self.ports = previewPorts
        self.hasLoadedOnce = true
    }

    // MARK: Derived list

    public var visiblePorts: [ListeningPort] {
        var result = ports
        if showLoopbackOnly {
            result = result.filter { $0.address.isLoopback }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter { port in
                port.matches(query)
            }
        }
        return sortOrder.sort(result)
    }

    public var totalConnectionCount: Int {
        ports.reduce(0) { $0 + $1.establishedConnections.count }
    }

    // MARK: Monitoring lifecycle

    public func start() {
        guard !isPreview, streamTask == nil else { return }
        let monitor = service.makeMonitor(interval: pollInterval)
        self.monitor = monitor
        streamTask = Task { [weak self, monitor] in
            await monitor.start()
            for await snapshot in monitor.snapshots {
                if Task.isCancelled { break }
                self?.apply(snapshot)
            }
        }
        Task { await refreshNow() }
    }

    public func stop() {
        streamTask?.cancel()
        streamTask = nil
        let monitor = self.monitor
        self.monitor = nil
        Task { await monitor?.shutdown() }
    }

    public func setPollInterval(_ interval: Duration) {
        pollInterval = interval
        Task { [monitor] in await monitor?.setInterval(interval) }
    }

    public func refreshNow() async {
        guard !isPreview else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let snapshot = try await service.snapshot()
            apply(snapshot)
        } catch {
            lastErrorMessage = Self.describe(error)
        }
    }

    private func apply(_ snapshot: [ListeningPort]) {
        ports = snapshot
        lastErrorMessage = nil
        hasLoadedOnce = true
        // Drop kill phases for ports that are gone, and clear "succeeded" rows.
        let liveIDs = Set(snapshot.map(\.id))
        killPhases = killPhases.filter { key, phase in
            liveIDs.contains(key) && !phase.isTerminal
        }
    }

    // MARK: Kill escalation

    public func phase(for port: ListeningPort) -> KillPhase {
        killPhases[port.id] ?? .idle
    }

    public func beginConfirmation(for port: ListeningPort) {
        killPhases[port.id] = .confirming
    }

    public func cancelConfirmation(for port: ListeningPort) {
        killPhases[port.id] = .idle
    }

    /// SIGTERM, then SIGKILL if the process lingers.
    public func confirmKill(_ port: ListeningPort) async {
        killPhases[port.id] = .working
        let outcome = await service.killer.terminateThenKill(pid: port.process.pid)
        killPhases[port.id] = outcome.toPhase()
        if outcome == .signalled || outcome == .processNotFound {
            await refreshNow()
        }
    }

    /// Retry a permission-denied kill with an administrator prompt.
    public func killAsAdministrator(_ port: ListeningPort) async {
        killPhases[port.id] = .working
        let outcome = await service.killer.forceKillAsAdministrator(pid: port.process.pid)
        killPhases[port.id] = outcome.toPhase()
        if outcome == .signalled || outcome == .processNotFound {
            await refreshNow()
        }
    }

    public func dismissKillResult(for port: ListeningPort) {
        killPhases[port.id] = nil
    }

    // MARK: Helpers

    private static func describe(_ error: Error) -> String {
        if let scanError = error as? PortScanError {
            switch scanError {
            case .commandFailed(let code, let message):
                return message.isEmpty ? "lsof failed (exit \(code))." : message
            }
        }
        return error.localizedDescription
    }
}

extension ListeningPort {
    func matches(_ query: String) -> Bool {
        if String(address.port).contains(query) { return true }
        if String(process.pid).contains(query) { return true }
        if process.friendlyName.localizedCaseInsensitiveContains(query) { return true }
        if process.command.localizedCaseInsensitiveContains(query) { return true }
        if address.host.localizedCaseInsensitiveContains(query) { return true }
        if let path = process.executablePath, path.localizedCaseInsensitiveContains(query) {
            return true
        }
        return false
    }
}
