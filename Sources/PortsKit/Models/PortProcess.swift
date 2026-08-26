import Foundation

/// A coarse classification of the process behind a port, used by the UI to pick
/// an icon and by humans to recognise a service at a glance.
public enum ProcessCategory: String, Sendable, Codable, Hashable, CaseIterable {
    case nodeRuntime
    case python
    case ruby
    case java
    case dotnet
    case golang
    case database
    case webServer
    case containerRuntime
    case shell
    case systemService
    case unknown
}

/// The process that owns a listening socket.
///
/// `PortProcess` deliberately avoids the name `ProcessInfo` so it does not
/// collide with `Foundation.ProcessInfo`.
public struct PortProcess: Sendable, Hashable, Codable, Identifiable {
    public var id: Int32 { pid }

    /// The process identifier.
    public let pid: Int32
    /// The parent process identifier, when known.
    public let parentPID: Int32?
    /// The short command name from `lsof` (`c` field, truncated by the kernel to
    /// roughly 15 characters).
    public let command: String
    /// The absolute executable path resolved via `proc_pidpath`, when available.
    public let executablePath: String?
    /// The process arguments, best-effort via `KERN_PROCARGS2`.
    public let arguments: [String]
    /// The owning user's login name (`lsof` `L` field).
    public let user: String
    /// The process start time, when it could be resolved.
    public let startDate: Date?
    /// A human-friendly label such as "Vite dev server" or "PostgreSQL".
    /// Falls back to `command` when no heuristic matches.
    public let friendlyName: String
    /// The resolved category for iconography.
    public let category: ProcessCategory

    public init(
        pid: Int32,
        parentPID: Int32?,
        command: String,
        executablePath: String?,
        arguments: [String],
        user: String,
        startDate: Date?,
        friendlyName: String,
        category: ProcessCategory
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.command = command
        self.executablePath = executablePath
        self.arguments = arguments
        self.user = user
        self.startDate = startDate
        self.friendlyName = friendlyName
        self.category = category
    }
}

/// A socket in the `LISTEN` state together with the process that owns it and the
/// connections currently established against it.
public struct ListeningPort: Sendable, Hashable, Codable, Identifiable {
    public var id: String {
        "\(transport.rawValue)-\(address.host)-\(address.port)-\(process.pid)"
    }

    public let address: SocketAddress
    public let transport: TransportProtocol
    public let process: PortProcess
    public var establishedConnections: [Connection]

    public init(
        address: SocketAddress,
        transport: TransportProtocol,
        process: PortProcess,
        establishedConnections: [Connection] = []
    ) {
        self.address = address
        self.transport = transport
        self.process = process
        self.establishedConnections = establishedConnections
    }

    /// Convenience accessor for the listening port number.
    public var port: Int { address.port }
}
