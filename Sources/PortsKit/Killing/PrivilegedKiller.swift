import Foundation

/// Escalates a kill via `osascript`'s "with administrator privileges", which
/// triggers the standard macOS authentication panel.
///
/// Only invoke this after an unprivileged attempt returned
/// ``KillOutcome/permissionDenied`` and the user explicitly asked to retry as
/// an administrator.
public struct PrivilegedKiller: Sendable {
    private let runner: CommandRunner
    private let osascriptPath: String

    public init(
        runner: CommandRunner = SystemCommandRunner(),
        osascriptPath: String = "/usr/bin/osascript"
    ) {
        self.runner = runner
        self.osascriptPath = osascriptPath
    }

    public func forceKill(pid: Int32) async -> KillOutcome {
        guard pid > 0 else { return .failed(errno: EINVAL) }
        let script = "do shell script \"/bin/kill -9 \(pid)\" with administrator privileges"
        let result: CommandResult
        do {
            result = try await runner.run(osascriptPath, arguments: ["-e", script])
        } catch {
            return .failed(errno: EIO)
        }

        if result.exitCode == 0 { return .signalled }

        let stderr = result.standardError.lowercased()
        if stderr.contains("user canceled") || stderr.contains("user cancelled")
            || stderr.contains("(-128)")
        {
            return .cancelledByUser
        }
        if stderr.contains("no such process") { return .processNotFound }
        return .failed(errno: EPERM)
    }
}
