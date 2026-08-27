import ArgumentParser
import Foundation
import PortsKit

extension Portsd {
    struct Kill: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "kill",
            abstract: "Kill the process listening on a port."
        )

        @Argument(help: "The listening port number to free.")
        var port: Int

        @Flag(name: .shortAndLong, help: "Send SIGKILL immediately instead of SIGTERM.")
        var force = false

        @Flag(name: .shortAndLong, help: "Do not ask for confirmation.")
        var yes = false

        func run() async throws {
            let service = PortsService()
            let matches = try await service.snapshot().filter { $0.address.port == port }

            guard let target = matches.first else {
                throw ValidationError("Nothing is listening on port \(port).")
            }

            let pids = Set(matches.map(\.process.pid)).sorted()
            let pidList = pids.map(String.init).joined(separator: ", ")
            let description = "\(target.process.friendlyName) (pid \(pidList))"

            if !yes {
                printError("Kill \(description) on port \(port)? [y/N] ")
                guard let answer = readLine()?.lowercased(), answer == "y" || answer == "yes" else {
                    print("Aborted.")
                    return
                }
            }

            for pid in pids {
                let outcome =
                    force
                    ? service.killer.forceKill(pid: pid)
                    : await service.killer.terminateThenKill(pid: pid)
                report(outcome, pid: pid)
            }
        }

        private func report(_ outcome: KillOutcome, pid: Int32) {
            switch outcome {
            case .signalled:
                print("Killed pid \(pid).")
            case .processNotFound:
                print("pid \(pid) was already gone.")
            case .permissionDenied:
                printError(
                    "Permission denied for pid \(pid). Re-run with sudo, or use the app's "
                        + "\"Kill as Administrator\".\n")
            case .cancelledByUser:
                print("Cancelled.")
            case .failed(let code):
                printError("Failed to kill pid \(pid): errno \(code).\n")
            }
        }

        private func printError(_ message: String) {
            FileHandle.standardError.write(Data(message.utf8))
        }
    }
}
