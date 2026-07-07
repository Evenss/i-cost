import Foundation
import Testing
@testable import TokenCostBarCore

struct SQLiteStoreTests {
    @Test
    func testStoreDeduplicatesEventsAndBuildsSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let catalog = PriceCatalog()
        let event = UsageEvent(
            id: "stable-event",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "gpt-5-codex",
            inputTokens: 1_000_000,
            outputTokens: 0,
            sourceFile: "/tmp/codex.jsonl"
        )
        let cost = catalog.cost(for: event)

        let firstInsert = try store.store(events: [event], costedEvents: [cost])
        let secondInsert = try store.store(events: [event], costedEvents: [cost])
        let snapshot = try store.dashboardSnapshot()

        #expect(firstInsert == 1)
        #expect(secondInsert == 0)
        #expect(abs(snapshot.todayUSD.doubleValue - 1.75) < 0.0001)
        #expect(abs(snapshot.todayCNY.doubleValue - 12.25) < 0.0001)
    }

    @Test
    func testRepriceAllEventsUpdatesPreviouslyUnpricedRows() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let event = UsageEvent(
            id: "repriced-event",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "codex-auto-review",
            inputTokens: 1_000_000,
            outputTokens: 1_000_000,
            sourceFile: "/tmp/codex.jsonl"
        )
        let emptyCatalog = PriceCatalog(prices: [])
        let unpriced = emptyCatalog.cost(for: event)

        try store.store(events: [event], costedEvents: [unpriced])
        let before = try store.dashboardSnapshot()

        try store.repriceAllEvents(using: PriceCatalog())
        let after = try store.dashboardSnapshot()

        #expect(before.unpricedEventCount == 1)
        #expect(after.unpricedEventCount == 0)
        #expect(after.todayUSD == 0)
    }

    @Test
    func testDeleteUnknownModelEventsResetsAffectedCursors() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let event = UsageEvent(
            id: "unknown-event",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "unknown",
            inputTokens: 100,
            outputTokens: 100,
            sourceFile: "/tmp/codex.jsonl"
        )
        try store.store(events: [event], costedEvents: [PriceCatalog(prices: []).cost(for: event)])
        try store.saveCursor(
            ScanCursor(
                source: .codex,
                filePath: "/tmp/codex.jsonl",
                fileSize: 1000,
                fileModifiedAt: nil,
                lastOffset: 1000
            )
        )

        let deletedFiles = try store.deleteUnknownModelEventsAndResetCursors()
        let snapshot = try store.dashboardSnapshot()
        let cursors = try store.loadCursors(for: .codex)

        #expect(deletedFiles == 1)
        #expect(snapshot.unpricedEventCount == 0)
        #expect(cursors["/tmp/codex.jsonl"] == nil)
    }

    @Test
    func testSourceStatesSupportMultipleLocationsForSameAgent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        try store.upsertSourceState(
            SourceState(
                source: .codex,
                displayName: "Codex",
                status: .ready,
                path: "~/.codex/sessions"
            )
        )
        try store.upsertSourceState(
            SourceState(
                id: "remote:server:codex",
                source: .codex,
                displayName: "Codex @ server",
                status: .ready,
                path: "server:~/.codex/sessions"
            )
        )

        let states = try store.loadSourceStates()
        let codexStates = states.filter { $0.source == .codex }

        #expect(codexStates.contains { $0.id == AgentSource.codex.rawValue })
        #expect(codexStates.contains { $0.id == "remote:server:codex" })
    }
}
