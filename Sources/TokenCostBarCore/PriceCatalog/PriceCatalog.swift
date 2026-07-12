import Foundation

public struct PriceCatalog: Sendable {
    public static let fixedUSDCNYRate = Decimal(7)
    // 2025-10-15T00:00:00Z, when Claude Haiku 4.5 launched.
    private static let claudeHaiku45PricingStart = Date(timeIntervalSince1970: 1_760_486_400)
    // 2025-11-24T00:00:00Z, when Claude Opus 4.5 introduced the $5/$25 tier.
    private static let claudeOpusCurrentPricingStart = Date(timeIntervalSince1970: 1_763_942_400)
    // 2026-02-17T00:00:00Z, when Claude Sonnet 4.6 launched with flat 1M pricing.
    private static let claudeSonnet46PricingStart = Date(timeIntervalSince1970: 1_771_286_400)
    // 2026-06-30T00:00:00Z, when Claude Sonnet 5 launched.
    private static let claudeSonnet5PricingStart = Date(timeIntervalSince1970: 1_782_777_600)
    // 2026-09-01T00:00:00Z, immediately after the introductory-price period.
    private static let claudeSonnet5StandardPricingStart = Date(timeIntervalSince1970: 1_788_220_800)
    private static let exactOnlyAliases: Set<String> = [
        "claude-haiku",
        "claude-opus",
        "claude-sonnet"
    ]

    private let prices: [ModelPrice]

    public init(prices: [ModelPrice] = PriceCatalog.defaultPrices) {
        self.prices = prices
    }

    public func price(for rawModelName: String, at date: Date = Date()) -> ModelPrice? {
        let normalized = ModelPrice.normalize(rawModelName)
        let effectivePrices = prices.filter { $0.isEffective(at: date) }

        if let exact = effectivePrices.first(where: { $0.aliases.contains(normalized) }) {
            return exact
        }

        return effectivePrices
            .flatMap { price in
                price.aliases.map { alias in
                    (price: price, alias: alias)
                }
            }
            .filter { item in
                item.alias.count >= 8
                    && !Self.exactOnlyAliases.contains(item.alias)
                    && Self.isContainedAliasMatch(item.alias, in: normalized)
            }
            .max { lhs, rhs in
                lhs.alias.count < rhs.alias.count
            }?
            .price
    }

    private static func isContainedAliasMatch(_ alias: String, in modelName: String) -> Bool {
        guard let range = modelName.range(of: alias) else {
            return false
        }

        if range.lowerBound != modelName.startIndex {
            let preceding = modelName[modelName.index(before: range.lowerBound)]
            guard !preceding.isLetter, !preceding.isNumber else {
                return false
            }
        }

        guard range.upperBound != modelName.endIndex else {
            return true
        }

        let suffix = modelName[range.upperBound...]
        guard let separator = suffix.first, !separator.isLetter, !separator.isNumber else {
            return false
        }

        let remainder = suffix.dropFirst()
        switch separator {
        case "-":
            return remainder == "preview"
                || remainder == "latest"
                || isSnapshotSuffix(remainder)
        case "@":
            return isSnapshotSuffix(remainder, allowsRevision: false)
        default:
            return false
        }
    }

