import Foundation

public struct LocalSourcesConfiguration: Codable, Equatable, Sendable {
    public let sources: [AgentSource]

    public init(sources: [AgentSource] = AgentSource.allCases) {
        self.sources = sources
    }

    public static func loadDefault(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> LocalSourcesConfiguration {
        let url = configuredFileURL(fileManager: fileManager, environment: environment)

        guard fileManager.fileExists(atPath: url.path) else {
            return LocalSourcesConfiguration()
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LocalSourcesConfiguration.self, from: data)
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/iCost", isDirectory: true)
            .appendingPathComponent("local-sources.json")
    }

    public func saveDefault(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        try save(
            to: Self.configuredFileURL(fileManager: fileManager, environment: environment),
            fileManager: fileManager
        )
    }

    public func save(to url: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    public func removing(_ source: AgentSource) -> LocalSourcesConfiguration {
        LocalSourcesConfiguration(sources: sources.filter { $0 != source })
    }

    public static func configuredFileURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let configuredPath = environment["I_COST_LOCAL_SOURCES"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return configuredPath.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: expandTilde($0)) }
            ?? defaultFileURL(fileManager: fileManager)
    }

    private static func expandTilde(_ path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        return FileManager.default.homeDirectoryForCurrentUser.path + String(path.dropFirst())
    }
}
