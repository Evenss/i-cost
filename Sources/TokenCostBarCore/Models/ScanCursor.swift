import Foundation

public struct ScanCursor: Codable, Equatable, Sendable {
    public let source: AgentSource
    public let filePath: String
    public var fileSize: Int64
    public var fileModifiedAt: Date?
    public var lastOffset: Int64
    public var lastEventKey: String?
    public var updatedAt: Date

    public init(
        source: AgentSource,
        filePath: String,
        fileSize: Int64,
        fileModifiedAt: Date?,
        lastOffset: Int64,
        lastEventKey: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.source = source
        self.filePath = filePath
        self.fileSize = fileSize
        self.fileModifiedAt = fileModifiedAt
        self.lastOffset = lastOffset
        self.lastEventKey = lastEventKey
        self.updatedAt = updatedAt
    }
}
