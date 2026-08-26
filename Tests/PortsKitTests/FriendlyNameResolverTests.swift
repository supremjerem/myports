import Testing

@testable import PortsKit

@Suite("FriendlyNameResolver")
struct FriendlyNameResolverTests {
    let resolver = FriendlyNameResolver()

    struct Case: Sendable {
        var command: String
        var arguments: [String]
        var expectedName: String
        var expectedCategory: ProcessCategory
    }

    @Test(
        "recognises common dev services",
        arguments: [
            Case(
                command: "node", arguments: ["node", "/x/node_modules/.bin/vite"],
                expectedName: "Vite dev server", expectedCategory: .nodeRuntime),
            Case(
                command: "node", arguments: ["node", "server.js", "next", "dev"],
                expectedName: "Next.js", expectedCategory: .nodeRuntime),
            Case(
                command: "node", arguments: ["node", "index.js"],
                expectedName: "Node.js", expectedCategory: .nodeRuntime),
            Case(
                command: "Python", arguments: ["python3", "-m", "http.server", "8000"],
                expectedName: "Python http.server", expectedCategory: .webServer),
            Case(
                command: "python3", arguments: ["python3", "manage.py", "runserver"],
                expectedName: "Django dev server", expectedCategory: .python),
            Case(
                command: "postgres", arguments: [],
                expectedName: "PostgreSQL", expectedCategory: .database),
            Case(
                command: "redis-server", arguments: [],
                expectedName: "Redis", expectedCategory: .database),
            Case(
                command: "com.docker.backend", arguments: [],
                expectedName: "Docker", expectedCategory: .containerRuntime),
            Case(
                command: "ruby", arguments: ["puma", "-C", "config/puma.rb"],
                expectedName: "Rails", expectedCategory: .ruby),
            Case(
                command: "java", arguments: ["-jar", "spring-app.jar"],
                expectedName: "Spring Boot", expectedCategory: .java),
            Case(
                command: "nginx", arguments: [],
                expectedName: "nginx", expectedCategory: .webServer),
        ]
    )
    func recognisesServices(_ testCase: Case) {
        let resolved = resolver.resolve(
            command: testCase.command, executablePath: nil, arguments: testCase.arguments)
        #expect(resolved.name == testCase.expectedName)
        #expect(resolved.category == testCase.expectedCategory)
    }

    @Test("falls back to the raw command when nothing matches")
    func fallback() {
        let resolved = resolver.resolve(
            command: "some-proprietary-daemon", executablePath: nil, arguments: [])
        #expect(resolved.name == "some-proprietary-daemon")
        #expect(resolved.category == .unknown)
    }
}
