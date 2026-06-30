import Foundation

public struct SourceScanOutput: Sendable {
    public let state: SourceState
    public let events: [UsageEvent]
    public let cursors: [ScanCursor]

    public init(state: SourceState, events: [UsageEvent], cursors: [ScanCursor]) {
        self.state = state
        self.events = events
        self.cursors = cursors
    }
}

public protocol UsageSourceAdapter {
    var source: AgentSource { get }
    var displayName: String { get }

    func discover() -> SourceState
    func scan(cursors: [String: ScanCursor]) throws -> SourceScanOutput
}
