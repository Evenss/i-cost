import Foundation
import Testing
@testable import TokenCostBarCore

struct PriceCatalogTests {
    @Test
    func testCodexCostUsesInputCachedAndOutputRates() {
        let catalog = PriceCatalog()
        let event = UsageEvent(
            id: "event-1",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "gpt-5-codex",
            inputTokens: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            outputTokens: 1_000_000,
            sourceFile: "/tmp/codex.jsonl"
        )

        let cost = catalog.cost(for: event)

        #expect(cost.isPriced)
        #expect(cost.pricingModelKey == "openai.gpt-5.3-codex")
        #expect(abs(cost.costUSD.doubleValue - 15.925) < 0.0001)
    }

    @Test
    func testUnknownModelIsNotPriced() {
        let catalog = PriceCatalog()
        let event = UsageEvent(
            id: "event-2",
            source: .claudeCode,
            occurredAt: Date(),
            modelRawName: "unknown-model",
            inputTokens: 100,
            outputTokens: 100,
            sourceFile: "/tmp/claude.jsonl"
        )

        let cost = catalog.cost(for: event)

        #expect(!cost.isPriced)
        #expect(cost.pricingModelKey == nil)
        #expect(cost.costUSD == 0)
    }

    @Test
    func testCodexAutoReviewIsTreatedAsZeroCostInternalMarker() {
        let catalog = PriceCatalog()
        let event = UsageEvent(
            id: "event-internal",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "codex-auto-review",
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            sourceFile: "/tmp/codex.jsonl"
        )

        let cost = catalog.cost(for: event)

        #expect(cost.isPriced)
        #expect(cost.pricingModelKey == "codex.internal-auto-review")
        #expect(cost.costUSD == 0)
    }

    @Test
    func testDeepSeekV4ProAliasIsPriced() {
        let catalog = PriceCatalog()
        let event = UsageEvent(
            id: "event-3",
            source: .claudeCode,
            occurredAt: Date(),
            modelRawName: "deepseek/deepseek-v4-pro",
            inputTokens: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            outputTokens: 1_000_000,
            sourceFile: "/tmp/claude.jsonl"
        )

        let cost = catalog.cost(for: event)

        #expect(cost.isPriced)
        #expect(cost.pricingModelKey == "deepseek.deepseek-v4-pro")
        #expect(abs(cost.costUSD.doubleValue - 1.308625) < 0.0001)
    }

    @Test
    func testZhipuGLM45UsesCNYConvertedRates() {
        let catalog = PriceCatalog()
        let event = UsageEvent(
            id: "event-4",
            source: .claudeCode,
            occurredAt: Date(),
            modelRawName: "glm-4.5",
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            sourceFile: "/tmp/claude.jsonl"
        )

        let cost = catalog.cost(for: event)

        #expect(cost.isPriced)
        #expect(cost.pricingModelKey == "zhipu.glm-4.5")
        #expect(abs(cost.costUSD.doubleValue - (2.8 / 7.0)) < 0.0001)
    }

    @Test
    func testMiniMaxM3UsesLongContextRatesAboveThreshold() {
        let catalog = PriceCatalog()
        let event = UsageEvent(
            id: "event-5",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "minimax-m3",
            inputTokens: 600_000,
            outputTokens: 1_000_000,
            sourceFile: "/tmp/codex.jsonl"
        )

        let cost = catalog.cost(for: event)

        #expect(cost.isPriced)
        #expect(cost.pricingModelKey == "minimax.minimax-m3")
        #expect(abs(cost.costUSD.doubleValue - 2.76) < 0.0001)
    }

    @Test
    func testLongestAliasWinsForMiniMaxHighspeedVariants() {
        let catalog = PriceCatalog()
        let event = UsageEvent(
            id: "event-6",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "minimax/minimax-m2.5-highspeed-preview",
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            sourceFile: "/tmp/codex.jsonl"
        )

        let cost = catalog.cost(for: event)

        #expect(cost.isPriced)
        #expect(cost.pricingModelKey == "minimax.legacy-m2-highspeed")
        #expect(abs(cost.costUSD.doubleValue - 3.0) < 0.0001)
    }
}
