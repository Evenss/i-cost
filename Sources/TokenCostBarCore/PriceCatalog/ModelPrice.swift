import Foundation

public struct ModelPrice: Equatable, Sendable {
    public let key: String
    public let aliases: [String]
    public let inputPerMillionUSD: Decimal
    public let cacheWritePerMillionUSD: Decimal?
    public let cacheReadPerMillionUSD: Decimal?
    public let outputPerMillionUSD: Decimal
    public let longContextThresholdTokens: Int?
    public let longContextInputPerMillionUSD: Decimal?
    public let longContextCacheReadPerMillionUSD: Decimal?
    public let longContextOutputPerMillionUSD: Decimal?

    public init(
        key: String,
        aliases: [String],
        inputPerMillionUSD: Decimal,
        cacheWritePerMillionUSD: Decimal? = nil,
        cacheReadPerMillionUSD: Decimal? = nil,
        outputPerMillionUSD: Decimal,
        longContextThresholdTokens: Int? = nil,
        longContextInputPerMillionUSD: Decimal? = nil,
        longContextCacheReadPerMillionUSD: Decimal? = nil,
        longContextOutputPerMillionUSD: Decimal? = nil
    ) {
        self.key = key
        self.aliases = aliases.map(Self.normalize)
        self.inputPerMillionUSD = inputPerMillionUSD
        self.cacheWritePerMillionUSD = cacheWritePerMillionUSD
        self.cacheReadPerMillionUSD = cacheReadPerMillionUSD
        self.outputPerMillionUSD = outputPerMillionUSD
        self.longContextThresholdTokens = longContextThresholdTokens
        self.longContextInputPerMillionUSD = longContextInputPerMillionUSD
        self.longContextCacheReadPerMillionUSD = longContextCacheReadPerMillionUSD
        self.longContextOutputPerMillionUSD = longContextOutputPerMillionUSD
    }

    static func normalize(_ modelName: String) -> String {
        modelName
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
}
