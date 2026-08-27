import Foundation

/// The result of running an external command.
public struct CommandResult: Sendable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

/// Runs external commands. Injected so tests can feed recorded `lsof` output
/// without spawning a subprocess.
public protocol CommandRunner: Sendable {
    func run(_ executablePath: String, arguments: [String]) async throws -> CommandResult
}

/// Runs commands with `Foundation.Process`.
public struct SystemCommandRunner: CommandRunner {
    public init() {}

    public func run(_ executablePath: String, arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executablePath)
                process.arguments = arguments
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                // `lsof` output is kilobyte-scale; reading to end before waiting
                // is safe and avoids the readabilityHandler race.
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                continuation.resume(
                    returning: CommandResult(
                        exitCode: process.terminationStatus,
                        standardOutput: String(decoding: outData, as: UTF8.self),
                        standardError: String(decoding: errData, as: UTF8.self)
                    )
                )
            }
        }
    }
}
