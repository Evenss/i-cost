import Foundation

public struct ModelPrice: Equatable, Sendable {
    public let key: String
    public let aliases: [String]
    public let inputPerMillionUSD: Decimal
    public let cacheWritePerMillionUSD: Decimal?
    public let cacheWrite1hPerMillionUSD: Decimal?
    public let cacheReadPerMillionUSD: Decimal?
    public let outputPerMillionUSD: Decimal
    public let longContextThresholdTokens: Int?
    public let longContextInputPerMillionUSD: Decimal?
    public let longContextCacheWritePerMillionUSD: Decimal?
    public let longContextCacheWrite1hPerMillionUSD: Decimal?
    public let longContextCacheReadPerMillionUSD: Decimal?
    public let longContextOutputPerMillionUSD: Decimal?
    public let effectiveFrom: Date?
    public let effectiveBefore: Date?

    public init(
        key: String,
        aliases: [String],
        inputPerMillionUSD: Decimal,
        cacheWritePerMillionUSD: Decimal? = nil,
        cacheWrite1hPerMillionUSD: Decimal? = nil,
        cacheReadPerMillionUSD: Decimal? = nil,
        outputPerMillionUSD: Decimal,
        longContextThresholdTokens: Int? = nil,
        longContextInputPerMillionUSD: Decimal? = nil,
        longContextCacheWritePerMillionUSD: Decimal? = nil,
        longContextCacheWrite1hPerMillionUSD: Decimal? = nil,
        longContextCacheReadPerMillionUSD: Decimal? = nil,
        longContextOutputPerMillionUSD: Decimal? = nil,
        effectiveFrom: Date? = nil,
        effectiveBefore: Date? = nil
    ) {
        self.key = key
        self.aliases = aliases.map(Self.normalize)
        self.inputPerMillionUSD = inputPerMillionUSD
        self.cacheWritePerMillionUSD = cacheWritePerMillionUSD
        self.cacheWrite1hPerMillionUSD = cacheWrite1hPerMillionUSD
        self.cacheReadPerMillionUSD = cacheReadPerMillionUSD
        self.outputPerMillionUSD = outputPerMillionUSD
        self.longContextThresholdTokens = longContextThresholdTokens
        self.longContextInputPerMillionUSD = longContextInputPerMillionUSD
        self.longContextCacheWritePerMillionUSD = longContextCacheWritePerMillionUSD
        self.longContextCacheWrite1hPerMillionUSD = longContextCacheWrite1hPerMillionUSD
        self.longContextCacheReadPerMillionUSD = longContextCacheReadPerMillionUSD
        self.longContextOutputPerMillionUSD = longContextOutputPerMillionUSD
        self.effectiveFrom = effectiveFrom
        self.effectiveBefore = effectiveBefore
    }

    func isEffective(at date: Date) -> Bool {
        if let effectiveFrom, date < effectiveFrom {
            return false
        }

        if let effectiveBefore, date >= effectiveBefore {
            return false
        }

        return true
    }

    static func normalize(_ modelName: String) -> String {
        modelName
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
    }
}
