import Foundation
import Testing
@testable import TokenCostBarCore

struct DefaultJSONLUsageAdapterTests {
    @Test
    func testCodexIncrementalScanInheritsModelFromEarlierMetadata() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sessionDirectory = home.appendingPathComponent(".codex/sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let metadataLine = #"{"timestamp":"2026-06-30T00:00:00Z","payload":{"model":"gpt-5.4","type":"session_config"}}"# + "\n"
        let usageLine = #"{"timestamp":"2026-06-30T00:01:00Z","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"cached_input_tokens":200,"output_tokens":300}}}}"# + "\n"
        let fileURL = sessionDirectory.appendingPathComponent("session.jsonl")
        try (metadataLine + usageLine).write(to: fileURL, atomically: true, encoding: .utf8)

        let adapter = DefaultJSONLUsageAdapter(source: .codex, homeDirectory: home)
        let cursor = ScanCursor(
            source: .codex,
            filePath: fileURL.path,
            fileSize: Int64(metadataLine.utf8.count),
            fileModifiedAt: nil,
            lastOffset: Int64(metadataLine.utf8.count)
        )

        let output = try adapter.scan(cursors: [fileURL.path: cursor])

        #expect(output.events.count == 1)
        #expect(output.events.first?.modelRawName == "gpt-5.4")
        #expect(output.events.first?.inputTokens == 1000)
        #expect(output.events.first?.cacheReadInputTokens == 200)
        #expect(output.events.first?.outputTokens == 300)
    }
}
