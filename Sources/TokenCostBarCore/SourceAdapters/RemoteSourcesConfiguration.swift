import Foundation

public struct RemoteSourcesConfiguration: Codable, Equatable, Sendable {
    public let hosts: [RemoteHostConfiguration]

    public init(hosts: [RemoteHostConfiguration] = []) {
        self.hosts = hosts
    }

    public static func loadDefault(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> RemoteSourcesConfiguration {
        let url = configuredFileURL(fileManager: fileManager, environment: environment)

        guard fileManager.fileExists(atPath: url.path) else {
            return RemoteSourcesConfiguration()
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RemoteSourcesConfiguration.self, from: data)
    }

    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/iCost", isDirectory: true)
            .appendingPathComponent("remote-sources.json")
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
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    public static func configuredFileURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        let configuredPath = environment["I_COST_REMOTE_SOURCES"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return configuredPath.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: expandTilde($0)) }
            ?? defaultFileURL(fileManager: fileManager)
    }

    private static func expandTilde(_ path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        return FileManager.default.homeDirectoryForCurrentUser.path + String(path.dropFirst())
    }
}

public struct RemoteHostConfiguration: Codable, Equatable, Sendable {
    public let id: String?
    public let host: String
    public let user: String?
    public let port: Int?
    public let identityFile: String?
    public let sources: [AgentSource]?
    public let paths: [String: String]?
    public let connectTimeoutSeconds: Int?

    public init(
        id: String? = nil,
        host: String,
        user: String? = nil,
        port: Int? = nil,
        identityFile: String? = nil,
        sources: [AgentSource]? = nil,
        paths: [String: String]? = nil,
        connectTimeoutSeconds: Int? = nil
    ) {
        self.id = id
        self.host = host
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.sources = sources
        self.paths = paths
        self.connectTimeoutSeconds = connectTimeoutSeconds
    }

    public var enabledSources: [AgentSource] {
        guard let sources, !sources.isEmpty else {
            return [.claudeCode, .codex]
        }
        return sources
    }

    public var target: String {
        if let user, !user.isEmpty {
            return "\(user)@\(host)"
        }
        return host
    }

    public var displayName: String {
        if let id, !id.isEmpty {
            return id
        }
        return target
    }

    public var stableID: String {
        let raw: String
        if let id, !id.isEmpty {
            raw = id
        } else {
            raw = "\(target):\(port ?? 22)"
        }
        return StableID.hash(raw)
    }

    public func remotePath(for source: AgentSource) -> String {
        if let configuredPath = paths?[source.rawValue], !configuredPath.isEmpty {
            return configuredPath
        }
        return "~/" + source.defaultRelativePath
    }
}
