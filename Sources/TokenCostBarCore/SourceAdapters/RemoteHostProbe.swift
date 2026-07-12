import Foundation

public struct RemoteHostProbeResult: Sendable {
    public let isConnected: Bool
    public let detectedSources: [AgentSource]
    public let diagnostic: String?

    public init(
        isConnected: Bool,
        detectedSources: [AgentSource] = [],
        diagnostic: String? = nil
    ) {
        self.isConnected = isConnected
        self.detectedSources = detectedSources
        self.diagnostic = diagnostic
    }
}

public struct RemoteHostProbe: Sendable {
    private let host: RemoteHostConfiguration

    public init(host: RemoteHostConfiguration) {
        self.host = host
    }

    public func run() -> RemoteHostProbeResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = sshArguments(command: probeCommand)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let completion = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in completion.signal() }

        do {
            try process.run()
        } catch {
            return RemoteHostProbeResult(isConnected: false, diagnostic: error.localizedDescription)
        }

        if completion.wait(timeout: .now() + TimeInterval(timeoutSeconds + 2)) == .timedOut {
            process.terminate()
            return RemoteHostProbeResult(isConnected: false, diagnostic: "ssh timed out.")
        }

        let stdout = String(
            data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        let stderr = String(
            data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""

        guard process.terminationStatus == 0, stdout.contains(Self.connectedMarker) else {
            let diagnostic = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return RemoteHostProbeResult(
                isConnected: false,
                diagnostic: diagnostic.isEmpty ? "ssh exited \(process.terminationStatus)." : diagnostic
            )
        }

        let detectedSources = AgentSource.allCases.filter { source in
            stdout.contains(Self.sourceMarker(for: source))
        }
        return RemoteHostProbeResult(isConnected: true, detectedSources: detectedSources)
    }

    func sshArguments(command: String) -> [String] {
        var arguments = [
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "ConnectTimeout=\(timeoutSeconds)"
        ]

        if let port = host.port, port > 0 {
            arguments.append(contentsOf: ["-p", "\(port)"])
        }

        if let identityFile = host.identityFile, !identityFile.isEmpty {
            arguments.append(contentsOf: ["-i", expandTilde(identityFile)])
        }

        arguments.append(host.target)
        arguments.append(command)
        return arguments
    }

    private var probeCommand: String {
        var commands = ["printf '\(Self.connectedMarker)\\n'"]
        for source in AgentSource.allCases {
            let path = remoteShellPath(host.remotePath(for: source))
            commands.append(
                "if test -d \(path); then printf '\(Self.sourceMarker(for: source))\\n'; fi"
            )
        }
        return commands.joined(separator: "; ")
    }

    private var timeoutSeconds: Int {
        max(1, host.connectTimeoutSeconds ?? 8)
    }

    private func remoteShellPath(_ path: String) -> String {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath == "~" {
            return "~"
        }
        if trimmedPath.hasPrefix("~/") {
            let relativePath = String(trimmedPath.dropFirst(2))
            let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
            return "~/" + components.map { shellQuote(String($0)) }.joined(separator: "/")
        }
        return shellQuote(trimmedPath)
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func expandTilde(_ path: String) -> String {
        guard path == "~" || path.hasPrefix("~/") else { return path }
        return FileManager.default.homeDirectoryForCurrentUser.path + String(path.dropFirst())
    }

    private static let connectedMarker = "__ICOST_CONNECTED__"

    private static func sourceMarker(for source: AgentSource) -> String {
        "__ICOST_SOURCE__:\(source.rawValue)"
    }
}
