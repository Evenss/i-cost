import Foundation
import SQLite3

public struct CursorUsageAdapter: UsageSourceAdapter {
    public let stateID: String
    public let source: AgentSource = .cursor
    public let displayName: String

    private let fileManager: FileManager
    private let rootURL: URL
    private let displayPath: String?
    private let filePathPrefix: String?
    private let extractor: JSONUsageExtractor

    public init(
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil,
        rootURL: URL? = nil,
        displayName: String? = nil,
        stateID: String? = nil,
        displayPath: String? = nil,
        filePathPrefix: String? = nil
    ) {
        self.displayName = displayName ?? AgentSource.cursor.displayName
        self.stateID = stateID ?? AgentSource.cursor.rawValue
        self.fileManager = fileManager
        self.displayPath = displayPath
        self.filePathPrefix = filePathPrefix
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.rootURL = rootURL ?? home.appendingPathComponent(AgentSource.cursor.defaultRelativePath)
        extractor = JSONUsageExtractor(source: .cursor)
    }

    public func discover() -> SourceState {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return SourceState(
                id: stateID,
                source: source,
                displayName: displayName,
                status: .missing,
                path: displayPath ?? abbreviate(rootURL),
                message: "Cursor data directory was not found."
            )
        }

        return SourceState(
            id: stateID,
            source: source,
            displayName: displayName,
            status: .ready,
            path: displayPath ?? abbreviate(rootURL)
        )
    }

    public func scan(cursors: [String: ScanCursor]) throws -> SourceScanOutput {
        let discovered = discover()
        guard discovered.status == .ready else {
            return SourceScanOutput(state: discovered, events: [], cursors: [])
        }

        let databases = stateDatabaseFiles()
        var events: [UsageEvent] = []
        var updatedCursors: [ScanCursor] = []

        for databaseURL in databases {
            let filePath = identityPath(for: databaseURL)
            let attributes = try fileManager.attributesOfItem(atPath: databaseURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let modifiedAt = attributes[.modificationDate] as? Date
            let fileEvents = try scanDatabase(
                databaseURL,
                identityFilePath: filePath,
                fallbackDate: modifiedAt ?? Date()
            )
            let existingCursor = cursors[filePath]

            events.append(contentsOf: fileEvents)
            updatedCursors.append(
                ScanCursor(
                    source: source,
                    filePath: filePath,
                    fileSize: fileSize,
                    fileModifiedAt: modifiedAt,
                    lastOffset: fileSize,
                    lastEventKey: fileEvents.last?.id ?? existingCursor?.lastEventKey,
                    updatedAt: Date()
                )
            )
        }

        let syncedState = SourceState(
            id: stateID,
            source: source,
            displayName: displayName,
            status: .ready,
            path: displayPath ?? abbreviate(rootURL),
            lastSyncedAt: Date()
        )

        return SourceScanOutput(state: syncedState, events: events, cursors: updatedCursors)
    }

    private func stateDatabaseFiles() -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            guard url.lastPathComponent == "state.vscdb" else { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            files.append(url)
        }

        return files.sorted { $0.path < $1.path }
    }

    private func scanDatabase(_ databaseURL: URL, identityFilePath: String, fallbackDate: Date) throws -> [UsageEvent] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = database.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_close(database)
            throw SQLiteStoreError.openFailed(message)
        }
        defer { sqlite3_close(database) }

        sqlite3_busy_timeout(database, 250)

        let sql = "SELECT key, value FROM ItemTable ORDER BY key;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        var events: [UsageEvent] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let keyPointer = sqlite3_column_text(statement, 0) else { continue }
            let key = String(cString: keyPointer)
            guard let object = jsonObjectFromValueColumn(statement, column: 1) else { continue }

            events.append(
                contentsOf: extractor.events(
                    fromJSONObject: object,
                    filePath: identityFilePath,
                    offset: nil,
                    fallbackDate: fallbackDate,
                    stableIDSeed: "\(identityFilePath):\(key)"
                )
            )
        }

        return events
    }

    private func jsonObjectFromValueColumn(_ statement: OpaquePointer?, column: Int32) -> Any? {
        let byteCount = Int(sqlite3_column_bytes(statement, column))
        guard byteCount > 0, let bytes = sqlite3_column_blob(statement, column) else {
            return nil
        }

        let data = Data(bytes: bytes, count: byteCount)
        return jsonObject(from: data)
    }

    private func jsonObject(from data: Data) -> Any? {
        guard let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return jsonObject(from: string, depth: 0)
    }

    private func jsonObject(from string: String, depth: Int) -> Any? {
        guard depth < 3 else { return nil }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "{" || trimmed.first == "[" || trimmed.first == "\"" else {
            return nil
        }

        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let nestedString = object as? String {
            return jsonObject(from: nestedString, depth: depth + 1)
        }

        return object
    }

    private func abbreviate(_ url: URL) -> String {
        let home = fileManager.homeDirectoryForCurrentUser.path
        guard url.path.hasPrefix(home) else { return url.path }
        return "~" + url.path.dropFirst(home.count)
    }

    private func identityPath(for fileURL: URL) -> String {
        guard let filePathPrefix else { return fileURL.path }

        let rootPath = rootURL.standardizedFileURL.path
        let filePath = fileURL.standardizedFileURL.path
        guard filePath == rootPath || filePath.hasPrefix(rootPath + "/") else {
            return filePath
        }

        let relativePath = String(filePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relativePath.isEmpty else { return filePathPrefix }
        return filePathPrefix + "/" + relativePath
    }
}
