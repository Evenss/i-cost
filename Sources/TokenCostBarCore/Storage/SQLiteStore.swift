import Foundation
import SQLite3

public enum SQLiteStoreError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case executionFailed(String)
    case invalidSource(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            "Failed to open database: \(message)"
        case .prepareFailed(let message):
            "Failed to prepare statement: \(message)"
        case .executionFailed(let message):
            "SQLite execution failed: \(message)"
        case .invalidSource(let value):
            "Unknown source: \(value)"
        }
    }
}

public final class SQLiteStore {
    public let databaseURL: URL
    private var db: OpaquePointer?

    public convenience init() throws {
        let environment = ProcessInfo.processInfo.environment
        if let overridePath = environment["I_COST_DATABASE"],
           !overridePath.isEmpty {
            let url = URL(fileURLWithPath: overridePath)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try self.init(databaseURL: url)
            return
        }

        let directory = try Self.defaultApplicationSupportDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try self.init(databaseURL: directory.appendingPathComponent("token-cost.sqlite"))
    }

    public init(databaseURL: URL) throws {
        self.databaseURL = databaseURL

        if sqlite3_open_v2(
            databaseURL.path,
            &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) != SQLITE_OK {
            throw SQLiteStoreError.openFailed(lastErrorMessage)
        }

        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    public func upsertSourceState(_ state: SourceState) throws {
        let sql = """
        INSERT INTO sources (id, source_id, display_name, enabled, path, status, last_synced_at, message, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          source_id = excluded.source_id,
          display_name = excluded.display_name,
          enabled = excluded.enabled,
          path = excluded.path,
          status = excluded.status,
          last_synced_at = excluded.last_synced_at,
          message = excluded.message,
          updated_at = excluded.updated_at;
        """

        try withStatement(sql) { statement in
            bindText(state.id, to: 1, in: statement)
            bindText(state.source.rawValue, to: 2, in: statement)
            bindText(state.displayName, to: 3, in: statement)
            sqlite3_bind_int(statement, 4, state.isEnabled ? 1 : 0)
            bindText(state.path, to: 5, in: statement)
            bindText(state.status.rawValue, to: 6, in: statement)
            bindText(state.lastSyncedAt.map(DateFormats.string), to: 7, in: statement)
            bindText(state.message, to: 8, in: statement)
            bindText(DateFormats.string(from: Date()), to: 9, in: statement)
            try stepDone(statement)
        }
    }

    public func deleteSourceStates(excluding activeIDs: Set<String>) throws {
        guard !activeIDs.isEmpty else {
            try execute("DELETE FROM sources;")
            return
        }

        let placeholders = Array(repeating: "?", count: activeIDs.count).joined(separator: ", ")
        let sql = "DELETE FROM sources WHERE id NOT IN (\(placeholders));"

        try withStatement(sql) { statement in
            for (index, id) in activeIDs.sorted().enumerated() {
                bindText(id, to: Int32(index + 1), in: statement)
            }
            try stepDone(statement)
        }
    }

    public func loadSourceStates() throws -> [SourceState] {
        let sql = """
        SELECT id, COALESCE(NULLIF(source_id, ''), id), display_name, enabled, path, status, last_synced_at, message
        FROM sources
        ORDER BY display_name;
        """

        var states: [SourceState] = []

        try withStatement(sql) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                let rawSource = columnText(statement, 1)
                guard let source = AgentSource(rawValue: rawSource) else {
                    throw SQLiteStoreError.invalidSource(rawSource)
                }

                let status = SourceStatus(rawValue: columnText(statement, 5)) ?? .error
                let syncedString = columnOptionalText(statement, 6)

                states.append(
                    SourceState(
                        id: columnText(statement, 0),
                        source: source,
                        displayName: columnText(statement, 2),
                        isEnabled: sqlite3_column_int(statement, 3) == 1,
                        status: status,
                        path: columnOptionalText(statement, 4),
                        lastSyncedAt: syncedString.flatMap(DateFormats.date),
                        message: columnOptionalText(statement, 7)
                    )
                )
            }
        }

