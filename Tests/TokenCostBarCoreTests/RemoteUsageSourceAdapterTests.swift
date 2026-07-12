import Foundation
import Testing
@testable import TokenCostBarCore

struct RemoteUsageSourceAdapterTests {
    @Test
    func testModernSCPArgumentsDoNotForceLegacyProtocol() {
        let host = RemoteHostConfiguration(
            host: "dev.example.com",
            user: "even",
            port: 2222,
            identityFile: "~/.ssh/id_ed25519"
        )
        let adapter = RemoteUsageSourceAdapter(host: host, source: .claudeCode)
        let remoteSpec = "even@dev.example.com:~/.claude/projects/."
        let arguments = adapter.scpArguments(remoteSpec: remoteSpec, localPath: "/tmp/cache")

        #expect(!arguments.contains("-O"))
        #expect(arguments.contains("-r"))
        #expect(arguments.contains("-P"))
        #expect(arguments.contains("2222"))
        #expect(arguments.contains(remoteSpec))
        #expect(arguments.last == "/tmp/cache")
    }

    @Test
    func testRemoteCopyPathIsNotShellQuoted() {
        let adapter = RemoteUsageSourceAdapter(
            host: RemoteHostConfiguration(host: "dev.example.com"),
            source: .cursor
        )

        #expect(adapter.remoteCopyPath("~/.claude/projects") == "~/.claude/projects/.")
        #expect(
            adapter.remoteCopyPath("~/Library/Application Support/Cursor/User/")
                == "~/Library/Application Support/Cursor/User/."
        )
    }
}
