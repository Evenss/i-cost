import Foundation

public struct DefaultJSONLUsageAdapter: UsageSourceAdapter {
    public let stateID: String
    public let source: AgentSource
    public let displayName: String

    private let fileManager: FileManager
    private let rootURL: URL
    private let displayPath: String?
    private let filePathPrefix: String?
    private let extractor: JSONUsageExtractor

    public init(
        source: AgentSource,
        fileManager: FileManager = .default,
        homeDirectory: URL? = nil,
        rootURL: URL? = nil,
        displayName: String? = nil,
        stateID: String? = nil,
        displayPath: String? = nil,
        filePathPrefix: String? = nil
    ) {
        self.source = source
        self.displayName = displayName ?? source.displayName
        self.stateID = stateID ?? source.rawValue
        self.fileManager = fileManager
        self.displayPath = displayPath
        self.filePathPrefix = filePathPrefix
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        self.rootURL = rootURL ?? home.appendingPathComponent(source.defaultRelativePath)
        extractor = JSONUsageExtractor(source: source)
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
                message: "Default log directory was not found."
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

        let files = usageFiles()
        var events: [UsageEvent] = []
        var updatedCursors: [ScanCursor] = []

        for fileURL in files {
            let filePath = identityPath(for: fileURL)
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let modifiedAt = attributes[.modificationDate] as? Date
            let existingCursor = cursors[filePath]
            let startOffset = existingCursor.flatMap { $0.fileSize <= fileSize ? $0.lastOffset : 0 } ?? 0

            let fileEvents = try scanFile(
                fileURL,
                eventFilePath: filePath,
                startOffset: startOffset,
                fallbackDate: modifiedAt ?? Date()
            )

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

    private func scanFile(
        _ fileURL: URL,
        eventFilePath: String,
        startOffset: Int64,
        fallbackDate: Date
    ) throws -> [UsageEvent] {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        try fileHandle.seek(toOffset: UInt64(max(0, startOffset)))
        let data = try fileHandle.readToEnd() ?? Data()
        guard !data.isEmpty else { return [] }

        if fileURL.pathExtension.lowercased() == "json" {
            return parseJSONDocument(data, filePath: eventFilePath, offset: startOffset, fallbackDate: fallbackDate)
        }

        return parseJSONLines(
            data,
            fileURL: fileURL,
            filePath: eventFilePath,
            startOffset: startOffset,
            fallbackDate: fallbackDate
        )
    }

    private func parseJSONLines(
        _ data: Data,
        fileURL: URL,
        filePath: String,
        startOffset: Int64,
        fallbackDate: Date
    ) -> [UsageEvent] {
        var events: [UsageEvent] = []
        var lineStart = 0
        var lineOffset = startOffset
        var currentModel = startOffset > 0 ? lastModelBeforeOffset(fileURL: fileURL, offset: startOffset) : nil

        for index in 0...data.count {
            let isEnd = index == data.count
            let isNewline = !isEnd && data[index] == 10
            guard isEnd || isNewline else { continue }

            if index > lineStart {
                let lineData = data[lineStart..<index]
                if let line = String(data: lineData, encoding: .utf8),
                   let object = extractor.jsonObject(fromJSONLine: line) {
                    if let model = extractor.modelName(in: object) {
                        currentModel = model
                    }

                    events.append(
                        contentsOf: extractor.events(
                            fromJSONObject: object,
                            filePath: filePath,
                            offset: lineOffset,
                            fallbackDate: fallbackDate,
                            modelOverride: currentModel
                        )
                    )
                }
            }

            lineOffset += Int64(index - lineStart + 1)
            lineStart = index + 1
        }

        return events
    }

    private func lastModelBeforeOffset(fileURL: URL, offset: Int64) -> String? {
        guard offset > 0,
              let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            return nil
        }
        defer { try? fileHandle.close() }

        let data = (try? fileHandle.read(upToCount: Int(offset))) ?? Data()
        guard !data.isEmpty else { return nil }

        var lineStart = 0
        var model: String?

        for index in 0...data.count {
            let isEnd = index == data.count
            let isNewline = !isEnd && data[index] == 10
            guard isEnd || isNewline else { continue }

            if index > lineStart {
                let lineData = data[lineStart..<index]
                if let line = String(data: lineData, encoding: .utf8),
                   let object = extractor.jsonObject(fromJSONLine: line),
                   let candidate = extractor.modelName(in: object) {
                    model = candidate
                }
            }

            lineStart = index + 1
        }

        return model
    }

    private func parseJSONDocument(
        _ data: Data,
        filePath: String,
        offset: Int64,
        fallbackDate: Date
    ) -> [UsageEvent] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        return extractor.events(fromJSONObject: object, filePath: filePath, offset: offset, fallbackDate: fallbackDate)
    }

    private func usageFiles() -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [URL] = []

        for case let url as URL in enumerator {
            guard ["jsonl", "json"].contains(url.pathExtension.lowercased()) else { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            files.append(url)
        }

        return files.sorted { $0.path < $1.path }
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
