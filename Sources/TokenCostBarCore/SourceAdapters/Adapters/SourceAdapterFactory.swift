import Foundation

public enum SourceAdapterFactory {
    public static func defaultAdapters() -> [UsageSourceAdapter] {
        AgentSource.allCases.map { source in
            switch source {
            case .claudeCode, .codex:
                DefaultJSONLUsageAdapter(source: source)
            case .cursor:
                CursorUsageAdapter()
            }
        }
    }
}
