import Foundation

public struct UsageEvent: Codable, Equatable, Sendable {
    public let id: String
    public let source: AgentSource
    public let occurredAt: Date
    public let modelRawName: String
    public let inputTokens: Int
    public let cacheCreationInputTokens: Int
    public let cacheCreationInputTokens1Hour: Int
    public let cacheReadInputTokens: Int
    public let outputTokens: Int
    public let sourceFile: String
    public let sourceOffset: Int64?

    public init(
        id: String,
        source: AgentSource,
        occurredAt: Date,
        modelRawName: String,
        inputTokens: Int,
        cacheCreationInputTokens: Int = 0,
        cacheCreationInputTokens1Hour: Int = 0,
        cacheReadInputTokens: Int = 0,
        outputTokens: Int,
        sourceFile: String,
        sourceOffset: Int64? = nil
    ) {
        self.id = id
        self.source = source
        self.occurredAt = occurredAt
        self.modelRawName = modelRawName
        self.inputTokens = max(0, inputTokens)
        self.cacheCreationInputTokens = max(0, cacheCreationInputTokens)
        self.cacheCreationInputTokens1Hour = max(0, cacheCreationInputTokens1Hour)
        self.cacheReadInputTokens = max(0, cacheReadInputTokens)
        self.outputTokens = max(0, outputTokens)
        self.sourceFile = sourceFile
        self.sourceOffset = sourceOffset
    }
}

public struct CostedUsageEvent: Codable, Equatable, Sendable {
    public let usageEventID: String
    public let source: AgentSource
    public let occurredAt: Date
    public let costUSD: Decimal
    public let isPriced: Bool
    public let pricingModelKey: String?

    public init(
        usageEventID: String,
        source: AgentSource,
        occurredAt: Date,
        costUSD: Decimal,
        isPriced: Bool,
        pricingModelKey: String?
    ) {
        self.usageEventID = usageEventID
        self.source = source
        self.occurredAt = occurredAt
        self.costUSD = costUSD
        self.isPriced = isPriced
        self.pricingModelKey = pricingModelKey
    }
}