    private static func isSnapshotSuffix(_ suffix: Substring, allowsRevision: Bool = true) -> Bool {
        let value = String(suffix)
        let datePart: Substring

        if let revisionRange = value.range(of: "-v") {
            guard allowsRevision else { return false }
            datePart = value[..<revisionRange.lowerBound]
            let revision = value[revisionRange.upperBound...]
            let revisionParts = revision.split(separator: ":", omittingEmptySubsequences: false)
            guard revisionParts.count == 2,
                  revisionParts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else {
                return false
            }
        } else {
            datePart = value[...]
        }

        if datePart.count == 8, datePart.allSatisfy(\.isNumber) {
            return true
        }

        let dateComponents = datePart.split(separator: "-", omittingEmptySubsequences: false)
        return dateComponents.count == 3
            && dateComponents[0].count == 4
            && dateComponents[1].count == 2
            && dateComponents[2].count == 2
            && dateComponents.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    public func cost(for event: UsageEvent) -> CostedUsageEvent {
        guard let price = price(for: event.modelRawName, at: event.occurredAt) else {
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
        let inputContextTokens = event.inputTokens
            + event.cacheCreationInputTokens
            + event.cacheCreationInputTokens1Hour
            + event.cacheReadInputTokens
        let usesLongContext = price.longContextThresholdTokens.map { inputContextTokens > $0 } ?? false
        let inputRate = usesLongContext
            ? (price.longContextInputPerMillionUSD ?? price.inputPerMillionUSD)
            : price.inputPerMillionUSD
        let outputRate = usesLongContext
            ? (price.longContextOutputPerMillionUSD ?? price.outputPerMillionUSD)
            : price.outputPerMillionUSD
        let inputCost = Decimal(event.inputTokens) / million * inputRate
        let cacheWriteRate = usesLongContext
            ? (price.longContextCacheWritePerMillionUSD ?? price.cacheWritePerMillionUSD ?? inputRate)
            : (price.cacheWritePerMillionUSD ?? price.inputPerMillionUSD)
        let cacheWrite1hRate = usesLongContext
            ? (price.longContextCacheWrite1hPerMillionUSD
                ?? price.cacheWrite1hPerMillionUSD
                ?? price.longContextCacheWritePerMillionUSD
                ?? price.cacheWritePerMillionUSD
                ?? inputRate)
            : (price.cacheWrite1hPerMillionUSD
                ?? price.cacheWritePerMillionUSD
                ?? price.inputPerMillionUSD)
        let cacheReadRate = usesLongContext
            ? (price.longContextCacheReadPerMillionUSD ?? price.cacheReadPerMillionUSD ?? inputRate)
            : (price.cacheReadPerMillionUSD ?? price.inputPerMillionUSD)
        let cacheWriteCost = Decimal(event.cacheCreationInputTokens) / million * cacheWriteRate
        let cacheWrite1hCost = Decimal(event.cacheCreationInputTokens1Hour) / million * cacheWrite1hRate
        let cacheReadCost = Decimal(event.cacheReadInputTokens) / million * cacheReadRate
        let outputCost = Decimal(event.outputTokens) / million * outputRate

        return CostedUsageEvent(
            usageEventID: event.id,
            source: event.source,
            occurredAt: event.occurredAt,
            costUSD: (inputCost + cacheWriteCost + cacheWrite1hCost + cacheReadCost + outputCost).rounded(scale: 8),
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
        // Standard API pricing verified on 2026-07-12:
        // https://developers.openai.com/api/docs/pricing
        ModelPrice(
            key: "openai.gpt-5.6-sol",
            aliases: [
                "gpt-5.6-sol",
                "gpt-5.6"
            ],
            inputPerMillionUSD: 5,
            cacheWritePerMillionUSD: 6.25,
            cacheReadPerMillionUSD: 0.50,
            outputPerMillionUSD: 30,
            longContextThresholdTokens: 272_000,
            longContextInputPerMillionUSD: 10,
            longContextCacheWritePerMillionUSD: 12.50,
            longContextCacheReadPerMillionUSD: 1,
            longContextOutputPerMillionUSD: 45
        ),
        ModelPrice(
            key: "openai.gpt-5.6-terra",
            aliases: [
                "gpt-5.6-terra"
            ],
            inputPerMillionUSD: 2.50,
            cacheWritePerMillionUSD: 3.125,
            cacheReadPerMillionUSD: 0.25,
            outputPerMillionUSD: 15,
            longContextThresholdTokens: 272_000,
            longContextInputPerMillionUSD: 5,
            longContextCacheWritePerMillionUSD: 6.25,
            longContextCacheReadPerMillionUSD: 0.50,
            longContextOutputPerMillionUSD: 22.50
        ),
        ModelPrice(
            key: "openai.gpt-5.6-luna",
            aliases: [
                "gpt-5.6-luna"
            ],
            inputPerMillionUSD: 1,
            cacheWritePerMillionUSD: 1.25,
            cacheReadPerMillionUSD: 0.10,
            outputPerMillionUSD: 6,
            longContextThresholdTokens: 272_000,
            longContextInputPerMillionUSD: 2,
            longContextCacheWritePerMillionUSD: 2.50,
            longContextCacheReadPerMillionUSD: 0.20,
            longContextOutputPerMillionUSD: 9
        ),
        ModelPrice(
            key: "openai.gpt-5.5-pro",
            aliases: [
                "gpt-5.5-pro",
                "gpt-5.5-pro-2026-04-23"
            ],
            inputPerMillionUSD: 30,
            outputPerMillionUSD: 180,
            longContextThresholdTokens: 272_000,
            longContextInputPerMillionUSD: 60,
            longContextOutputPerMillionUSD: 270
        ),
        ModelPrice(
            key: "openai.gpt-5.5",
            aliases: [
                "gpt-5.5",
                "gpt-5.5-2026-04-23"
            ],
            inputPerMillionUSD: 5,
            cacheReadPerMillionUSD: 0.50,
            outputPerMillionUSD: 30,
            longContextThresholdTokens: 272_000,
            longContextInputPerMillionUSD: 10,
            longContextCacheReadPerMillionUSD: 1,
            longContextOutputPerMillionUSD: 45
        ),
        ModelPrice(
            key: "openai.gpt-5.4-pro",
            aliases: [
                "gpt-5.4-pro",
                "gpt-5.4-pro-2026-03-05"
            ],
            inputPerMillionUSD: 30,
            outputPerMillionUSD: 180,
            longContextThresholdTokens: 272_000,
            longContextInputPerMillionUSD: 60,
            longContextOutputPerMillionUSD: 270
        ),
        ModelPrice(
            key: "openai.gpt-5.4-mini",
            aliases: [
                "gpt-5.4-mini",
                "gpt-5.4-mini-2026-03-17"
            ],
            inputPerMillionUSD: 0.75,
            cacheReadPerMillionUSD: 0.075,
            outputPerMillionUSD: 4.50
        ),
        ModelPrice(
            key: "openai.gpt-5.4-nano",
            aliases: [
                "gpt-5.4-nano",
                "gpt-5.4-nano-2026-03-17"
            ],
            inputPerMillionUSD: 0.20,
            cacheReadPerMillionUSD: 0.02,
            outputPerMillionUSD: 1.25
        ),
        ModelPrice(
            key: "openai.gpt-5.4",
            aliases: [
                "gpt-5.4",
                "gpt-5.4-2026-03-05"
            ],
            inputPerMillionUSD: 2.50,
            cacheReadPerMillionUSD: 0.25,
            outputPerMillionUSD: 15,
            longContextThresholdTokens: 272_000,
            longContextInputPerMillionUSD: 5,
            longContextCacheReadPerMillionUSD: 0.50,
            longContextOutputPerMillionUSD: 22.50
        ),
        ModelPrice(
            key: "openai.gpt-5",
            aliases: [
                "gpt-5",
                "gpt-5.1",
                "gpt-5.1-chat"
            ],
            inputPerMillionUSD: 1.25,
            cacheReadPerMillionUSD: 0.125,
            outputPerMillionUSD: 10
        ),
        // Claude API global, standard-tier pricing verified on 2026-07-12.
        // Five-minute and one-hour cache writes are priced separately when the
        // usage payload exposes TTL details; legacy aggregate writes use five minutes.
        // https://platform.claude.com/docs/en/about-claude/pricing
        ModelPrice(
            key: "anthropic.claude-fable-5",
            aliases: [
                "claude-fable-5"
            ],
            inputPerMillionUSD: 10,
            cacheWritePerMillionUSD: 12.50,
            cacheWrite1hPerMillionUSD: 20,
            cacheReadPerMillionUSD: 1,
            outputPerMillionUSD: 50
        ),
        ModelPrice(
            key: "anthropic.claude-mythos-5",
            aliases: [
                "claude-mythos-5",
                "claude-mythos-preview"
            ],
            inputPerMillionUSD: 10,
            cacheWritePerMillionUSD: 12.50,
            cacheWrite1hPerMillionUSD: 20,
            cacheReadPerMillionUSD: 1,
            outputPerMillionUSD: 50
        ),
        ModelPrice(
            key: "anthropic.claude-opus-legacy",
            aliases: [
                "claude-opus"
            ],
            inputPerMillionUSD: 15,
            cacheWritePerMillionUSD: 18.75,
            cacheWrite1hPerMillionUSD: 30,
            cacheReadPerMillionUSD: 1.50,
            outputPerMillionUSD: 75,
            effectiveBefore: claudeOpusCurrentPricingStart
        ),
        ModelPrice(
            key: "anthropic.claude-opus-4.5-plus",
            aliases: [
                "claude-opus"
            ],
            inputPerMillionUSD: 5,
            cacheWritePerMillionUSD: 6.25,
            cacheWrite1hPerMillionUSD: 10,
            cacheReadPerMillionUSD: 0.50,
            outputPerMillionUSD: 25,
            effectiveFrom: claudeOpusCurrentPricingStart
        ),
        ModelPrice(
            key: "anthropic.claude-opus-4.8",
            aliases: [
                "claude-opus-4.8",
                "claude-opus-4-8",
                "claude-4.8-opus"
            ],
            inputPerMillionUSD: 5,
            cacheWritePerMillionUSD: 6.25,
            cacheWrite1hPerMillionUSD: 10,
            cacheReadPerMillionUSD: 0.50,
            outputPerMillionUSD: 25
        ),
        ModelPrice(
            key: "anthropic.claude-opus-4.5-4.7",
            aliases: [
                "claude-opus-4.7",
                "claude-opus-4-7",
                "claude-4.7-opus",
                "claude-opus-4.6",
                "claude-opus-4-6",
                "claude-4.6-opus",
                "claude-opus-4.5",
                "claude-opus-4-5",
                "claude-4.5-opus"
            ],
            inputPerMillionUSD: 5,
            cacheWritePerMillionUSD: 6.25,
            cacheWrite1hPerMillionUSD: 10,
            cacheReadPerMillionUSD: 0.50,
            outputPerMillionUSD: 25
        ),
        ModelPrice(
            key: "anthropic.claude-opus-legacy",
            aliases: [
                "claude-opus-4.1",
                "claude-opus-4-1",
                "claude-opus-4",
                "claude-4-opus",
                "claude-3-opus"
            ],
            inputPerMillionUSD: 15,
            cacheWritePerMillionUSD: 18.75,
            cacheWrite1hPerMillionUSD: 30,
            cacheReadPerMillionUSD: 1.50,
            outputPerMillionUSD: 75
        ),
        ModelPrice(
            key: "anthropic.claude-sonnet-4-4.5",
            aliases: [
                "claude-sonnet"
            ],
            inputPerMillionUSD: 3,
            cacheWritePerMillionUSD: 3.75,
            cacheWrite1hPerMillionUSD: 6,
            cacheReadPerMillionUSD: 0.30,
            outputPerMillionUSD: 15,
            longContextThresholdTokens: 200_000,
            longContextInputPerMillionUSD: 6,
            longContextCacheWritePerMillionUSD: 7.50,
            longContextCacheWrite1hPerMillionUSD: 12,
            longContextCacheReadPerMillionUSD: 0.60,
            longContextOutputPerMillionUSD: 22.50,
            effectiveBefore: claudeSonnet46PricingStart
        ),
        ModelPrice(
            key: "anthropic.claude-sonnet-4.6",
            aliases: [
                "claude-sonnet"
            ],
            inputPerMillionUSD: 3,
            cacheWritePerMillionUSD: 3.75,
            cacheWrite1hPerMillionUSD: 6,
            cacheReadPerMillionUSD: 0.30,
            outputPerMillionUSD: 15,
            effectiveFrom: claudeSonnet46PricingStart,
            effectiveBefore: claudeSonnet5PricingStart
        ),
        ModelPrice(
            key: "anthropic.claude-sonnet-5",
            aliases: [
                "claude-sonnet",
                "claude-sonnet-5",
                "claude-5-sonnet"
            ],
            inputPerMillionUSD: 2,
            cacheWritePerMillionUSD: 2.50,
            cacheWrite1hPerMillionUSD: 4,
            cacheReadPerMillionUSD: 0.20,
            outputPerMillionUSD: 10,
            effectiveFrom: claudeSonnet5PricingStart,
            effectiveBefore: claudeSonnet5StandardPricingStart
        ),
        ModelPrice(
            key: "anthropic.claude-sonnet-5",
            aliases: [
                "claude-sonnet",
                "claude-sonnet-5",
                "claude-5-sonnet"
            ],
            inputPerMillionUSD: 3,
            cacheWritePerMillionUSD: 3.75,
            cacheWrite1hPerMillionUSD: 6,
            cacheReadPerMillionUSD: 0.30,
            outputPerMillionUSD: 15,
            effectiveFrom: claudeSonnet5StandardPricingStart
        ),
        ModelPrice(
            key: "anthropic.claude-sonnet-4.6",
            aliases: [
                "claude-sonnet-4.6",
                "claude-sonnet-4-6",
                "claude-4.6-sonnet"
            ],
            inputPerMillionUSD: 3,
            cacheWritePerMillionUSD: 3.75,
            cacheWrite1hPerMillionUSD: 6,
            cacheReadPerMillionUSD: 0.30,
            outputPerMillionUSD: 15
        ),
        ModelPrice(
            key: "anthropic.claude-sonnet-4-4.5",
            aliases: [
                "claude-sonnet-4.5",
                "claude-sonnet-4-5",
                "claude-4.5-sonnet",
                "claude-sonnet-4",
                "claude-4-sonnet"
            ],
            inputPerMillionUSD: 3,
            cacheWritePerMillionUSD: 3.75,
            cacheWrite1hPerMillionUSD: 6,
            cacheReadPerMillionUSD: 0.30,
            outputPerMillionUSD: 15,
            longContextThresholdTokens: 200_000,
            longContextInputPerMillionUSD: 6,
            longContextCacheWritePerMillionUSD: 7.50,
            longContextCacheWrite1hPerMillionUSD: 12,
            longContextCacheReadPerMillionUSD: 0.60,
            longContextOutputPerMillionUSD: 22.50
        ),
        ModelPrice(
            key: "anthropic.claude-sonnet-3.x",
            aliases: [
                "claude-sonnet-3.7",
                "claude-sonnet-3-7",
                "claude-3.7-sonnet",
                "claude-3-7-sonnet",
                "claude-3-5-sonnet",
                "claude-3.5-sonnet"
            ],
            inputPerMillionUSD: 3,
            cacheWritePerMillionUSD: 3.75,
            cacheWrite1hPerMillionUSD: 6,
            cacheReadPerMillionUSD: 0.30,
            outputPerMillionUSD: 15
        ),
        ModelPrice(
            key: "anthropic.claude-haiku-3.5",
            aliases: [
                "claude-haiku"
            ],
            inputPerMillionUSD: 0.80,
            cacheWritePerMillionUSD: 1,
            cacheWrite1hPerMillionUSD: 1.60,
            cacheReadPerMillionUSD: 0.08,
            outputPerMillionUSD: 4,
            effectiveBefore: claudeHaiku45PricingStart
        ),
        ModelPrice(
            key: "anthropic.claude-haiku-4.5",
            aliases: [
                "claude-haiku"
            ],
            inputPerMillionUSD: 1,
            cacheWritePerMillionUSD: 1.25,
            cacheWrite1hPerMillionUSD: 2,
            cacheReadPerMillionUSD: 0.10,
            outputPerMillionUSD: 5,
            effectiveFrom: claudeHaiku45PricingStart
        ),
        ModelPrice(
            key: "anthropic.claude-haiku-4.5",
            aliases: [
                "claude-haiku-4.5",
                "claude-haiku-4-5",
                "claude-4.5-haiku"
            ],
            inputPerMillionUSD: 1,
            cacheWritePerMillionUSD: 1.25,
            cacheWrite1hPerMillionUSD: 2,
            cacheReadPerMillionUSD: 0.10,
            outputPerMillionUSD: 5
        ),
        ModelPrice(
            key: "anthropic.claude-haiku-3.5",
            aliases: [
                "claude-haiku-3.5",
                "claude-haiku-3-5",
                "claude-3.5-haiku",
                "claude-3-5-haiku"
            ],
            inputPerMillionUSD: 0.80,
            cacheWritePerMillionUSD: 1,
            cacheWrite1hPerMillionUSD: 1.60,
            cacheReadPerMillionUSD: 0.08,
            outputPerMillionUSD: 4
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
