import Foundation

public struct RemoteUsageSourceAdapter: UsageSourceAdapter {
    public let stateID: String
    public let source: AgentSource
    public let displayName: String

    private let host: RemoteHostConfiguration
    private let remotePath: String
    private let fileManager: FileManager
    private let cacheRootURL: URL

    public init(
        host: RemoteHostConfiguration,
        source: AgentSource,
        fileManager: FileManager = .default,
        cacheBaseURL: URL? = nil
    ) {
        self.host = host
        self.source = source
        self.fileManager = fileManager
        remotePath = host.remotePath(for: source)
        stateID = "remote:\(host.stableID):\(source.rawValue)"
        displayName = "\(source.displayName) @ \(host.displayName)"

        let defaultCacheBaseURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/iCost/RemoteCaches", isDirectory: true)
        cacheRootURL = (cacheBaseURL ?? defaultCacheBaseURL)
            .appendingPathComponent(host.stableID, isDirectory: true)
            .appendingPathComponent(source.rawValue, isDirectory: true)
    }

    public func discover() -> SourceState {
        guard !host.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return state(status: .error, message: "Remote host is empty.")
        }

        do {
            let result = try runProcess(
                executablePath: "/usr/bin/ssh",
                arguments: sshArguments(command: "if test -d \(remoteShellPath(remotePath)); then printf ready; else printf missing; fi"),
                timeout: TimeInterval(timeoutSeconds + 2)
            )

            guard result.terminationStatus == 0 else {
                return state(status: .error, message: commandFailureMessage(result, commandName: "ssh"))
            }

            if result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "ready" {
                return state(status: .ready)
            }

            return state(status: .missing, message: "Remote log directory was not found.")
        } catch {
            return state(status: .error, message: error.localizedDescription)
        }
    }

    public func scan(cursors: [String: ScanCursor]) throws -> SourceScanOutput {
        let discovered = discover()
        guard discovered.status == .ready else {
            return SourceScanOutput(state: discovered, events: [], cursors: [])
        }

        try synchronizeRemoteDirectory()

        let adapter = localAdapter()
        let output = try adapter.scan(cursors: cursors)

        return SourceScanOutput(
            state: state(status: .ready, lastSyncedAt: Date()),
            events: output.events,
            cursors: output.cursors
        )
    }

    private func localAdapter() -> UsageSourceAdapter {
        switch source {
        case .claudeCode, .codex:
            DefaultJSONLUsageAdapter(
                source: source,
                fileManager: fileManager,
                rootURL: cacheRootURL,
                displayName: displayName,
                stateID: stateID,
                displayPath: displayPath,
                filePathPrefix: remoteIdentityRoot
            )
        case .cursor:
            CursorUsageAdapter(
                fileManager: fileManager,
                rootURL: cacheRootURL,
                displayName: displayName,
                stateID: stateID,
                displayPath: displayPath,
                filePathPrefix: remoteIdentityRoot
            )
        }
    }

    private func synchronizeRemoteDirectory() throws {
        try? fileManager.removeItem(at: cacheRootURL)
        try fileManager.createDirectory(at: cacheRootURL, withIntermediateDirectories: true)

        let remoteSpec = "\(host.target):\(remoteShellPath(remotePath, appending: "."))"
        let result = try runProcess(
            executablePath: "/usr/bin/scp",
            arguments: scpArguments(remoteSpec: remoteSpec, localPath: cacheRootURL.path),
            timeout: max(120, TimeInterval(timeoutSeconds * 6))
        )

        guard result.terminationStatus == 0 else {
            throw RemoteUsageSourceAdapterError.commandFailed(
                command: "scp",
                status: result.terminationStatus,
                message: commandFailureMessage(result, commandName: "scp")
            )
        }
    }

    private func state(
        status: SourceStatus,
        lastSyncedAt: Date? = nil,
        message: String? = nil
    ) -> SourceState {
        SourceState(
            id: stateID,
            source: source,
            displayName: displayName,
            status: status,
            path: displayPath,
            lastSyncedAt: lastSyncedAt,
            message: message
        )
    }

    private var displayPath: String {
        "\(host.target):\(remotePath)"
    }

    private var remoteIdentityRoot: String {
        let separator = remotePath.hasPrefix("/") ? "" : "/"
        return "ssh://\(host.target)\(separator)\(remotePath)"
    }

    private var timeoutSeconds: Int {
        max(1, host.connectTimeoutSeconds ?? 8)
    }

    private func sshArguments(command: String) -> [String] {
        var arguments = baseSSHOptions(portFlag: "-p")
        arguments.append(host.target)
        arguments.append(command)
        return arguments
    }

    private func scpArguments(remoteSpec: String, localPath: String) -> [String] {
        var arguments = ["-O", "-q", "-p", "-r"]
        arguments.append(contentsOf: baseSSHOptions(portFlag: "-P"))
        arguments.append(remoteSpec)
        arguments.append(localPath)
        return arguments
    }

    private func baseSSHOptions(portFlag: String) -> [String] {
        var arguments = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=\(timeoutSeconds)"
        ]

        if let port = host.port, port > 0 {
            arguments.append(contentsOf: [portFlag, "\(port)"])
        }

        if let identityFile = host.identityFile, !identityFile.isEmpty {
            arguments.append(contentsOf: ["-i", expandTilde(identityFile)])
        }

        return arguments
    }

    private func runProcess(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }

        try process.run()

        if completion.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw RemoteUsageSourceAdapterError.timedOut(command: URL(fileURLWithPath: executablePath).lastPathComponent)
        }

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(
            terminationStatus: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }

    private func commandFailureMessage(_ result: CommandResult, commandName: String) -> String {
        let message = [result.stderr, result.stdout]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "No output."
        return "\(commandName) exited \(result.terminationStatus): \(message)"
    }

    private func remoteShellPath(_ path: String, appending child: String? = nil) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let basePath: String

        if trimmedPath == "~" {
            basePath = "~"
        } else if trimmedPath.hasPrefix("~/") {
            let relativePath = String(trimmedPath.dropFirst(2))
            let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
            basePath = "~/" + components.map { shellQuote(String($0)) }.joined(separator: "/")
        } else {
            basePath = shellQuote(trimmedPath)
        }

        if let child {
            return basePath + "/" + shellQuote(child)
        }

        return basePath
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func expandTilde(_ path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        return fileManager.homeDirectoryForCurrentUser.path + String(path.dropFirst())
    }
}

private struct CommandResult {
    let terminationStatus: Int32
    let stdout: String
    let stderr: String
}

private enum RemoteUsageSourceAdapterError: LocalizedError {
    case commandFailed(command: String, status: Int32, message: String)
    case timedOut(command: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(_, _, let message):
            message
        case .timedOut(let command):
            "\(command) timed out."
        }
    }
}
