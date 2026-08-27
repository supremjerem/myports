import Foundation

/// The transport-layer protocol a socket uses.
public enum TransportProtocol: String, Sendable, Codable, Hashable {
    case tcp
    case udp

    init?(lsofToken token: String) {
        switch token.uppercased() {
        case "TCP": self = .tcp
        case "UDP": self = .udp
        default: return nil
        }
    }
}

/// A host/port pair parsed from an `lsof` socket name such as `127.0.0.1:3000`,
/// `*:8080` or `[::1]:5432`.
public struct SocketAddress: Sendable, Hashable, Codable {
    /// The textual host: an IPv4/IPv6 literal, or `*` for "all interfaces".
    public let host: String
    /// The port number. `0` represents a wildcard (`*`) port.
    public let port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    /// `true` when the address is bound to a loopback interface only.
    public var isLoopback: Bool {
        host == "127.0.0.1" || host == "::1" || host.hasPrefix("127.") || host == "[::1]"
    }

    /// `true` when the socket listens on every interface (`*`, `0.0.0.0`, `::`).
    public var isWildcardHost: Bool {
        host == "*" || host == "0.0.0.0" || host == "::" || host == "[::]"
    }

    /// Parses an endpoint token as emitted by `lsof -F n`.
    ///
    /// Handles IPv4 (`127.0.0.1:3000`), wildcard (`*:3000`, `*:*`) and
    /// bracketed IPv6 (`[::1]:5432`, `[fe80::1]:0`) forms.
    public static func parse(_ token: String) -> SocketAddress? {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let host: Substring
        let portToken: Substring

        if trimmed.hasPrefix("[") {
            guard let closing = trimmed.firstIndex(of: "]") else { return nil }
            host = trimmed[trimmed.index(after: trimmed.startIndex)..<closing]
            let afterBracket = trimmed.index(after: closing)
            guard afterBracket < trimmed.endIndex, trimmed[afterBracket] == ":" else { return nil }
            portToken = trimmed[trimmed.index(after: afterBracket)...]
        } else {
            guard let separator = trimmed.lastIndex(of: ":") else { return nil }
            host = trimmed[trimmed.startIndex..<separator]
            portToken = trimmed[trimmed.index(after: separator)...]
        }

        guard !host.isEmpty else { return nil }
        let port: Int
        if portToken == "*" {
            port = 0
        } else if let parsed = Int(portToken) {
            port = parsed
        } else {
            return nil
        }
        return SocketAddress(host: String(host), port: port)
    }
}

/// A remote peer connected to a local listening socket, or a locally-originated
/// connection, as reported by `lsof`.
public struct Connection: Sendable, Hashable, Codable {
    public let localAddress: SocketAddress
    public let remoteAddress: SocketAddress?
    public let state: ConnectionState
    public let transport: TransportProtocol

    public init(
        localAddress: SocketAddress,
        remoteAddress: SocketAddress?,
        state: ConnectionState,
        transport: TransportProtocol
    ) {
        self.localAddress = localAddress
        self.remoteAddress = remoteAddress
        self.state = state
        self.transport = transport
    }
}

/// The TCP state reported by `lsof` in the `TST=` field.
public enum ConnectionState: String, Sendable, Codable, Hashable {
    case listen = "LISTEN"
    case established = "ESTABLISHED"
    case synSent = "SYN_SENT"
    case synReceived = "SYN_RCVD"
    case finWait1 = "FIN_WAIT_1"
    case finWait2 = "FIN_WAIT_2"
    case timeWait = "TIME_WAIT"
    case closeWait = "CLOSE_WAIT"
    case lastAck = "LAST_ACK"
    case closing = "CLOSING"
    case closed = "CLOSED"
    case idle = "IDLE"
    case other = "OTHER"

    init(lsofToken token: String) {
        self = ConnectionState(rawValue: token.uppercased()) ?? .other
    }
}
