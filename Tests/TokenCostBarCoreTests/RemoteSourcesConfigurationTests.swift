import Foundation
import Testing
@testable import TokenCostBarCore

struct RemoteSourcesConfigurationTests {
    @Test
    func testLoadsConfiguredRemoteHostsFromEnvironmentPath() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configURL = directory.appendingPathComponent("remote-sources.json")
        try """
        {
          "hosts": [
            {
              "id": "buildbox",
              "host": "buildbox.example.com",
              "user": "even",
              "port": 2222,
              "identityFile": "~/.ssh/id_ed25519",
              "sources": ["codex", "claude_code"],
              "paths": {
                "codex": "~/.codex/sessions-custom"
              }
            }
          ]
        }
        """.write(to: configURL, atomically: true, encoding: .utf8)

        let configuration = try RemoteSourcesConfiguration.loadDefault(
            environment: ["I_COST_REMOTE_SOURCES": configURL.path]
        )

        #expect(configuration.hosts.count == 1)
        #expect(configuration.hosts.first?.displayName == "buildbox")
        #expect(configuration.hosts.first?.enabledSources == [.codex, .claudeCode])
        #expect(configuration.hosts.first?.remotePath(for: .codex) == "~/.codex/sessions-custom")
        #expect(configuration.hosts.first?.remotePath(for: .claudeCode) == "~/.claude/projects")
    }

    @Test
    func testRemovingRemoteChannelKeepsOtherChannelsOnHost() {
        let host = RemoteHostConfiguration(
            id: "development",
            host: "dev.example.com",
            sources: [.claudeCode, .codex]
        )
        let configuration = RemoteSourcesConfiguration(hosts: [host])
        let stateID = "remote:\(host.stableID):codex"

        let updated = configuration.removing(source: .codex, stateID: stateID)

        #expect(updated.hosts.count == 1)
        #expect(updated.hosts.first?.enabledSources == [.claudeCode])
    }

    @Test
    func testRemovingLastRemoteChannelAlsoRemovesHost() {
        let host = RemoteHostConfiguration(
            id: "development",
            host: "dev.example.com",
            sources: [.codex]
        )
        let configuration = RemoteSourcesConfiguration(hosts: [host])
        let stateID = "remote:\(host.stableID):codex"

        let updated = configuration.removing(source: .codex, stateID: stateID)

        #expect(updated.hosts.isEmpty)
    }
}
