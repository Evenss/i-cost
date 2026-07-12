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
    func testLatestOpenAIModelsUsePublishedShortContextRates() {
        let catalog = PriceCatalog()
        let cases: [(model: String, key: String, expectedUSD: Double)] = [
            ("gpt-5.6", "openai.gpt-5.6-sol", 3.50),
            ("gpt-5.6-terra", "openai.gpt-5.6-terra", 1.75),
            ("gpt-5.6-luna", "openai.gpt-5.6-luna", 0.70),
            ("gpt-5.5", "openai.gpt-5.5", 3.50),
            ("gpt-5.5-pro", "openai.gpt-5.5-pro", 21.00),
            ("gpt-5.4", "openai.gpt-5.4", 1.75),
            ("gpt-5.4-mini", "openai.gpt-5.4-mini", 0.525),
            ("gpt-5.4-nano", "openai.gpt-5.4-nano", 0.145),
            ("gpt-5.4-pro", "openai.gpt-5.4-pro", 21.00)
        ]

        for testCase in cases {
            let cost = catalog.cost(for: event(
                model: testCase.model,
                inputTokens: 100_000,
                outputTokens: 100_000
            ))

            #expect(cost.pricingModelKey == testCase.key)
            #expect(abs(cost.costUSD.doubleValue - testCase.expectedUSD) < 0.0001)
        }
    }

    @Test
    func testGPT56LongContextUsesLongCacheWriteAndReadRates() {
        let catalog = PriceCatalog()
        let cost = catalog.cost(for: event(
            model: "gpt-5.6",
            inputTokens: 100_000,
            cacheCreationInputTokens: 100_000,
            cacheReadInputTokens: 100_000,
            outputTokens: 1_000_000
        ))

        #expect(cost.pricingModelKey == "openai.gpt-5.6-sol")
        #expect(abs(cost.costUSD.doubleValue - 47.35) < 0.0001)
    }

    @Test
    func testGPT56LongContextStartsStrictlyAbove272KInputTokens() {
        let catalog = PriceCatalog()
        let atThreshold = catalog.cost(for: event(
            model: "gpt-5.6",
            inputTokens: 100_000,
            cacheCreationInputTokens: 72_000,
            cacheReadInputTokens: 100_000,
            outputTokens: 1_000_000
        ))
        let aboveThreshold = catalog.cost(for: event(
            model: "gpt-5.6",
            inputTokens: 100_001,
            cacheCreationInputTokens: 72_000,
            cacheReadInputTokens: 100_000,
            outputTokens: 1_000_000
        ))

        #expect(abs(atThreshold.costUSD.doubleValue - 31) < 0.0001)
        #expect(abs(aboveThreshold.costUSD.doubleValue - 47.00001) < 0.0001)
    }

    @Test
    func testOpenAISnapshotsUseTheirSpecificPriceEntries() {
        let catalog = PriceCatalog()
        let cases: [(model: String, key: String)] = [
            ("gpt-5.5-pro-2026-04-23", "openai.gpt-5.5-pro"),
            ("gpt-5.4-2026-03-05", "openai.gpt-5.4"),
            ("gpt-5.4-pro-2026-03-05", "openai.gpt-5.4-pro"),
            ("gpt-5.4-mini-2026-03-17", "openai.gpt-5.4-mini"),
            ("gpt-5.4-nano-2026-03-17", "openai.gpt-5.4-nano")
        ]

        for testCase in cases {
            let cost = catalog.cost(for: event(model: testCase.model))
            #expect(cost.pricingModelKey == testCase.key)
        }
    }

    @Test
    func testLatestClaudeModelsUsePublishedCacheWriteTTLAndReadRates() {
        let catalog = PriceCatalog()
        let cases: [(model: String, key: String, expectedUSD: Double)] = [
            ("claude-fable-5", "anthropic.claude-fable-5", 9.35),
            ("claude-mythos-5", "anthropic.claude-mythos-5", 9.35),
            ("claude-opus-4-8", "anthropic.claude-opus-4.8", 4.675),
            ("claude-haiku-4-5-20251001", "anthropic.claude-haiku-4.5", 0.935)
        ]

        for testCase in cases {
            let cost = catalog.cost(for: event(
                source: .claudeCode,
                model: testCase.model,
                inputTokens: 100_000,
                cacheCreationInputTokens: 100_000,
                cacheCreationInputTokens1Hour: 100_000,
                cacheReadInputTokens: 100_000,
                outputTokens: 100_000
            ))

            #expect(cost.pricingModelKey == testCase.key)
            #expect(abs(cost.costUSD.doubleValue - testCase.expectedUSD) < 0.0001)
        }
    }

    @Test
    func testClaudeSonnet5PriceChangesOnSeptemberFirst() {
        let catalog = PriceCatalog()
        let introductoryCost = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-sonnet-5",
            occurredAt: Date(timeIntervalSince1970: 1_788_220_799),
            inputTokens: 1_000_000,
            cacheCreationInputTokens: 1_000_000,
            cacheCreationInputTokens1Hour: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))
        let standardCost = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-sonnet-5",
            occurredAt: Date(timeIntervalSince1970: 1_788_220_800),
            inputTokens: 1_000_000,
            cacheCreationInputTokens: 1_000_000,
            cacheCreationInputTokens1Hour: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))

        #expect(introductoryCost.pricingModelKey == "anthropic.claude-sonnet-5")
        #expect(abs(introductoryCost.costUSD.doubleValue - 18.70) < 0.0001)
        #expect(standardCost.pricingModelKey == "anthropic.claude-sonnet-5")
        #expect(abs(standardCost.costUSD.doubleValue - 28.05) < 0.0001)
    }

    @Test
    func testClaudeSonnet45LongContextUsesTTLSpecificCacheRates() {
        let catalog = PriceCatalog()
        let cost = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-sonnet-4-5",
            inputTokens: 100_000,
            cacheCreationInputTokens: 100_000,
            cacheCreationInputTokens1Hour: 100_000,
            cacheReadInputTokens: 100_000,
            outputTokens: 1_000_000
        ))

        #expect(cost.pricingModelKey == "anthropic.claude-sonnet-4-4.5")
        #expect(abs(cost.costUSD.doubleValue - 25.11) < 0.0001)
    }

    @Test
    func testUpdatedClaudeLegacyTiersAreSeparated() {
        let catalog = PriceCatalog()
        let opus45 = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-opus-4-5",
            inputTokens: 1_000_000,
            cacheCreationInputTokens: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))
        let haiku35 = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-3-5-haiku",
            inputTokens: 1_000_000,
            cacheCreationInputTokens: 1_000_000,
            cacheReadInputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))

        #expect(opus45.pricingModelKey == "anthropic.claude-opus-4.5-4.7")
        #expect(abs(opus45.costUSD.doubleValue - 36.75) < 0.0001)
        #expect(haiku35.pricingModelKey == "anthropic.claude-haiku-3.5")
        #expect(abs(haiku35.costUSD.doubleValue - 5.88) < 0.0001)
    }

    @Test
    func testUnknownFutureVersionsAndPricingVariantsAreNotSilentlyPriced() {
        let catalog = PriceCatalog()
        let futureModels = [
            "claude-sonnet-6",
            "claude-opus-4.9",
            "claude-opus-4-9",
            "claude-opus-4.10",
            "gpt-5.6:priority",
            "claude-opus-4.8/fast",
            "gpt-5.6.priority",
            "claude-opus-4.8.fast",
            "gpt-5.6-preview-extra",
            "gpt-5.6-latestXYZ"
        ]

        for model in futureModels {
            let cost = catalog.cost(for: event(source: .claudeCode, model: model))
            #expect(!cost.isPriced)
            #expect(cost.pricingModelKey == nil)
        }
    }

    @Test
    func testOfficialProviderAndSnapshotModelIDsAreRecognized() {
        let catalog = PriceCatalog()
        let cases: [(model: String, key: String)] = [
            ("anthropic.claude-opus-4-8", "anthropic.claude-opus-4.8"),
            ("claude-haiku-4-5@20251001", "anthropic.claude-haiku-4.5"),
            ("anthropic.claude-haiku-4-5-20251001-v1:0", "anthropic.claude-haiku-4.5")
        ]

        for testCase in cases {
            let cost = catalog.cost(for: event(source: .claudeCode, model: testCase.model))
            #expect(cost.pricingModelKey == testCase.key)
        }
    }

    @Test
    func testGenericClaudeAliasesKeepHistoricalPriceTiers() {
        let catalog = PriceCatalog()
        let sonnetBefore5 = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-sonnet",
            occurredAt: Date(timeIntervalSince1970: 1_782_777_599),
            inputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))
        let sonnet5 = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-sonnet",
            occurredAt: Date(timeIntervalSince1970: 1_782_777_600),
            inputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))
        let opusLegacy = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-opus",
            occurredAt: Date(timeIntervalSince1970: 1_763_942_399),
            inputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))
        let opusCurrent = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-opus",
            occurredAt: Date(timeIntervalSince1970: 1_763_942_400),
            inputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))
        let haiku35 = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-haiku",
            occurredAt: Date(timeIntervalSince1970: 1_760_486_399),
            inputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))
        let haiku45 = catalog.cost(for: event(
            source: .claudeCode,
            model: "claude-haiku",
            occurredAt: Date(timeIntervalSince1970: 1_760_486_400),
            inputTokens: 1_000_000,
            outputTokens: 1_000_000
        ))

        #expect(sonnetBefore5.pricingModelKey == "anthropic.claude-sonnet-4.6")
        #expect(abs(sonnetBefore5.costUSD.doubleValue - 18) < 0.0001)
        #expect(sonnet5.pricingModelKey == "anthropic.claude-sonnet-5")
        #expect(abs(sonnet5.costUSD.doubleValue - 12) < 0.0001)
        #expect(opusLegacy.pricingModelKey == "anthropic.claude-opus-legacy")
        #expect(abs(opusLegacy.costUSD.doubleValue - 90) < 0.0001)
        #expect(opusCurrent.pricingModelKey == "anthropic.claude-opus-4.5-plus")
        #expect(abs(opusCurrent.costUSD.doubleValue - 30) < 0.0001)
        #expect(haiku35.pricingModelKey == "anthropic.claude-haiku-3.5")
        #expect(abs(haiku35.costUSD.doubleValue - 4.8) < 0.0001)
        #expect(haiku45.pricingModelKey == "anthropic.claude-haiku-4.5")
        #expect(abs(haiku45.costUSD.doubleValue - 6) < 0.0001)
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

    private func event(
        source: AgentSource = .codex,
        model: String,
        occurredAt: Date = Date(timeIntervalSince1970: 1_783_814_400),
        inputTokens: Int = 1,
        cacheCreationInputTokens: Int = 0,
        cacheCreationInputTokens1Hour: Int = 0,
        cacheReadInputTokens: Int = 0,
        outputTokens: Int = 1
    ) -> UsageEvent {
        UsageEvent(
            id: "event-\(model)",
            source: source,
            occurredAt: occurredAt,
            modelRawName: model,
            inputTokens: inputTokens,
            cacheCreationInputTokens: cacheCreationInputTokens,
            cacheCreationInputTokens1Hour: cacheCreationInputTokens1Hour,
            cacheReadInputTokens: cacheReadInputTokens,
            outputTokens: outputTokens,
            sourceFile: "/tmp/usage.jsonl"
        )
    }
}
