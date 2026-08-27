import Foundation
import PortsKit

@testable import PortsRemote

/// Canned `lsof -F` output: two dev servers (node on 3000, postgres on 5432)
/// plus one established connection against 3000.
enum AgentFixtures {
    static let listen = """
        p42001
        R900
        cnode
        Ltester
        f23
        tIPv4
        PTCP
        n127.0.0.1:3000
        TST=LISTEN
        p42500
        R1
        cpostgres
        Ltester
        f7
        tIPv4
        PTCP
        n127.0.0.1:5432
        TST=LISTEN
        """

    static let established = """
        p42001
        R900
        cnode
        Ltester
        f31
        tIPv4
        PTCP
        n127.0.0.1:3000->127.0.0.1:51544
        TST=ESTABLISHED
        """
}

struct StubCommandRunner: CommandRunner {
    var listen: String
    var established: String

    func run(_ executablePath: String, arguments: [String]) async throws -> CommandResult {
        let output = arguments.contains("-sTCP:ESTABLISHED") ? established : listen
        return CommandResult(exitCode: 0, standardOutput: output, standardError: "")
    }
}

struct StubInspector: ProcessInspecting {
    func inspect(pid: Int32) -> ProcessDetails { .empty }
}

/// Records every signal it is asked to send and answers from a fixed table.
final class RecordingSignaler: Signaler, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var sent: [(KillSignal, Int32)] = []
    var outcome: KillOutcome = .signalled

    func send(_ signal: KillSignal, to pid: Int32) -> KillOutcome {
        lock.withLock { sent.append((signal, pid)) }
        return outcome
    }

    func probe(pid: Int32) -> KillOutcome { .processNotFound }
}

extension PortsService {
    /// A service whose scanner replays `AgentFixtures` and whose killer records
    /// calls instead of signalling anything.
    static func stubbed(signaler: RecordingSignaler = RecordingSignaler()) -> PortsService {
        PortsService(
            scanner: PortScanner(
                runner: StubCommandRunner(
                    listen: AgentFixtures.listen, established: AgentFixtures.established),
                inspector: StubInspector(),
                nameResolver: FriendlyNameResolver()
            ),
            killer: PortKiller(signaler: signaler)
        )
    }
}

/// A temp data directory that cleans itself up.
struct TempDataDir: ~Copyable {
    let url: URL

    init() {
        url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("myports-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func config(readOnly: Bool = false, killRateLimitPerMinute: Int = 10) -> RemoteConfig {
        RemoteConfig(
            bindHost: "127.0.0.1",
            port: 0,
            readOnly: readOnly,
            dataDirectory: url,
            eventInterval: .milliseconds(200),
            killRateLimitPerMinute: killRateLimitPerMinute
        )
    }
}
