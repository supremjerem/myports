import Foundation
import Hummingbird

/// `GET /api/v1/device` — unauthenticated, so a client can discover the API
/// version and read-only status before pairing.
struct DeviceController {
    let config: RemoteConfig

    @Sendable
    func device(_ request: Request, context: AgentRequestContext) async throws -> Response {
        JSONBody.json(
            DeviceResponse(
                apiVersion: RemoteConfig.apiVersion,
                hostname: ProcessInfo.processInfo.hostName,
                operatingSystem: Self.operatingSystemString,
                readOnly: config.readOnly
            ))
    }

    private static var operatingSystemString: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
