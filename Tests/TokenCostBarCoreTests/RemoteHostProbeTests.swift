import Foundation
import Testing
@testable import TokenCostBarCore

struct RemoteHostProbeTests {
    @Test
    func testUsesSystemSSHDefaultsWhenOptionalFieldsAreMissing() {
        let probe = RemoteHostProbe(
            host: RemoteHostConfiguration(host: "workstation")
        )

        let arguments = probe.sshArguments(command: "printf ready")

        #expect(arguments.contains("BatchMode=yes"))
        #expect(arguments.contains("StrictHostKeyChecking=accept-new"))
        #expect(arguments.contains("ConnectTimeout=8"))
        #expect(arguments.suffix(2) == ["workstation", "printf ready"])
        #expect(!arguments.contains("-p"))
        #expect(!arguments.contains("-i"))
    }

    @Test
    func testAddsOnlyExplicitConnectionSupplements() {
        let probe = RemoteHostProbe(
            host: RemoteHostConfiguration(
                host: "workstation",
                user: "ubuntu",
                port: 2222,
                identityFile: "~/.ssh/workstation",
                connectTimeoutSeconds: 12
            )
        )

        let arguments = probe.sshArguments(command: "printf ready")

        #expect(arguments.contains("ConnectTimeout=12"))
        #expect(arguments.contains("-p"))
        #expect(arguments.contains("2222"))
        #expect(arguments.contains("-i"))
        #expect(arguments.contains(FileManager.default.homeDirectoryForCurrentUser.path + "/.ssh/workstation"))
        #expect(arguments.suffix(2) == ["ubuntu@workstation", "printf ready"])
    }
}
