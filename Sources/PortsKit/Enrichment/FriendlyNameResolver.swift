import Foundation

/// Turns a raw command name plus arguments into a recognisable label and a
/// category for iconography.
public protocol FriendlyNameResolving: Sendable {
    func resolve(command: String, executablePath: String?, arguments: [String]) -> ResolvedName
}

public struct ResolvedName: Sendable, Equatable {
    public let name: String
    public let category: ProcessCategory
}

/// A small, deliberately conservative heuristic table. When nothing matches it
/// returns the original command unchanged so the UI never shows a worse label
/// than `lsof` already provides.
public struct FriendlyNameResolver: FriendlyNameResolving {
    public init() {}

    public func resolve(
        command: String, executablePath: String?, arguments: [String]
    ) -> ResolvedName {
        let lowerCommand = command.lowercased()
        let argsBlob = arguments.joined(separator: " ").lowercased()

        // Databases and caches — match on the command name alone.
        if let database = Self.databases[lowerCommand] {
            return ResolvedName(name: database, category: .database)
        }

        // Container runtimes.
        if lowerCommand.hasPrefix("com.docker") || lowerCommand == "dockerd"
            || lowerCommand == "containerd" || lowerCommand == "colima"
        {
            return ResolvedName(name: "Docker", category: .containerRuntime)
        }

        // Node.js — disambiguate by the tool it is running.
        if lowerCommand == "node" || lowerCommand.hasPrefix("node") {
            return ResolvedName(name: Self.nodeLabel(for: argsBlob), category: .nodeRuntime)
        }

        // Python — spot the common dev servers.
        if lowerCommand.hasPrefix("python") || lowerCommand == "python" {
            if argsBlob.contains("http.server") {
                return ResolvedName(name: "Python http.server", category: .webServer)
            }
            if argsBlob.contains("flask") { return ResolvedName(name: "Flask", category: .python) }
            if argsBlob.contains("uvicorn") || argsBlob.contains("gunicorn") {
                return ResolvedName(name: "Python ASGI/WSGI server", category: .python)
            }
            if argsBlob.contains("manage.py") || argsBlob.contains("django") {
                return ResolvedName(name: "Django dev server", category: .python)
            }
            return ResolvedName(name: "Python", category: .python)
        }

        // Ruby / Rails.
        if lowerCommand == "ruby" || lowerCommand == "puma" || lowerCommand == "rails" {
            if argsBlob.contains("rails") || argsBlob.contains("puma") || lowerCommand == "puma"
                || lowerCommand == "rails"
            {
                return ResolvedName(name: "Rails", category: .ruby)
            }
            return ResolvedName(name: "Ruby", category: .ruby)
        }

        // Java / JVM.
        if lowerCommand == "java" {
            if argsBlob.contains("spring") {
                return ResolvedName(name: "Spring Boot", category: .java)
            }
            return ResolvedName(name: "Java", category: .java)
        }

        // Standalone web servers.
        if let server = Self.webServers[lowerCommand] {
            return ResolvedName(name: server, category: .webServer)
        }

        // .NET / Go.
        if lowerCommand == "dotnet" { return ResolvedName(name: ".NET", category: .dotnet) }
        if lowerCommand.hasPrefix("__debug_bin") || lowerCommand == "air" {
            return ResolvedName(name: "Go server", category: .golang)
        }

        return ResolvedName(name: command, category: .unknown)
    }

    private static func nodeLabel(for argsBlob: String) -> String {
        let known: [(needle: String, label: String)] = [
            ("vite", "Vite dev server"),
            ("next", "Next.js"),
            ("nuxt", "Nuxt"),
            ("webpack", "webpack-dev-server"),
            ("react-scripts", "Create React App"),
            ("remix", "Remix"),
            ("astro", "Astro"),
            ("nest", "NestJS"),
            ("nodemon", "nodemon"),
            ("storybook", "Storybook"),
        ]
        for entry in known where argsBlob.contains(entry.needle) {
            return entry.label
        }
        return "Node.js"
    }

    private static let databases: [String: String] = [
        "postgres": "PostgreSQL",
        "postmaster": "PostgreSQL",
        "mysqld": "MySQL",
        "mariadbd": "MariaDB",
        "redis-server": "Redis",
        "mongod": "MongoDB",
        "memcached": "Memcached",
        "influxd": "InfluxDB",
        "cockroach": "CockroachDB",
    ]

    private static let webServers: [String: String] = [
        "nginx": "nginx",
        "httpd": "Apache httpd",
        "caddy": "Caddy",
        "traefik": "Traefik",
    ]
}
