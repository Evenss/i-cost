import Foundation
import SQLite3
import Testing
@testable import TokenCostBarCore

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct CursorUsageAdapterTests {
    @Test
    func testReadsTokenUsageFromCursorStateDatabase() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspaceDirectory = home
            .appendingPathComponent("Library/Application Support/Cursor/User/workspaceStorage/example", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }

        let databaseURL = workspaceDirectory.appendingPathComponent("state.vscdb")
        try createCursorStateDatabase(
            at: databaseURL,
            key: "composerData",
            value: """
            {"createdAt":"2026-06-30T10:00:00Z","model":"claude-sonnet-4-5","usage":{"input_tokens":1200,"cache_read_input_tokens":300,"output_tokens":400}}
            """
        )

        let adapter = CursorUsageAdapter(homeDirectory: home)
        let output = try adapter.scan(cursors: [:])

        #expect(output.state.status == .ready)
        #expect(output.state.source == .cursor)
        #expect(output.events.count == 1)
        #expect(output.events.first?.source == .cursor)
        #expect(output.events.first?.modelRawName == "claude-sonnet-4-5")
        #expect(output.events.first?.inputTokens == 1200)
        #expect(output.events.first?.cacheReadInputTokens == 300)
        #expect(output.events.first?.outputTokens == 400)
        #expect(output.cursors.count == 1)
    }

    private func createCursorStateDatabase(at url: URL, key: String, value: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK else {
            throw SQLiteStoreError.openFailed("Could not create test database")
        }
        defer { sqlite3_close(database) }

        try execute("CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value BLOB);", in: database)

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "INSERT INTO ItemTable (key, value) VALUES (?, ?);", -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteStoreError.prepareFailed("Could not prepare insert")
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, key, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, value, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteStoreError.executionFailed("Could not insert value")
        }
    }

    private func execute(_ sql: String, in database: OpaquePointer?) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            throw SQLiteStoreError.executionFailed(message)
        }
    }
}
