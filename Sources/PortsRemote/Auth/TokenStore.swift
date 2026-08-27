import CryptoKit
import Foundation

/// A paired client's credential. Only the SHA-256 of the secret is persisted;
/// the secret itself is shown once, at creation.
public struct TokenRecord: Codable, Sendable, Identifiable {
    public var id: String
    public var label: String
    public var sha256Hex: String
    public var createdAt: Date
    public var lastUsedAt: Date?
}

public enum TokenStoreError: Error, Equatable {
    case notFound(id: String)
}

/// Persists and verifies bearer tokens.
public protocol TokenStoring: Sendable {
    func allRecords() async throws -> [TokenRecord]
    /// Creates a token, returning the plaintext secret (shown once) and its record.
    func create(label: String) async throws -> (secret: String, record: TokenRecord)
    func revoke(id: String) async throws
    /// Returns the matching record if `secret` is valid, updating `lastUsedAt`.
    func verify(secret: String) async -> TokenRecord?
}

/// JSON-file backed token store (`tokens.json` in the data directory), guarded
/// by an actor so concurrent requests serialise around the file.
public actor FileTokenStore: TokenStoring {
    private let fileURL: URL
    private var cache: [TokenRecord]?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func allRecords() throws -> [TokenRecord] {
        try load()
    }

    public func create(label: String) throws -> (secret: String, record: TokenRecord) {
        var records = try load()
        let secret = Self.makeSecret()
        let record = TokenRecord(
            id: UUID().uuidString,
            label: label.isEmpty ? "unnamed" : label,
            sha256Hex: Self.hash(secret),
            createdAt: Date(),
            lastUsedAt: nil
        )
        records.append(record)
        try save(records)
        return (secret, record)
    }

    public func revoke(id: String) throws {
        var records = try load()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw TokenStoreError.notFound(id: id)
        }
        records.remove(at: index)
        try save(records)
    }

    public func verify(secret: String) -> TokenRecord? {
        guard let records = try? load() else { return nil }
        let hash = Self.hash(secret)
        guard
            let index = records.firstIndex(where: {
                Self.constantTimeEquals($0.sha256Hex, hash)
            })
        else { return nil }
        var updated = records
        updated[index].lastUsedAt = Date()
        try? save(updated)
        return updated[index]
    }

    // MARK: File I/O

    private func load() throws -> [TokenRecord] {
        if let cache { return cache }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cache = []
            return []
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try decoder.decode([TokenRecord].self, from: data)
        cache = records
        return records
    }

    private func save(_ records: [TokenRecord]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(records).write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        cache = records
    }

    // MARK: Crypto helpers

    static func makeSecret() -> String {
        let random = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        return random.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func hash(_ secret: String) -> String {
        let digest = SHA256.hash(data: Data(secret.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        guard a.count == b.count else { return false }
        var difference: UInt8 = 0
        for index in a.indices { difference |= a[index] ^ b[index] }
        return difference == 0
    }
}
