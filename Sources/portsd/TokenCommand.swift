import ArgumentParser
import Foundation
import PortsRemote

extension Portsd {
    struct Token: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "token",
            abstract: "Manage bearer tokens for the agent.",
            subcommands: [Add.self, List.self, Revoke.self]
        )

        struct Options: ParsableArguments {
            @Option(help: "Directory for tokens.json and audit.log.")
            var dataDir: String?

            func store() -> FileTokenStore {
                var config = RemoteConfig().applyingEnvironment()
                if let dataDir {
                    config.dataDirectory = URL(fileURLWithPath: dataDir, isDirectory: true)
                }
                return FileTokenStore(fileURL: config.tokensFileURL)
            }
        }

        struct Add: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "add", abstract: "Create a token and print the secret once.")

            @OptionGroup var options: Options
            @Option(name: .shortAndLong, help: "A label to recognise this client.")
            var label = "unnamed"

            func run() async throws {
                let (secret, record) = try await options.store().create(label: label)
                print("id:     \(record.id)")
                print("label:  \(record.label)")
                print("secret: \(secret)")
                FileHandle.standardError.write(
                    Data("\nStore the secret now — it is not saved in plaintext.\n".utf8))
            }
        }

        struct List: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "list", abstract: "List token ids and labels.")

            @OptionGroup var options: Options

            func run() async throws {
                let records = try await options.store().allRecords()
                if records.isEmpty {
                    print("No tokens. Create one with: portsd token add --label \"my phone\"")
                    return
                }
                for record in records {
                    let used = record.lastUsedAt.map { " last used \($0.ISO8601Format())" } ?? ""
                    print(
                        "\(record.id)  \(record.label)  created \(record.createdAt.ISO8601Format())\(used)"
                    )
                }
            }
        }

        struct Revoke: AsyncParsableCommand {
            static let configuration = CommandConfiguration(
                commandName: "revoke", abstract: "Delete a token by id.")

            @OptionGroup var options: Options
            @Argument(help: "The token id from `token list`.")
            var id: String

            func run() async throws {
                try await options.store().revoke(id: id)
                print("Revoked \(id).")
            }
        }
    }
}
