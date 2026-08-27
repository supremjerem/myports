import Foundation

@testable import PortsKit

/// Loads a file from `Tests/PortsKitTests/Fixtures`.
enum Fixture {
    struct NotFound: Error, CustomStringConvertible {
        let name: String
        var description: String { "missing fixture \(name)" }
    }

    static func load(_ name: String) throws -> String {
        guard
            let url = Bundle.module.url(
                forResource: name, withExtension: nil, subdirectory: "Fixtures")
        else {
            throw NotFound(name: name)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

/// A `CommandRunner` that returns canned output keyed by the `-sTCP:` filter in
/// the arguments, so one stub covers both the LISTEN and ESTABLISHED calls.
struct StubCommandRunner: CommandRunner {
    var listenOutput: String
    var establishedOutput: String
    var exitCode: Int32 = 0

    func run(_ executablePath: String, arguments: [String]) async throws -> CommandResult {
        let output =
            arguments.contains("-sTCP:ESTABLISHED") ? establishedOutput : listenOutput
        return CommandResult(exitCode: exitCode, standardOutput: output, standardError: "")
    }
}

struct StubProcessInspector: ProcessInspecting {
    var detailsByPID: [Int32: ProcessDetails] = [:]

    func inspect(pid: Int32) -> ProcessDetails {
        detailsByPID[pid] ?? .empty
    }
}

/// Records every signal delivery and answers from a scripted table.
final class SpySignaler: Signaler, @unchecked Sendable {
    struct Call: Equatable {
        var signal: KillSignal?
        var pid: Int32
    }

    private let lock = NSLock()
    private var _calls: [Call] = []
    var calls: [Call] {
        lock.withLock { _calls }
    }

    /// Outcome to return for `send`, by pid. Missing pids get `.signalled`.
    var sendOutcomes: [Int32: KillOutcome] = [:]
    /// Outcome to return for `probe`, by pid. Missing pids get `.processNotFound`.
    var probeOutcomes: [Int32: KillOutcome] = [:]

    func send(_ signal: KillSignal, to pid: Int32) -> KillOutcome {
        lock.withLock { _calls.append(Call(signal: signal, pid: pid)) }
        return sendOutcomes[pid] ?? .signalled
    }

    func probe(pid: Int32) -> KillOutcome {
        lock.withLock { _calls.append(Call(signal: nil, pid: pid)) }
        return probeOutcomes[pid] ?? .processNotFound
    }
}
