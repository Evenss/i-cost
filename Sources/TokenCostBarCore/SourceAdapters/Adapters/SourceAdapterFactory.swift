import Foundation

public enum SourceAdapterFactory {
    public static func defaultAdapters() -> [UsageSourceAdapter] {
        AgentSource.allCases.map { source in
            DefaultJSONLUsageAdapter(source: source)
        }
    }
}
