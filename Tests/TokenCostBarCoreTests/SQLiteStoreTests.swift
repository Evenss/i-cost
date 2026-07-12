import Foundation
import SQLite3
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
    func testRepricePreservesFiveMinuteAndOneHourCacheWritesFromStorage() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let event = UsageEvent(
            id: "cache-ttl-event",
            source: .claudeCode,
            occurredAt: Date(),
            modelRawName: "test-cache-ttl",
            inputTokens: 0,
            cacheCreationInputTokens: 1_000_000,
            cacheCreationInputTokens1Hour: 1_000_000,
            outputTokens: 0,
            sourceFile: "/tmp/claude.jsonl"
        )
        let emptyCatalog = PriceCatalog(prices: [])
        let ttlCatalog = PriceCatalog(prices: [
            ModelPrice(
                key: "test.cache-ttl",
                aliases: ["test-cache-ttl"],
                inputPerMillionUSD: 0,
                cacheWritePerMillionUSD: 1,
                cacheWrite1hPerMillionUSD: 2,
                outputPerMillionUSD: 0
            )
        ])

        try store.store(events: [event], costedEvents: [emptyCatalog.cost(for: event)])
        try store.repriceAllEvents(using: ttlCatalog)
        let snapshot = try store.dashboardSnapshot()

        #expect(snapshot.unpricedEventCount == 0)
        #expect(abs(snapshot.todayUSD.doubleValue - 3) < 0.0001)
    }

    @Test
    func testMigrationAddsOneHourCacheColumnToExistingDatabase() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appendingPathComponent("legacy.sqlite")
        var legacyDatabase: OpaquePointer?
        let openResult = sqlite3_open(databaseURL.path, &legacyDatabase)
        #expect(openResult == SQLITE_OK)
        guard openResult == SQLITE_OK, let legacyDatabase else { return }

        let now = DateFormats.string(from: Date())
        let legacySchema = """
        CREATE TABLE usage_events (
          id TEXT PRIMARY KEY,
          source_id TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          model_raw_name TEXT NOT NULL,
          input_tokens INTEGER NOT NULL DEFAULT 0,
          cache_creation_input_tokens INTEGER NOT NULL DEFAULT 0,
          cache_read_input_tokens INTEGER NOT NULL DEFAULT 0,
          output_tokens INTEGER NOT NULL DEFAULT 0,
          source_file TEXT NOT NULL,
          source_offset INTEGER,
          created_at TEXT NOT NULL
        );
        INSERT INTO usage_events VALUES (
          'legacy-cache-event', 'claude_code', '\(now)', 'test-cache-ttl',
          0, 1000000, 0, 0, '/tmp/legacy.jsonl', NULL, '\(now)'
        );
        """
        let schemaResult = sqlite3_exec(legacyDatabase, legacySchema, nil, nil, nil)
        sqlite3_close(legacyDatabase)
        #expect(schemaResult == SQLITE_OK)
        guard schemaResult == SQLITE_OK else { return }

        let catalog = PriceCatalog(prices: [
            ModelPrice(
                key: "test.cache-ttl",
                aliases: ["test-cache-ttl"],
                inputPerMillionUSD: 0,
                cacheWritePerMillionUSD: 1,
                cacheWrite1hPerMillionUSD: 2,
                outputPerMillionUSD: 0
            )
        ])
        let store = try SQLiteStore(databaseURL: databaseURL)
        try store.repriceAllEvents(using: catalog)
        let migratedSnapshot = try store.dashboardSnapshot()

        let reopenedStore = try SQLiteStore(databaseURL: databaseURL)
        try reopenedStore.repriceAllEvents(using: catalog)
        let reopenedSnapshot = try reopenedStore.dashboardSnapshot()

        #expect(abs(migratedSnapshot.todayUSD.doubleValue - 1) < 0.0001)
        #expect(abs(reopenedSnapshot.todayUSD.doubleValue - 1) < 0.0001)
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

    @Test
    func testDeletingInactiveSourceStatesDoesNotDeleteHistoricalUsage() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let event = UsageEvent(
            id: "historical-codex-event",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "gpt-5-codex",
            inputTokens: 1_000,
            outputTokens: 0,
            sourceFile: "/tmp/codex.jsonl"
        )
        try store.upsertSourceState(
            SourceState(source: .claudeCode, status: .ready, path: "~/.claude/projects")
        )
        try store.upsertSourceState(
            SourceState(source: .codex, status: .ready, path: "~/.codex/sessions")
        )
        try store.store(events: [event], costedEvents: [PriceCatalog().cost(for: event)])

        try store.deleteSourceStates(excluding: [AgentSource.claudeCode.rawValue])
        let states = try store.loadSourceStates()
        let snapshot = try store.dashboardSnapshot()

        #expect(states.map(\.id) == [AgentSource.claudeCode.rawValue])
        #expect(snapshot.todayUSD > 0)
    }

    @Test
    func testDeletingOneSourceStateImmediatelyUpdatesSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        try store.upsertSourceState(
            SourceState(source: .claudeCode, status: .ready, path: "~/.claude/projects")
        )
        try store.upsertSourceState(
            SourceState(
                id: "remote:development:codex",
                source: .codex,
                displayName: "Codex @ development",
                status: .error,
                path: "development:~/.codex/sessions"
            )
        )

        try store.deleteSourceState(id: "remote:development:codex")
        let snapshot = try store.dashboardSnapshot()

        #expect(snapshot.sourceStates.map(\.id) == [AgentSource.claudeCode.rawValue])
    }

    @Test
    func testScanCoordinatorRemovesStatesOutsideCurrentAdapterSet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        try store.upsertSourceState(
            SourceState(
                id: "remote:old-host:codex",
                source: .codex,
                displayName: "Codex @ old-host",
                status: .error,
                path: "old-host:~/.codex/sessions"
            )
        )

        let coordinator = ScanCoordinator(store: store, adapters: [ReadyTestAdapter(source: .claudeCode)])
        _ = try coordinator.scanAll()

        let states = try store.loadSourceStates()
        #expect(states.map(\.id) == [AgentSource.claudeCode.rawValue])
    }

    @Test
    func testParserVersionResetOnlyRemovesSelectedSourceOnce() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try SQLiteStore(databaseURL: directory.appendingPathComponent("test.sqlite"))
        let codexEvent = UsageEvent(
            id: "codex-before-parser-reset",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "gpt-5.6-sol",
            inputTokens: 1_000,
            outputTokens: 100,
            sourceFile: "/tmp/codex.jsonl"
        )
        let claudeEvent = UsageEvent(
            id: "claude-preserved",
            source: .claudeCode,
            occurredAt: Date(),
            modelRawName: "claude-sonnet-4-5",
            inputTokens: 1_000,
            outputTokens: 100,
            sourceFile: "/tmp/claude.jsonl"
        )
        try store.store(
            events: [codexEvent, claudeEvent],
            costedEvents: [PriceCatalog().cost(for: codexEvent), PriceCatalog().cost(for: claudeEvent)]
        )
        try store.saveCursor(
            ScanCursor(
                source: .codex,
                filePath: "/tmp/codex.jsonl",
                fileSize: 100,
                fileModifiedAt: nil,
                lastOffset: 100
            )
        )

        #expect(try store.sourceEventsNeedReset(for: .codex, parserVersion: 2))
        try store.resetSourceEvents(for: .codex, parserVersion: 2)

        #expect(!(try store.sourceEventsNeedReset(for: .codex, parserVersion: 2)))
        #expect(try store.loadCursors(for: .codex).isEmpty)
        #expect(try store.loadUsageEvents().map(\.id) == [claudeEvent.id])

        let codexAfterReset = UsageEvent(
            id: "codex-after-parser-reset",
            source: .codex,
            occurredAt: Date(),
            modelRawName: "gpt-5.6-sol",
            inputTokens: 100,
            outputTokens: 10,
            sourceFile: "/tmp/codex.jsonl"
        )
        try store.store(
            events: [codexAfterReset],
            costedEvents: [PriceCatalog().cost(for: codexAfterReset)]
        )
        try store.resetSourceEvents(for: .codex, parserVersion: 2)

        #expect(try store.loadUsageEvents().contains { $0.id == codexAfterReset.id })
    }
}

private struct ReadyTestAdapter: UsageSourceAdapter {
    let source: AgentSource

    var displayName: String { source.displayName }

    func discover() -> SourceState {
        SourceState(source: source, status: .ready, path: nil)
    }

    func scan(cursors: [String: ScanCursor]) throws -> SourceScanOutput {
        SourceScanOutput(state: discover(), events: [], cursors: [])
    }
}
