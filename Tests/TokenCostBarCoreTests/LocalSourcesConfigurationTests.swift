import Foundation
import Testing
@testable import TokenCostBarCore

struct LocalSourcesConfigurationTests {
    @Test
    func testDefaultsToAllLocalSourcesWhenConfigurationIsMissing() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configuration = try LocalSourcesConfiguration.loadDefault(
            environment: ["I_COST_LOCAL_SOURCES": directory.appendingPathComponent("missing.json").path]
        )

        #expect(configuration.sources == AgentSource.allCases)
    }

    @Test
    func testPersistsAnEmptyLocalSourceSelection() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let configURL = directory.appendingPathComponent("local-sources.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        try LocalSourcesConfiguration(sources: []).save(to: configURL)
        let configuration = try LocalSourcesConfiguration.loadDefault(
            environment: ["I_COST_LOCAL_SOURCES": configURL.path]
        )

        #expect(configuration.sources.isEmpty)
        #expect(SourceAdapterFactory.localAdapters(configuration: configuration).isEmpty)
    }

    @Test
    func testRemovingOneLocalSourceFiltersFactoryAdapters() {
        let configuration = LocalSourcesConfiguration().removing(.codex)
        let adapters = SourceAdapterFactory.localAdapters(configuration: configuration)

        #expect(configuration.sources == [.claudeCode, .cursor])
        #expect(adapters.map(\.source) == [.claudeCode, .cursor])
    }
}
