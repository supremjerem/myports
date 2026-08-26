import Foundation

/// One socket file descriptor as reported by `lsof -F`.
struct RawSocket: Equatable {
    var pid: Int32
    var command: String
    var login: String
    var parentPID: Int32?
    var fileDescriptor: String
    var family: String
    var transport: TransportProtocol
    var localAddress: SocketAddress
    var remoteAddress: SocketAddress?
    var state: ConnectionState
}

/// Parses the field-mode output of `lsof -F pcnLPRTt`.
///
/// The stream is a sequence of single-character-tagged lines. Process-level
/// fields (`p`, `c`, `L`, `R`) appear once per process and stay in scope until
/// the next `p`. File-level fields (`f`, `t`, `P`, `n`, `T`) repeat per open
/// file and are flushed whenever the next `f`/`p` line, or end of input, is
/// reached.
enum LsofParser {
    static func parse(_ output: String) -> [RawSocket] {
        var sockets: [RawSocket] = []

        var pid: Int32?
        var command = ""
        var login = ""
        var parentPID: Int32?

        var fd: String?
        var family = ""
        var transport: TransportProtocol?
        var name: String?
        var state: ConnectionState = .other

        func flushFile() {
            defer {
                fd = nil
                family = ""
                transport = nil
                name = nil
                state = .other
            }
            guard let pid, let rawName = name, let transport else { return }
            let endpoints = rawName.components(separatedBy: "->")
            guard let local = SocketAddress.parse(endpoints[0]) else { return }
            let remote = endpoints.count > 1 ? SocketAddress.parse(endpoints[1]) : nil
            sockets.append(
                RawSocket(
                    pid: pid,
                    command: command,
                    login: login,
                    parentPID: parentPID,
                    fileDescriptor: fd ?? "",
                    family: family,
                    transport: transport,
                    localAddress: local,
                    remoteAddress: remote,
                    state: state
                )
            )
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())

            switch tag {
            case "p":
                flushFile()
                pid = Int32(value)
                command = ""
                login = ""
                parentPID = nil
            case "c":
                command = value
            case "L":
                login = value
            case "R":
                parentPID = Int32(value)
            case "f":
                flushFile()
                fd = value
            case "t":
                family = value
            case "P":
                transport = TransportProtocol(lsofToken: value)
            case "n":
                name = value
            case "T":
                if let equals = value.firstIndex(of: "="), value[..<equals] == "ST" {
                    state = ConnectionState(lsofToken: String(value[value.index(after: equals)...]))
                }
            default:
                continue
            }
        }
        flushFile()
        return sockets
    }
}
