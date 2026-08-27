import ArgumentParser
import Foundation
import PortsRemote

extension Portsd {
    struct Serve: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "serve",
            abstract: "Run the HTTPS+JSON agent (self-signed TLS, Bonjour)."
        )

        @Option(help: "Interface to bind. Default 127.0.0.1.")
        var bind: String?

        @Flag(help: "Bind 0.0.0.0 so the agent is reachable on the LAN.")
        var lan = false

        @Option(name: .shortAndLong, help: "TCP port to listen on.")
        var port: Int?

        @Flag(help: "Serve reads only; reject every kill with HTTP 403.")
        var readonly = false

        @Flag(help: "Print a pairing URL at startup.")
        var pair = false

        @Option(help: "Directory for tokens.json, audit.log and the TLS identity.")
        var dataDir: String?

        func run() async throws {
            var config = RemoteConfig().applyingEnvironment()
            if lan { config.bindHost = "0.0.0.0" }
            if let bind { config.bindHost = bind }
            if let port { config.port = port }
            if readonly { config.readOnly = true }
            if let dataDir {
                config.dataDirectory = URL(fileURLWithPath: dataDir, isDirectory: true)
            }

            let agent = PortsAgent(config: config)
            let identity = try agent.resolveIdentity()

            var banner = """
                MyPorts agent on https://\(config.bindHost):\(config.port)\
                \(config.readOnly ? " (read-only)" : "")
                Cert fingerprint (SHA-256): \(identity.fingerprint)
                Data dir: \(config.dataDirectory.path)

                """
            if pair {
                let payload = await agent.makePairingPayload(fingerprint: identity.fingerprint)
                banner += "\nPairing URL (valid ~10 min):\n\(payload.urlString())\n"
            } else {
                banner += "\nShow a pairing QR from the macOS app, or run with --pair.\n"
            }
            FileHandle.standardError.write(Data(banner.utf8))

            try await agent.run()
        }
    }
}
