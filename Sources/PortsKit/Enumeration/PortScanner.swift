import Foundation

/// Errors surfaced while scanning ports.
public enum PortScanError: Error, Sendable, Equatable {
    /// `lsof` exited with an unexpected status and produced no usable output.
    case commandFailed(exitCode: Int32, message: String)
}

/// Enumerates listening TCP ports and the processes behind them.
///
/// The scan runs `lsof` twice — once for `LISTEN` sockets, once for
/// `ESTABLISHED` — parses both, enriches each owning process via
/// ``ProcessInspecting`` and ``FriendlyNameResolving``, and attaches the
/// established connections whose local endpoint matches a listening port owned
/// by the same process.
public struct PortScanner: Sendable {
    private let runner: CommandRunner
    private let inspector: ProcessInspecting
    private let nameResolver: FriendlyNameResolving
    private let lsofPath: String

    public init(
        runner: CommandRunner = SystemCommandRunner(),
        inspector: ProcessInspecting = ProcessInspector(),
        nameResolver: FriendlyNameResolving = FriendlyNameResolver(),
        lsofPath: String = "/usr/sbin/lsof"
    ) {
        self.runner = runner
        self.inspector = inspector
        self.nameResolver = nameResolver
        self.lsofPath = lsofPath
    }

    private static let fieldFlags = "-FpcnLPRTt"

    public func scan() async throws -> [ListeningPort] {
        async let listenOutput = runLsof(stateFilter: "LISTEN")
        async let establishedOutput = runLsof(stateFilter: "ESTABLISHED")

        // `lsof` reports a separate file descriptor for the IPv4 and IPv6 halves
        // of a dual-stack listener (both named e.g. `*:5000`). They collapse to
        // one logical port here, keyed by owning pid + bound host + port.
        var seenListeners: Set<String> = []
        let listenSockets = LsofParser.parse(try await listenOutput)
            .filter { $0.state == .listen && $0.transport == .tcp }
            .filter { socket in
                let key = "\(socket.pid)-\(socket.localAddress.host)-\(socket.localAddress.port)"
                return seenListeners.insert(key).inserted
            }
        let establishedSockets = LsofParser.parse(try await establishedOutput)
            .filter { $0.state == .established }

        var connectionsByPID: [Int32: [Connection]] = [:]
        for socket in establishedSockets {
            connectionsByPID[socket.pid, default: []].append(
                Connection(
                    localAddress: socket.localAddress,
                    remoteAddress: socket.remoteAddress,
                    state: socket.state,
                    transport: socket.transport
                )
            )
        }

        var detailsByPID: [Int32: ProcessDetails] = [:]
        var ports: [ListeningPort] = []
        for socket in listenSockets {
            let details =
                detailsByPID[socket.pid]
                ?? {
                    let resolved = inspector.inspect(pid: socket.pid)
                    detailsByPID[socket.pid] = resolved
                    return resolved
                }()

            let resolvedName = nameResolver.resolve(
                command: socket.command,
                executablePath: details.executablePath,
                arguments: details.arguments
            )

            let process = PortProcess(
                pid: socket.pid,
                parentPID: details.parentPID ?? socket.parentPID,
                command: socket.command,
                executablePath: details.executablePath,
                arguments: details.arguments,
                user: socket.login,
                startDate: details.startDate,
                friendlyName: resolvedName.name,
                category: resolvedName.category
            )

            let matchingConnections = (connectionsByPID[socket.pid] ?? []).filter {
                $0.localAddress.port == socket.localAddress.port
            }

            ports.append(
                ListeningPort(
                    address: socket.localAddress,
                    transport: socket.transport,
                    process: process,
                    establishedConnections: matchingConnections
                )
            )
        }

        return ports.sorted {
            ($0.address.port, $0.process.pid, $0.address.host)
                < ($1.address.port, $1.process.pid, $1.address.host)
        }
    }

    private func runLsof(stateFilter: String) async throws -> String {
        let result = try await runner.run(
            lsofPath,
            arguments: ["-nP", "-iTCP", "-sTCP:\(stateFilter)", Self.fieldFlags]
        )
        // `lsof` exits 1 when the filter matches nothing; that is not an error.
        guard result.exitCode == 0 || result.exitCode == 1 else {
            throw PortScanError.commandFailed(
                exitCode: result.exitCode,
                message: result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return result.standardOutput
    }
}
