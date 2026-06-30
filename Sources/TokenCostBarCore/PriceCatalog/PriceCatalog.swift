import Foundation

public struct PriceCatalog: Sendable {
    public static let fixedUSDCNYRate = Decimal(7)

    private let prices: [ModelPrice]

    public init(prices: [ModelPrice] = PriceCatalog.defaultPrices) {
        self.prices = prices
    }

    public func price(for rawModelName: String) -> ModelPrice? {
        let normalized = ModelPrice.normalize(rawModelName)

        if let exact = prices.first(where: { $0.aliases.contains(normalized) }) {
            return exact
        }

        return prices
            .flatMap { price in
                price.aliases.map { alias in
                    (price: price, alias: alias)
                }
            }
            .filter { item in
                item.alias.count >= 8 && normalized.contains(item.alias)
            }
            .max { lhs, rhs in
                lhs.alias.count < rhs.alias.count
            }?
            .price
    }

    public func cost(for event: UsageEvent) -> CostedUsageEvent {
        guard let price = price(for: event.modelRawName) else {
            return CostedUsageEvent(
                usageEventID: event.id,
                source: event.source,
                occurredAt: event.occurredAt,
                costUSD: 0,
                isPriced: false,
                pricingModelKey: nil
            )
        }

        let million = Decimal(1_000_000)
        let inputContextTokens = event.inputTokens + event.cacheCreationInputTokens + event.cacheReadInputTokens
        let usesLongContext = price.longContextThresholdTokens.map { inputContextTokens > $0 } ?? false
        let inputRate = usesLongContext
            ? (price.longContextInputPerMillionUSD ?? price.inputPerMillionUSD)
            : price.inputPerMillionUSD
        let outputRate = usesLongContext
            ? (price.longContextOutputPerMillionUSD ?? price.outputPerMillionUSD)
            : price.outputPerMillionUSD
        let inputCost = Decimal(event.inputTokens) / million * inputRate
        let cacheWriteRate = price.cacheWritePerMillionUSD ?? price.inputPerMillionUSD
        let cacheReadRate = usesLongContext
            ? (price.longContextCacheReadPerMillionUSD ?? price.cacheReadPerMillionUSD ?? inputRate)
            : (price.cacheReadPerMillionUSD ?? price.inputPerMillionUSD)
        let cacheWriteCost = Decimal(event.cacheCreationInputTokens) / million * cacheWriteRate
        let cacheReadCost = Decimal(event.cacheReadInputTokens) / million * cacheReadRate
        let outputCost = Decimal(event.outputTokens) / million * outputRate

        return CostedUsageEvent(
            usageEventID: event.id,
            source: event.source,
            occurredAt: event.occurredAt,
            costUSD: (inputCost + cacheWriteCost + cacheReadCost + outputCost).rounded(scale: 8),
            isPriced: true,
            pricingModelKey: price.key
        )
    }

