import ArgumentParser
import Foundation
import PortsRemote

extension Portsd {
    struct Serve: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "serve",
            abstract: "Run the HTTP+JSON agent (loopback only for now)."
        )

        @Option(help: "Interface to bind. Non-loopback needs TLS + pairing (not yet available).")
        var bind: String?

        @Option(name: .shortAndLong, help: "TCP port to listen on.")
        var port: Int?

        @Flag(help: "Serve reads only; reject every kill with HTTP 403.")
        var readonly = false

        @Option(help: "Directory for tokens.json and audit.log.")
        var dataDir: String?

        func run() async throws {
            var config = RemoteConfig().applyingEnvironment()
            if let bind { config.bindHost = bind }
            if let port { config.port = port }
            if readonly { config.readOnly = true }
            if let dataDir {
                config.dataDirectory = URL(fileURLWithPath: dataDir, isDirectory: true)
            }

            let agent = PortsAgent(config: config)

            FileHandle.standardError.write(
                Data(
                    """
                    MyPorts agent on http://\(config.bindHost):\(config.port)\
                    \(config.readOnly ? " (read-only)" : "")
                    Data dir: \(config.dataDirectory.path)
                    Create a token with:  portsd token add --label "my phone"

                    """.utf8))

            try await agent.run()
        }
    }
}
