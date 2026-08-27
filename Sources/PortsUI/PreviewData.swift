import Foundation
import PortsKit

/// Deterministic sample data for SwiftUI previews, the demo window, and manual
/// screenshots. Not used on any real code path.
public enum PortsPreviewData {
    public static let ports: [ListeningPort] = [
        make(
            port: 3000, host: "127.0.0.1", pid: 48120, command: "node",
            name: "Vite dev server", category: .nodeRuntime,
            path: "/opt/homebrew/bin/node",
            args: ["node", "/repo/node_modules/.bin/vite", "--host"],
            connections: 2),
        make(
            port: 5173, host: "::1", pid: 48120, command: "node",
            name: "Vite dev server", category: .nodeRuntime,
            path: "/opt/homebrew/bin/node", args: [], connections: 0),
        make(
            port: 5432, host: "127.0.0.1", pid: 1180, command: "postgres",
            name: "PostgreSQL", category: .database,
            path: "/opt/homebrew/opt/postgresql@16/bin/postgres", args: [], connections: 4),
        make(
            port: 6379, host: "127.0.0.1", pid: 1204, command: "redis-server",
            name: "Redis", category: .database,
            path: "/opt/homebrew/opt/redis/bin/redis-server", args: [], connections: 1),
        make(
            port: 8080, host: "*", pid: 990, command: "com.docker.backend",
            name: "Docker", category: .containerRuntime,
            path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend",
            args: [], connections: 0),
        make(
            port: 8000, host: "*", pid: 52310, command: "Python",
            name: "Python http.server", category: .webServer,
            path: "/usr/bin/python3", args: ["python3", "-m", "http.server", "8000"],
            connections: 0),
    ]

    private static func make(
        port: Int, host: String, pid: Int32, command: String, name: String,
        category: ProcessCategory, path: String, args: [String], connections: Int
    ) -> ListeningPort {
        let address = SocketAddress(host: host, port: port)
        return ListeningPort(
            address: address,
            transport: .tcp,
            process: PortProcess(
                pid: pid, parentPID: 1, command: command, executablePath: path,
                arguments: args, user: "jrz",
                startDate: Date(timeIntervalSinceNow: -3600), friendlyName: name,
                category: category),
            establishedConnections: (0..<connections).map { index in
                Connection(
                    localAddress: address,
                    remoteAddress: SocketAddress(host: "127.0.0.1", port: 51000 + index),
                    state: .established, transport: .tcp)
            }
        )
    }
}
