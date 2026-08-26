import Foundation

/// Polls ``PortScanner`` on an interval and publishes each fresh snapshot on an
/// `AsyncStream`.
///
/// The menu-bar app pauses the monitor (``stop()``) whenever its window is
/// closed so an idle app costs nothing.
public actor PortsMonitor {
    private let scanner: PortScanner
    private var interval: Duration
    private var pollTask: Task<Void, Never>?

    /// The stream of snapshots. A new subscriber receives snapshots produced
    /// after it starts iterating.
    public nonisolated let snapshots: AsyncStream<[ListeningPort]>
    private let continuation: AsyncStream<[ListeningPort]>.Continuation

    public init(scanner: PortScanner = PortScanner(), interval: Duration = .seconds(2)) {
        self.scanner = scanner
        self.interval = interval
        (snapshots, continuation) = AsyncStream.makeStream(
            bufferingPolicy: .bufferingNewest(1))
    }

    deinit {
        continuation.finish()
        pollTask?.cancel()
    }

    /// Starts polling. Calling this while already running restarts the loop with
    /// the current interval.
    public func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if let snapshot = try? await self.scanner.scan() {
                    self.continuation.yield(snapshot)
                }
                try? await Task.sleep(for: await self.interval)
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func setInterval(_ newInterval: Duration) {
        interval = newInterval
    }

    /// Runs a scan immediately, publishes it on the stream, and returns it.
    @discardableResult
    public func refreshNow() async throws -> [ListeningPort] {
        let snapshot = try await scanner.scan()
        continuation.yield(snapshot)
        return snapshot
    }
}
