import Crypto
import Foundation
import NIOSSL
import SwiftASN1
import X509

/// A self-signed server identity: a certificate, its private key, and the
/// SHA-256 fingerprint of the DER certificate that clients pin during pairing.
public struct SelfSignedIdentity: Sendable {
    public let certificatePEM: String
    public let privateKeyPEM: String
    /// Lowercase hex SHA-256 of the DER-encoded certificate.
    public let fingerprint: String

    public var nioCertificate: NIOSSLCertificate {
        get throws { try NIOSSLCertificate(bytes: Array(certificatePEM.utf8), format: .pem) }
    }

    public var nioPrivateKey: NIOSSLPrivateKey {
        get throws { try NIOSSLPrivateKey(bytes: Array(privateKeyPEM.utf8), format: .pem) }
    }
}

/// Loads the identity from disk, generating and persisting one on first use.
public enum IdentityStore {
    public static func loadOrCreate(
        certificateURL: URL,
        keyURL: URL,
        hostname: String,
        ipAddresses: [String] = []
    ) throws -> SelfSignedIdentity {
        if let certPEM = try? String(contentsOf: certificateURL, encoding: .utf8),
            let keyPEM = try? String(contentsOf: keyURL, encoding: .utf8),
            let identity = try? makeIdentity(certificatePEM: certPEM, privateKeyPEM: keyPEM)
        {
            return identity
        }

        let (certPEM, keyPEM) = try generate(hostname: hostname, ipAddresses: ipAddresses)
        try FileManager.default.createDirectory(
            at: certificateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try certPEM.write(to: certificateURL, atomically: true, encoding: .utf8)
        try keyPEM.write(to: keyURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o644], ofItemAtPath: certificateURL.path)

        return try makeIdentity(certificatePEM: certPEM, privateKeyPEM: keyPEM)
    }

    static func makeIdentity(certificatePEM: String, privateKeyPEM: String) throws
        -> SelfSignedIdentity
    {
        let nioCert = try NIOSSLCertificate(bytes: Array(certificatePEM.utf8), format: .pem)
        let der = try nioCert.toDERBytes()
        let digest = SHA256.hash(data: Data(der))
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined()
        return SelfSignedIdentity(
            certificatePEM: certificatePEM,
            privateKeyPEM: privateKeyPEM,
            fingerprint: fingerprint
        )
    }

    static func generate(hostname: String, ipAddresses: [String]) throws -> (
        certificatePEM: String, privateKeyPEM: String
    ) {
        let swiftKey = P256.Signing.PrivateKey()
        let key = Certificate.PrivateKey(swiftKey)

        let name = try DistinguishedName {
            CommonName(hostname)
            OrganizationName("MyPorts")
        }

        var sans: [GeneralName] = [
            .dnsName("localhost"),
            .dnsName(hostname),
        ]
        for address in ipAddresses {
            if let octets = ipv4Octets(address) {
                sans.append(.ipAddress(ASN1OctetString(contentBytes: ArraySlice(octets))))
            }
        }

        let now = Date()
        let extensions = try Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
            KeyUsage(digitalSignature: true, keyEncipherment: true)
            try ExtendedKeyUsage([.serverAuth])
            SubjectAlternativeNames(sans)
        }

        let certificate = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: key.publicKey,
            notValidBefore: now.addingTimeInterval(-3600),
            notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365 * 10),
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: key
        )

        var certSerializer = DER.Serializer()
        try certSerializer.serialize(certificate)
        let certPEM = PEMDocument(
            type: "CERTIFICATE", derBytes: certSerializer.serializedBytes
        ).pemString

        return (certPEM, swiftKey.pemRepresentation)
    }

    private static func ipv4Octets(_ string: String) -> [UInt8]? {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var octets: [UInt8] = []
        for part in parts {
            guard let value = UInt8(part) else { return nil }
            octets.append(value)
        }
        return octets
    }
}
