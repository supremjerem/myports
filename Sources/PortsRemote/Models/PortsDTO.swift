import Foundation
import PortsKit

/// Wire types for the JSON API. Kept separate from PortsKit's domain models so
/// the on-the-wire contract can evolve independently; `apiVersion` guards
/// compatibility with older clients.

public struct PortsResponse: Codable, Sendable {
    public var apiVersion: Int
    public var ports: [PortDTO]

    public init(ports: [ListeningPort], apiVersion: Int = RemoteConfig.apiVersion) {
        self.apiVersion = apiVersion
        self.ports = ports.map(PortDTO.init)
    }
}

public struct PortDTO: Codable, Sendable {
    public var port: Int
    public var host: String
    public var transport: String
    public var pid: Int32
    public var command: String
    public var friendlyName: String
    public var category: String
    public var executablePath: String?
    public var user: String
    public var isLoopback: Bool
    public var connectionCount: Int
    public var connections: [ConnectionDTO]

    init(_ model: ListeningPort) {
        port = model.address.port
        host = model.address.host
        transport = model.transport.rawValue
        pid = model.process.pid
        command = model.process.command
        friendlyName = model.process.friendlyName
        category = model.process.category.rawValue
        executablePath = model.process.executablePath
        user = model.process.user
        isLoopback = model.address.isLoopback
        connectionCount = model.establishedConnections.count
        connections = model.establishedConnections.map(ConnectionDTO.init)
    }
}

public struct ConnectionDTO: Codable, Sendable {
    public var localHost: String
    public var localPort: Int
    public var remoteHost: String?
    public var remotePort: Int?
    public var state: String

    init(_ model: Connection) {
        localHost = model.localAddress.host
        localPort = model.localAddress.port
        remoteHost = model.remoteAddress?.host
        remotePort = model.remoteAddress?.port
        state = model.state.rawValue
    }
}

public struct ConnectionsResponse: Codable, Sendable {
    public var apiVersion: Int
    public var connections: [ConnectionDTO]
}

public struct DeviceResponse: Codable, Sendable {
    public var apiVersion: Int
    public var hostname: String
    public var operatingSystem: String
    public var readOnly: Bool
}

public struct KillRequest: Codable, Sendable {
    public enum Signal: String, Codable, Sendable {
        case term = "TERM"
        case kill = "KILL"
    }
    public var signal: Signal
}

public struct KillResponse: Codable, Sendable {
    public var apiVersion: Int
    public var outcome: String
    public var pid: Int32
}

public struct APIError: Codable, Sendable, Error {
    public var error: String
    public init(_ error: String) { self.error = error }
}