    public static let defaultPrices: [ModelPrice] = [
        ModelPrice(
            key: "codex.internal-auto-review",
            aliases: [
                "codex-auto-review"
            ],
            inputPerMillionUSD: 0,
            outputPerMillionUSD: 0
        ),
        ModelPrice(
            key: "openai.gpt-5.3-codex",
            aliases: [
                "gpt-5.3-codex",
                "gpt-5-codex",
                "gpt-codex",
                "codex"
            ],
            inputPerMillionUSD: 1.75,
            cacheReadPerMillionUSD: 0.175,
            outputPerMillionUSD: 14
        ),
        ModelPrice(
            key: "openai.gpt-5",
            aliases: [
                "gpt-5",
                "gpt-5.1",
                "gpt-5.1-chat",
                "gpt-5.4",
                "gpt-5.5"
            ],
            inputPerMillionUSD: 1.25,
            cacheReadPerMillionUSD: 0.125,
            outputPerMillionUSD: 10
        ),
        ModelPrice(
            key: "anthropic.claude-sonnet",
            aliases: [
                "claude-sonnet",
                "claude-sonnet-4",
                "claude-sonnet-4.5",
                "claude-sonnet-4-5",
                "claude-4-sonnet",
                "claude-3-5-sonnet",
                "claude-3.5-sonnet"
            ],
            inputPerMillionUSD: 3,
            cacheWritePerMillionUSD: 3.75,
            cacheReadPerMillionUSD: 0.30,
            outputPerMillionUSD: 15
        ),
        ModelPrice(
            key: "anthropic.claude-opus",
            aliases: [
                "claude-opus",
                "claude-opus-4",
                "claude-opus-4.5",
                "claude-opus-4-5",
                "claude-4-opus",
                "claude-3-opus"
            ],
            inputPerMillionUSD: 15,
            cacheWritePerMillionUSD: 18.75,
            cacheReadPerMillionUSD: 1.50,
            outputPerMillionUSD: 75
        ),
        ModelPrice(
            key: "anthropic.claude-haiku",
            aliases: [
                "claude-haiku",
                "claude-haiku-4.5",
                "claude-haiku-4-5",
                "claude-3-5-haiku",
                "claude-3.5-haiku"
            ],
            inputPerMillionUSD: 1,
            cacheWritePerMillionUSD: 1.25,
            cacheReadPerMillionUSD: 0.10,
            outputPerMillionUSD: 5
        ),
        ModelPrice(
            key: "deepseek.deepseek-v4-flash",
            aliases: [
                "deepseek-v4-flash",
                "deepseek/deepseek-v4-flash",
                "deepseek-chat",
                "deepseek/deepseek-chat",
                "deepseek-reasoner",
                "deepseek/deepseek-reasoner"
            ],
            inputPerMillionUSD: 0.14,
            cacheReadPerMillionUSD: 0.0028,
            outputPerMillionUSD: 0.28
        ),
        ModelPrice(
            key: "deepseek.deepseek-v4-pro",
            aliases: [
                "deepseek-v4-pro",
                "deepseek/deepseek-v4-pro"
            ],
            inputPerMillionUSD: 0.435,
            cacheReadPerMillionUSD: 0.003625,
            outputPerMillionUSD: 0.87
        ),
        ModelPrice(
            key: "zhipu.glm-4.5-flash",
            aliases: [
                "glm-4.5-flash",
                "zhipu/glm-4.5-flash",
                "bigmodel/glm-4.5-flash"
            ],
            inputPerMillionUSD: 0,
            outputPerMillionUSD: 0
        ),
        ModelPrice(
            key: "zhipu.glm-4.5",
            aliases: [
                "glm-4.5",
                "glm-4.5-air",
                "glm-4.5-x",
                "glm-4.5-airx",
                "zhipu/glm-4.5",
                "zhipu/glm-4.5-air",
                "zhipu/glm-4.5-x",
                "zhipu/glm-4.5-airx",
                "bigmodel/glm-4.5",
                "bigmodel/glm-4.5-air",
                "bigmodel/glm-4.5-x",
                "bigmodel/glm-4.5-airx"
            ],
            inputPerMillionUSD: cny(0.8),
            outputPerMillionUSD: cny(2)
        ),
        ModelPrice(
            key: "minimax.minimax-m3",
            aliases: [
                "minimax-m3",
                "minimax/minimax-m3",
                "minimax-m3-standard"
            ],
            inputPerMillionUSD: 0.30,
            cacheReadPerMillionUSD: 0.06,
            outputPerMillionUSD: 1.20,
            longContextThresholdTokens: 512_000,
            longContextInputPerMillionUSD: 0.60,
            longContextCacheReadPerMillionUSD: 0.12,
            longContextOutputPerMillionUSD: 2.40
        ),
        ModelPrice(
            key: "minimax.minimax-m3-priority",
            aliases: [
                "minimax-m3-priority",
                "minimax/minimax-m3-priority"
            ],
            inputPerMillionUSD: 0.45,
            cacheReadPerMillionUSD: 0.09,
            outputPerMillionUSD: 1.80,
            longContextThresholdTokens: 512_000,
            longContextInputPerMillionUSD: 0.90,
            longContextCacheReadPerMillionUSD: 0.18,
            longContextOutputPerMillionUSD: 3.60
        ),
        ModelPrice(
            key: "minimax.minimax-m2.7",
            aliases: [
                "minimax-m2.7",
                "minimax/minimax-m2.7"
            ],
            inputPerMillionUSD: 0.30,
            cacheWritePerMillionUSD: 0.375,
            cacheReadPerMillionUSD: 0.06,
            outputPerMillionUSD: 1.20
        ),
        ModelPrice(
            key: "minimax.minimax-m2.7-highspeed",
            aliases: [
                "minimax-m2.7-highspeed",
                "minimax/minimax-m2.7-highspeed"
            ],
            inputPerMillionUSD: 0.60,
            cacheWritePerMillionUSD: 0.375,
            cacheReadPerMillionUSD: 0.06,
            outputPerMillionUSD: 2.40
        ),
        ModelPrice(
            key: "minimax.legacy-m2",
            aliases: [
                "minimax-m2.5",
                "minimax-m2.1",
                "minimax-m2",
                "minimax/minimax-m2.5",
                "minimax/minimax-m2.1",
                "minimax/minimax-m2"
            ],
            inputPerMillionUSD: 0.30,
            cacheWritePerMillionUSD: 0.375,
            cacheReadPerMillionUSD: 0.03,
            outputPerMillionUSD: 1.20
        ),
        ModelPrice(
            key: "minimax.legacy-m2-highspeed",
            aliases: [
                "minimax-m2.5-highspeed",
                "minimax-m2.1-highspeed",
                "minimax/minimax-m2.5-highspeed",
                "minimax/minimax-m2.1-highspeed"
            ],
            inputPerMillionUSD: 0.60,
            cacheWritePerMillionUSD: 0.375,
            cacheReadPerMillionUSD: 0.03,
            outputPerMillionUSD: 2.40
        )
    ]

    private static func cny(_ value: Decimal) -> Decimal {
        value / fixedUSDCNYRate
    }
}
