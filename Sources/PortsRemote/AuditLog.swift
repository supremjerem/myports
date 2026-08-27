import Foundation

/// One line in the audit log.
public struct AuditEntry: Codable, Sendable {
    public var timestamp: Date
    public var action: String
    public var tokenLabel: String?
    public var port: Int?
    public var pid: Int32?
    public var signal: String?
    public var outcome: String?
    public var detail: String?
}

/// Append-only audit trail. Every kill attempt (and token change) is recorded so
/// the user can see what a remote client did.
public protocol AuditLogging: Sendable {
    func record(_ entry: AuditEntry) async
    func recentEntries(limit: Int) async -> [AuditEntry]
}

/// Newline-delimited JSON at `audit.log` in the data directory.
public actor FileAuditLog: AuditLogging {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func record(_ entry: AuditEntry) {
        guard var line = try? encoder.encode(entry) else { return }
        line.append(0x0A)
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } else {
                try line.write(to: fileURL, options: .atomic)
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            }
        } catch {
            // The audit log is best-effort; never fail a request because it
            // could not be written.
        }
    }

    public func recentEntries(limit: Int) -> [AuditEntry] {
        guard let data = try? Data(contentsOf: fileURL),
            let text = String(data: data, encoding: .utf8)
        else { return [] }
        let lines = text.split(separator: "\n").suffix(limit)
        return lines.compactMap { line in
            try? decoder.decode(AuditEntry.self, from: Data(line.utf8))
        }
    }
}
