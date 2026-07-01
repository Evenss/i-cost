import Foundation

public enum AgentSource: String, CaseIterable, Codable, Sendable {
    case claudeCode = "claude_code"
    case codex
    case cursor

    public var displayName: String {
        switch self {
        case .claudeCode:
            "Claude Code"
        case .codex:
            "Codex"
        case .cursor:
            "Cursor"
        }
    }

    public var defaultRelativePath: String {
        switch self {
        case .claudeCode:
            ".claude/projects"
        case .codex:
            ".codex/sessions"
        case .cursor:
            "Library/Application Support/Cursor/User"
        }
    }
}

public enum SourceStatus: String, Codable, Sendable {
    case ready
    case missing
    case disabled
    case error

    public var displayName: String {
        switch self {
        case .ready:
            "Ready"
        case .missing:
            "Missing"
        case .disabled:
            "Disabled"
        case .error:
            "Error"
        }
    }
}

public struct SourceState: Identifiable, Codable, Equatable, Sendable {
    public var id: String { source.rawValue }

    public let source: AgentSource
    public var displayName: String
    public var isEnabled: Bool
    public var status: SourceStatus
    public var path: String?
    public var lastSyncedAt: Date?
    public var message: String?

    public init(
        source: AgentSource,
        displayName: String? = nil,
        isEnabled: Bool = true,
        status: SourceStatus,
        path: String?,
        lastSyncedAt: Date? = nil,
        message: String? = nil
    ) {
        self.source = source
        self.displayName = displayName ?? source.displayName
        self.isEnabled = isEnabled
        self.status = status
        self.path = path
        self.lastSyncedAt = lastSyncedAt
        self.message = message
    }
}
