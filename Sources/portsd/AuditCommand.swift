import ArgumentParser
import Foundation
import PortsRemote

extension Portsd {
    struct Audit: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "audit",
            abstract: "Show recent entries from the agent's audit log."
        )

        @Option(help: "Directory for tokens.json and audit.log.")
        var dataDir: String?

        @Option(name: .shortAndLong, help: "Number of entries to show.")
        var limit = 50

        func run() async throws {
            var config = RemoteConfig().applyingEnvironment()
            if let dataDir {
                config.dataDirectory = URL(fileURLWithPath: dataDir, isDirectory: true)
            }
            let log = FileAuditLog(fileURL: config.auditLogURL)
            let entries = await log.recentEntries(limit: limit)
            if entries.isEmpty {
                print("No audit entries at \(config.auditLogURL.path).")
                return
            }
            for entry in entries {
                var parts = ["\(entry.timestamp.ISO8601Format())", entry.action]
                if let label = entry.tokenLabel { parts.append("by \(label)") }
                if let port = entry.port { parts.append("port \(port)") }
                if let pid = entry.pid { parts.append("pid \(pid)") }
                if let signal = entry.signal { parts.append(signal) }
                if let outcome = entry.outcome { parts.append("-> \(outcome)") }
                print(parts.joined(separator: "  "))
            }
        }
    }
}
