import Foundation

public enum SourceAdapterFactory {
    public static func defaultAdapters() -> [UsageSourceAdapter] {
        localAdapters() + remoteAdapters()
    }

    public static func localAdapters(
        configuration: LocalSourcesConfiguration? = nil,
        fileManager: FileManager = .default
    ) -> [UsageSourceAdapter] {
        let loadedConfiguration = configuration ?? (try? LocalSourcesConfiguration.loadDefault(fileManager: fileManager))
        guard let loadedConfiguration else { return [] }

        return loadedConfiguration.sources.map { source in
            switch source {
            case .claudeCode, .codex:
                DefaultJSONLUsageAdapter(source: source)
            case .cursor:
                CursorUsageAdapter()
            }
        }
    }

    public static func remoteAdapters(
        configuration: RemoteSourcesConfiguration? = nil,
        fileManager: FileManager = .default
    ) -> [UsageSourceAdapter] {
        let loadedConfiguration = configuration ?? (try? RemoteSourcesConfiguration.loadDefault(fileManager: fileManager))
        guard let loadedConfiguration else { return [] }

        return loadedConfiguration.hosts.flatMap { host in
            host.enabledSources.map { source in
                RemoteUsageSourceAdapter(host: host, source: source, fileManager: fileManager)
            }
        }
    }
}