        return states.sorted { $0.displayName < $1.displayName }
    }

    public func loadCursors(for source: AgentSource) throws -> [String: ScanCursor] {
        let sql = """
        SELECT file_path, file_size, file_modified_at, last_offset, last_event_key, updated_at
        FROM scan_cursors
        WHERE source_id = ?;
        """

        var cursors: [String: ScanCursor] = [:]

        try withStatement(sql) { statement in
            bindText(source.rawValue, to: 1, in: statement)

            while sqlite3_step(statement) == SQLITE_ROW {
                let filePath = columnText(statement, 0)
                cursors[filePath] = ScanCursor(
                    source: source,
                    filePath: filePath,
                    fileSize: sqlite3_column_int64(statement, 1),
                    fileModifiedAt: columnOptionalText(statement, 2).flatMap(DateFormats.date),
                    lastOffset: sqlite3_column_int64(statement, 3),
                    lastEventKey: columnOptionalText(statement, 4),
                    updatedAt: columnOptionalText(statement, 5).flatMap(DateFormats.date) ?? Date()
                )
            }
        }

        return cursors
    }

    public func saveCursor(_ cursor: ScanCursor) throws {
        let sql = """
        INSERT INTO scan_cursors (
          source_id, file_path, file_size, file_modified_at, last_offset, last_event_key, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(source_id, file_path) DO UPDATE SET
          file_size = excluded.file_size,
          file_modified_at = excluded.file_modified_at,
          last_offset = excluded.last_offset,
          last_event_key = excluded.last_event_key,
          updated_at = excluded.updated_at;
        """

        try withStatement(sql) { statement in
            bindText(cursor.source.rawValue, to: 1, in: statement)
            bindText(cursor.filePath, to: 2, in: statement)
            sqlite3_bind_int64(statement, 3, cursor.fileSize)
            bindText(cursor.fileModifiedAt.map(DateFormats.string), to: 4, in: statement)
            sqlite3_bind_int64(statement, 5, cursor.lastOffset)
            bindText(cursor.lastEventKey, to: 6, in: statement)
            bindText(DateFormats.string(from: cursor.updatedAt), to: 7, in: statement)
            try stepDone(statement)
        }
    }

    @discardableResult
    public func store(events: [UsageEvent], costedEvents: [CostedUsageEvent]) throws -> Int {
        guard events.count == costedEvents.count else { return 0 }

        try execute("BEGIN IMMEDIATE TRANSACTION;")
        var inserted = 0

        do {
            for (event, costedEvent) in zip(events, costedEvents) {
                let wasInserted = try insertUsageEvent(event)
                guard wasInserted else { continue }

                inserted += 1
                try insertCostedUsageEvent(costedEvent)

                if !costedEvent.isPriced {
                    try recordUnknownModel(event)
                }
            }

            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }

        try rebuildDailyRollups()
        return inserted
    }

    public func repriceAllEvents(using priceCatalog: PriceCatalog) throws {
        let events = try loadUsageEvents()

        try execute("BEGIN IMMEDIATE TRANSACTION;")

        do {
            try execute("DELETE FROM costed_usage_events;")
            try execute("DELETE FROM unknown_models;")

            for event in events {
                let costedEvent = priceCatalog.cost(for: event)
                try insertCostedUsageEvent(costedEvent)

                if !costedEvent.isPriced {
                    try recordUnknownModel(event)
                }
            }

            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }

        try rebuildDailyRollups()
    }

    @discardableResult
    public func deleteUnknownModelEventsAndResetCursors() throws -> Int {
        let unknownFiles = try loadUnknownModelFiles()
        guard !unknownFiles.isEmpty else { return 0 }

        try execute("BEGIN IMMEDIATE TRANSACTION;")

        do {
            try execute("""
            DELETE FROM costed_usage_events
            WHERE usage_event_id IN (
              SELECT id FROM usage_events WHERE model_raw_name = 'unknown'
            );
            """)

            try execute("DELETE FROM usage_events WHERE model_raw_name = 'unknown';")
            try execute("DELETE FROM unknown_models;")

            let deleteCursorSQL = """
            DELETE FROM scan_cursors
            WHERE source_id = ? AND file_path = ?;
            """

            try withStatement(deleteCursorSQL) { statement in
                for item in unknownFiles {
                    sqlite3_reset(statement)
                    sqlite3_clear_bindings(statement)
                    bindText(item.source.rawValue, to: 1, in: statement)
                    bindText(item.filePath, to: 2, in: statement)
                    try stepDone(statement)
                }
            }

            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }

        try rebuildDailyRollups()
        return unknownFiles.count
    }

    public func rebuildDailyRollups() throws {
        struct RollupKey: Hashable {
            let day: String
            let source: AgentSource
        }

        struct RollupValue {
            var costUSD: Decimal = 0
            var eventCount: Int = 0
            var unpricedEventCount: Int = 0
        }

        let sql = """
        SELECT source_id, occurred_at, cost_usd, priced
        FROM costed_usage_events;
        """

        var values: [RollupKey: RollupValue] = [:]

        try withStatement(sql) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                let rawSource = columnText(statement, 0)
                guard let source = AgentSource(rawValue: rawSource) else { continue }
                guard let date = DateFormats.date(from: columnText(statement, 1)) else { continue }

                let day = DateFormats.dayString(from: date)
                let key = RollupKey(day: day, source: source)
                let cost = Decimal(string: columnText(statement, 2)) ?? 0
                let priced = sqlite3_column_int(statement, 3) == 1

                values[key, default: RollupValue()].costUSD += cost
                values[key, default: RollupValue()].eventCount += 1
                values[key, default: RollupValue()].unpricedEventCount += priced ? 0 : 1
            }
        }

        try execute("DELETE FROM daily_rollups;")

        let insertSQL = """
        INSERT INTO daily_rollups (
          day, source_id, cost_usd, event_count, unpriced_event_count, updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?);
        """

        try withStatement(insertSQL) { statement in
            for (key, value) in values {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                bindText(key.day, to: 1, in: statement)
                bindText(key.source.rawValue, to: 2, in: statement)
                bindText("\(value.costUSD.rounded(scale: 8))", to: 3, in: statement)
                sqlite3_bind_int(statement, 4, Int32(value.eventCount))
                sqlite3_bind_int(statement, 5, Int32(value.unpricedEventCount))
                bindText(DateFormats.string(from: Date()), to: 6, in: statement)
                try stepDone(statement)
            }
        }
    }

    public func dashboardSnapshot(trendDays: Int = 14) throws -> DashboardSnapshot {
        let sourceStates = try loadSourceStates()
        let rows = try loadDailyRollupRows()
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let todayKey = DateFormats.dayString(from: today)

        let trendDates = (0..<trendDays).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }.reversed()

        let trend = trendDates.map { date in
            let key = DateFormats.dayString(from: date)
            let dayRows = rows.filter { $0.day == key }
            return DailyCost(
                day: key,
                costUSD: dayRows.reduce(Decimal(0)) { $0 + $1.costUSD }.rounded(scale: 6),
                unpricedEventCount: dayRows.reduce(0) { $0 + $1.unpricedEventCount }
            )
        }

        let todayRows = rows.filter { $0.day == todayKey }
        let todayUSD = todayRows.reduce(Decimal(0)) { $0 + $1.costUSD }.rounded(scale: 6)

        let weekStart = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let weekUSD = rows
            .filter { row in
                guard let date = DateFormats.dayDate(from: row.day) else { return false }
                return date >= weekStart && date <= today
            }
            .reduce(Decimal(0)) { $0 + $1.costUSD }
            .rounded(scale: 6)

        let monthInterval = calendar.dateInterval(of: .month, for: today)
        let monthUSD = rows
            .filter { row in
                guard let date = DateFormats.dayDate(from: row.day) else { return false }
                guard let monthInterval else { return false }
                return monthInterval.contains(date)
            }
            .reduce(Decimal(0)) { $0 + $1.costUSD }
            .rounded(scale: 6)

        let agentTotals = AgentSource.allCases.compactMap { source -> AgentCost? in
            let sourceRows = todayRows.filter { $0.source == source }
            let cost = sourceRows.reduce(Decimal(0)) { $0 + $1.costUSD }.rounded(scale: 6)
            let eventCount = sourceRows.reduce(0) { $0 + $1.eventCount }
            let unpriced = sourceRows.reduce(0) { $0 + $1.unpricedEventCount }
            guard cost > 0 || eventCount > 0 else { return nil }
            return AgentCost(source: source, costUSD: cost, eventCount: eventCount, unpricedEventCount: unpriced)
        }
        .sorted { $0.costUSD > $1.costUSD }

        let unpricedCount = todayRows.reduce(0) { $0 + $1.unpricedEventCount }

        return DashboardSnapshot(
            todayUSD: todayUSD,
            todayCNY: (todayUSD * PriceCatalog.fixedUSDCNYRate).rounded(scale: 6),
            weekUSD: weekUSD,
            weekCNY: (weekUSD * PriceCatalog.fixedUSDCNYRate).rounded(scale: 6),
            monthUSD: monthUSD,
            monthCNY: (monthUSD * PriceCatalog.fixedUSDCNYRate).rounded(scale: 6),
            dailyTrend: trend,
            agentTotals: agentTotals,
            sourceStates: sourceStates,
            unpricedEventCount: unpricedCount,
            lastUpdatedAt: now
        )
    }

    private func loadDailyRollupRows() throws -> [DailyRollupRow] {
        let sql = """
        SELECT day, source_id, cost_usd, event_count, unpriced_event_count
        FROM daily_rollups;
        """

        var rows: [DailyRollupRow] = []

        try withStatement(sql) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let source = AgentSource(rawValue: columnText(statement, 1)) else { continue }
                rows.append(
                    DailyRollupRow(
                        day: columnText(statement, 0),
                        source: source,
                        costUSD: Decimal(string: columnText(statement, 2)) ?? 0,
                        eventCount: Int(sqlite3_column_int(statement, 3)),
                        unpricedEventCount: Int(sqlite3_column_int(statement, 4))
                    )
                )
            }
        }

        return rows
    }

    private func loadUsageEvents() throws -> [UsageEvent] {
        let sql = """
        SELECT id, source_id, occurred_at, model_raw_name, input_tokens,
               cache_creation_input_tokens, cache_creation_input_tokens_1h,
               cache_read_input_tokens, output_tokens, source_file, source_offset
        FROM usage_events;
        """

        var events: [UsageEvent] = []

        try withStatement(sql) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let source = AgentSource(rawValue: columnText(statement, 1)) else { continue }
                guard let occurredAt = DateFormats.date(from: columnText(statement, 2)) else { continue }

                let sourceOffset: Int64?
                if sqlite3_column_type(statement, 10) == SQLITE_NULL {
                    sourceOffset = nil
                } else {
                    sourceOffset = sqlite3_column_int64(statement, 10)
                }

                events.append(
                    UsageEvent(
                        id: columnText(statement, 0),
                        source: source,
                        occurredAt: occurredAt,
                        modelRawName: columnText(statement, 3),
                        inputTokens: Int(sqlite3_column_int(statement, 4)),
                        cacheCreationInputTokens: Int(sqlite3_column_int(statement, 5)),
                        cacheCreationInputTokens1Hour: Int(sqlite3_column_int(statement, 6)),
                        cacheReadInputTokens: Int(sqlite3_column_int(statement, 7)),
                        outputTokens: Int(sqlite3_column_int(statement, 8)),
                        sourceFile: columnText(statement, 9),
                        sourceOffset: sourceOffset
                    )
                )
            }
        }

        return events
    }

    private func loadUnknownModelFiles() throws -> [UnknownModelFile] {
        let sql = """
        SELECT DISTINCT source_id, source_file
        FROM usage_events
        WHERE model_raw_name = 'unknown';
        """

        var files: [UnknownModelFile] = []

        try withStatement(sql) { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let source = AgentSource(rawValue: columnText(statement, 0)) else { continue }
                let filePath = columnText(statement, 1)
                guard !filePath.isEmpty else { continue }
                files.append(UnknownModelFile(source: source, filePath: filePath))
            }
        }

        return files
    }

    private func insertUsageEvent(_ event: UsageEvent) throws -> Bool {
        let sql = """
        INSERT OR IGNORE INTO usage_events (
          id, source_id, occurred_at, model_raw_name, input_tokens,
          cache_creation_input_tokens, cache_creation_input_tokens_1h,
          cache_read_input_tokens, output_tokens, source_file, source_offset, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        try withStatement(sql) { statement in
            bindText(event.id, to: 1, in: statement)
            bindText(event.source.rawValue, to: 2, in: statement)
            bindText(DateFormats.string(from: event.occurredAt), to: 3, in: statement)
            bindText(event.modelRawName, to: 4, in: statement)
            sqlite3_bind_int(statement, 5, Int32(event.inputTokens))
            sqlite3_bind_int(statement, 6, Int32(event.cacheCreationInputTokens))
            sqlite3_bind_int(statement, 7, Int32(event.cacheCreationInputTokens1Hour))
            sqlite3_bind_int(statement, 8, Int32(event.cacheReadInputTokens))
            sqlite3_bind_int(statement, 9, Int32(event.outputTokens))
            bindText(event.sourceFile, to: 10, in: statement)
            if let sourceOffset = event.sourceOffset {
                sqlite3_bind_int64(statement, 11, sourceOffset)
            } else {
                sqlite3_bind_null(statement, 11)
            }
            bindText(DateFormats.string(from: Date()), to: 12, in: statement)
            try stepDone(statement)
        }

        return sqlite3_changes(db) > 0
    }

    private func insertCostedUsageEvent(_ event: CostedUsageEvent) throws {
        let sql = """
        INSERT OR REPLACE INTO costed_usage_events (
          usage_event_id, source_id, occurred_at, cost_usd, priced, pricing_model_key, created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """

        try withStatement(sql) { statement in
            bindText(event.usageEventID, to: 1, in: statement)
            bindText(event.source.rawValue, to: 2, in: statement)
            bindText(DateFormats.string(from: event.occurredAt), to: 3, in: statement)
            bindText("\(event.costUSD.rounded(scale: 8))", to: 4, in: statement)
            sqlite3_bind_int(statement, 5, event.isPriced ? 1 : 0)
            bindText(event.pricingModelKey, to: 6, in: statement)
            bindText(DateFormats.string(from: Date()), to: 7, in: statement)
            try stepDone(statement)
        }
    }

    private func recordUnknownModel(_ event: UsageEvent) throws {
        let sql = """
        INSERT INTO unknown_models (
          model_raw_name, source_id, first_seen_at, last_seen_at, event_count
        )
        VALUES (?, ?, ?, ?, 1)
        ON CONFLICT(model_raw_name, source_id) DO UPDATE SET
          last_seen_at = excluded.last_seen_at,
          event_count = event_count + 1;
        """

        try withStatement(sql) { statement in
            bindText(event.modelRawName, to: 1, in: statement)
            bindText(event.source.rawValue, to: 2, in: statement)
            bindText(DateFormats.string(from: event.occurredAt), to: 3, in: statement)
            bindText(DateFormats.string(from: event.occurredAt), to: 4, in: statement)
            try stepDone(statement)
        }
    }

    private func migrate() throws {
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA foreign_keys = ON;")

        try execute("""
        CREATE TABLE IF NOT EXISTS sources (
          id TEXT PRIMARY KEY,
          source_id TEXT NOT NULL,
          display_name TEXT NOT NULL,
          enabled INTEGER NOT NULL,
          path TEXT,
          status TEXT NOT NULL,
          last_synced_at TEXT,
          message TEXT,
          updated_at TEXT NOT NULL
        );
        """)

        try? execute("ALTER TABLE sources ADD COLUMN source_id TEXT;")
        try execute("UPDATE sources SET source_id = id WHERE source_id IS NULL OR source_id = '';")

        try execute("""
        CREATE TABLE IF NOT EXISTS scan_cursors (
          source_id TEXT NOT NULL,
          file_path TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          file_modified_at TEXT,
          last_offset INTEGER,
          last_event_key TEXT,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (source_id, file_path)
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS usage_events (
          id TEXT PRIMARY KEY,
          source_id TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          model_raw_name TEXT NOT NULL,
          input_tokens INTEGER NOT NULL DEFAULT 0,
          cache_creation_input_tokens INTEGER NOT NULL DEFAULT 0,
          cache_creation_input_tokens_1h INTEGER NOT NULL DEFAULT 0,
          cache_read_input_tokens INTEGER NOT NULL DEFAULT 0,
          output_tokens INTEGER NOT NULL DEFAULT 0,
          source_file TEXT NOT NULL,
          source_offset INTEGER,
          created_at TEXT NOT NULL
        );
        """)

        try addColumnIfMissing(
            table: "usage_events",
            column: "cache_creation_input_tokens_1h",
            definition: "INTEGER NOT NULL DEFAULT 0"
        )

        try execute("""
        CREATE TABLE IF NOT EXISTS costed_usage_events (
          usage_event_id TEXT PRIMARY KEY,
          source_id TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          cost_usd TEXT NOT NULL,
          priced INTEGER NOT NULL,
          pricing_model_key TEXT,
          created_at TEXT NOT NULL
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS daily_rollups (
          day TEXT NOT NULL,
          source_id TEXT NOT NULL,
          cost_usd TEXT NOT NULL,
          event_count INTEGER NOT NULL,
          unpriced_event_count INTEGER NOT NULL,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (day, source_id)
        );
        """)

        try execute("""
        CREATE TABLE IF NOT EXISTS unknown_models (
          model_raw_name TEXT NOT NULL,
          source_id TEXT NOT NULL,
          first_seen_at TEXT NOT NULL,
          last_seen_at TEXT NOT NULL,
          event_count INTEGER NOT NULL,
          PRIMARY KEY (model_raw_name, source_id)
        );
        """)
    }

    private func execute(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw SQLiteStoreError.executionFailed(lastErrorMessage)
        }
    }

    private func addColumnIfMissing(table: String, column: String, definition: String) throws {
        var hasColumn = false

        try withStatement("PRAGMA table_info(\(table));") { statement in
            while sqlite3_step(statement) == SQLITE_ROW {
                if columnText(statement, 1) == column {
                    hasColumn = true
                    break
                }
            }
        }

        guard !hasColumn else { return }
        try execute("ALTER TABLE \(table) ADD COLUMN \(column) \(definition);")
    }

    private func withStatement(_ sql: String, _ body: (OpaquePointer?) throws -> Void) throws {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw SQLiteStoreError.prepareFailed(lastErrorMessage)
        }
        defer { sqlite3_finalize(statement) }
        try body(statement)
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        if sqlite3_step(statement) != SQLITE_DONE {
            throw SQLiteStoreError.executionFailed(lastErrorMessage)
        }
    }

    private func bindText(_ value: String?, to index: Int32, in statement: OpaquePointer?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let text = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: text)
    }

    private func columnOptionalText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return columnText(statement, index)
    }

    private var lastErrorMessage: String {
        guard let db, let message = sqlite3_errmsg(db) else { return "Unknown SQLite error" }
        return String(cString: message)
    }

    private static func defaultApplicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("iCost", isDirectory: true)
        let legacyDirectory = base.appendingPathComponent("TokenCostBar", isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path),
           FileManager.default.fileExists(atPath: legacyDirectory.path) {
            do {
                try FileManager.default.moveItem(at: legacyDirectory, to: directory)
            } catch {
                return legacyDirectory
            }
        }

        return directory
    }
}

private struct DailyRollupRow {
    let day: String
    let source: AgentSource
    let costUSD: Decimal
    let eventCount: Int
    let unpricedEventCount: Int
}

private struct UnknownModelFile {
    let source: AgentSource
    let filePath: String
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
