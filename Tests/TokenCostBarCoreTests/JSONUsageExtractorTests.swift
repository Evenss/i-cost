import Testing
import Foundation
@testable import TokenCostBarCore

struct JSONUsageExtractorTests {
    @Test
    func testParsesClaudeCodeUsageShape() {
        let extractor = JSONUsageExtractor(source: .claudeCode)
        let line = """
        {"uuid":"abc","timestamp":"2026-06-29T10:00:00Z","message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":1000,"cache_creation_input_tokens":2000,"cache_read_input_tokens":3000,"output_tokens":400}}}
        """

        let event = extractor.event(
            fromJSONLine: line,
            filePath: "/tmp/claude.jsonl",
            offset: 0,
            fallbackDate: Date()
        )

        #expect(event != nil)
        #expect(event?.source == .claudeCode)
        #expect(event?.modelRawName == "claude-sonnet-4-5")
        #expect(event?.inputTokens == 1000)
        #expect(event?.cacheCreationInputTokens == 2000)
        #expect(event?.cacheCreationInputTokens1Hour == 0)
        #expect(event?.cacheReadInputTokens == 3000)
        #expect(event?.outputTokens == 400)
    }

    @Test
    func testParsesClaudeCacheCreationTTLBreakdownWithoutDoubleCountingAggregate() {
        let extractor = JSONUsageExtractor(source: .claudeCode)
        let line = """
        {"uuid":"ttl","timestamp":"2026-07-12T10:00:00Z","message":{"model":"claude-opus-4-8","usage":{"input_tokens":1000,"cache_creation_input_tokens":500,"cache_creation":{"ephemeral_5m_input_tokens":200,"ephemeral_1h_input_tokens":300},"cache_read_input_tokens":400,"output_tokens":50,"iterations":[{"cache_creation":{"ephemeral_5m_input_tokens":50,"ephemeral_1h_input_tokens":75}},{"cache_creation":{"ephemeral_5m_input_tokens":150,"ephemeral_1h_input_tokens":225}}]}}}
        """

        let event = extractor.event(
            fromJSONLine: line,
            filePath: "/tmp/claude.jsonl",
            offset: 0,
            fallbackDate: Date()
        )

        #expect(event != nil)
        #expect(event?.inputTokens == 1000)
        #expect(event?.cacheCreationInputTokens == 200)
        #expect(event?.cacheCreationInputTokens1Hour == 300)
        #expect(event?.cacheReadInputTokens == 400)
        #expect(event?.outputTokens == 50)
    }

    @Test
    func testParsesOpenAICachedTokenDetailsAsOneEvent() {
        let extractor = JSONUsageExtractor(source: .codex)
        let line = """
        {"id":"resp_1","created_at":"2026-06-29T10:00:00Z","model":"gpt-5-codex","usage":{"input_tokens":1000,"input_tokens_details":{"cached_tokens":400},"output_tokens":200}}
        """

        let events = extractor.events(
            fromJSONObject: try! JSONSerialization.jsonObject(with: Data(line.utf8)),
            filePath: "/tmp/codex.jsonl",
            offset: 0,
            fallbackDate: Date()
        )

        #expect(events.count == 1)
        #expect(events.first?.inputTokens == 600)
        #expect(events.first?.cacheCreationInputTokens1Hour == 0)
        #expect(events.first?.cacheReadInputTokens == 400)
        #expect(events.first?.outputTokens == 200)
    }

    @Test
    func testParsesOpenAICacheReadAndWriteDetailsAsInputSubsets() {
        let extractor = JSONUsageExtractor(source: .codex)
        let line = """
        {"id":"resp_2","created_at":"2026-07-12T10:00:00Z","model":"gpt-5.6","usage":{"input_tokens":1000,"input_tokens_details":{"cached_tokens":400,"cache_write_tokens":250},"output_tokens":200}}
        """

        let events = extractor.events(
            fromJSONObject: try! JSONSerialization.jsonObject(with: Data(line.utf8)),
            filePath: "/tmp/codex.jsonl",
            offset: 0,
            fallbackDate: Date()
        )

        #expect(events.count == 1)
        #expect(events.first?.inputTokens == 350)
        #expect(events.first?.cacheCreationInputTokens == 250)
        #expect(events.first?.cacheCreationInputTokens1Hour == 0)
        #expect(events.first?.cacheReadInputTokens == 400)
        #expect(events.first?.outputTokens == 200)
    }
}
