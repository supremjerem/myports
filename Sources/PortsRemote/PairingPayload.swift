import Foundation

/// The contents of the pairing QR code. Encoded as compact JSON, then base64url,
/// then wrapped in a `myports://pair?d=…` URL so a camera app can hand it to the
/// iOS client.
public struct PairingPayload: Codable, Sendable, Equatable {
    public var version: Int
    public var host: String
    public var port: Int
    /// Lowercase hex SHA-256 of the DER server certificate, for pinning.
    public var fingerprint: String
    /// Single-use pairing token, exchanged at `POST /api/v1/pair`.
    public var pairingToken: String

    enum CodingKeys: String, CodingKey {
        case version = "v"
        case host = "h"
        case port = "p"
        case fingerprint = "fp"
        case pairingToken = "pt"
    }

    public init(
        host: String, port: Int, fingerprint: String, pairingToken: String, version: Int = 1
    ) {
        self.version = version
        self.host = host
        self.port = port
        self.fingerprint = fingerprint
        self.pairingToken = pairingToken
    }

    public func urlString() -> String {
        let json = (try? JSONEncoder().encode(self)) ?? Data()
        let encoded = json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "myports://pair?d=\(encoded)"
    }

    public static func parse(_ urlString: String) -> PairingPayload? {
        guard let components = URLComponents(string: urlString),
            components.scheme == "myports",
            let item = components.queryItems?.first(where: { $0.name == "d" }),
            let encoded = item.value
        else { return nil }

        var base64 =
            encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let data = Data(base64Encoded: base64),
            let payload = try? JSONDecoder().decode(PairingPayload.self, from: data)
        else { return nil }
        return payload
    }
}
