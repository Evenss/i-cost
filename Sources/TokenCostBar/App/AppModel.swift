import Foundation
import TokenCostBarCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot
    @Published private(set) var localConfiguration: LocalSourcesConfiguration
    @Published private(set) var remoteConfiguration: RemoteSourcesConfiguration
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var remoteConfigurationError: String?

    private let store: SQLiteStore?
    private var coordinator: ScanCoordinator?
    private var refreshTimer: Timer?
    private var refreshRequested = false

    init(coordinator: ScanCoordinator) {
        store = nil
        self.coordinator = coordinator
        localConfiguration = (try? LocalSourcesConfiguration.loadDefault()) ?? LocalSourcesConfiguration()
        remoteConfiguration = (try? RemoteSourcesConfiguration.loadDefault()) ?? RemoteSourcesConfiguration()
        snapshot = (try? coordinator.currentSnapshot()) ?? .empty
    }

    init(store: SQLiteStore) {
        self.store = store
        let localConfiguration = (try? LocalSourcesConfiguration.loadDefault()) ?? LocalSourcesConfiguration()
        let remoteConfiguration = (try? RemoteSourcesConfiguration.loadDefault()) ?? RemoteSourcesConfiguration()
        self.localConfiguration = localConfiguration
        self.remoteConfiguration = remoteConfiguration
        coordinator = ScanCoordinator(
            store: store,
            adapters: SourceAdapterFactory.localAdapters(configuration: localConfiguration)
                + SourceAdapterFactory.remoteAdapters(configuration: remoteConfiguration)
        )
        snapshot = (try? coordinator?.currentSnapshot()) ?? .empty
    }

    init(errorMessage: String) {
        store = nil
        coordinator = nil
        localConfiguration = LocalSourcesConfiguration()
        remoteConfiguration = RemoteSourcesConfiguration()
        snapshot = .empty
        lastErrorMessage = errorMessage
    }

    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func refresh() {
        guard let coordinator else { return }
        guard !isRefreshing else {
            refreshRequested = true
            return
        }

        let startedAt = Date()
        isRefreshing = true

        Task { [weak self, coordinator] in
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    try coordinator.scanAll()
                }.value

                self?.snapshot = summary.snapshot
                self?.lastErrorMessage = nil
            } catch {
                self?.lastErrorMessage = error.localizedDescription
            }

            let remainingRefreshTime = 0.7 - Date().timeIntervalSince(startedAt)
            if remainingRefreshTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingRefreshTime * 1_000_000_000))
            }

            self?.isRefreshing = false
            if self?.refreshRequested == true {
                self?.refreshRequested = false
                self?.refresh()
            }
        }
    }

    func saveRemoteConfiguration(_ configuration: RemoteSourcesConfiguration) {
        do {
            try configuration.saveDefault()
            remoteConfiguration = configuration
            remoteConfigurationError = nil
            rebuildCoordinator()
            refresh()
        } catch {
            remoteConfigurationError = error.localizedDescription
            lastErrorMessage = error.localizedDescription
        }
    }

    func removeSource(_ source: SourceState) {
        do {
            if source.id.hasPrefix("remote:") {
                let configuration = remoteConfiguration.removing(
                    source: source.source,
                    stateID: source.id
                )
                try configuration.saveDefault()
                remoteConfiguration = configuration
                remoteConfigurationError = nil
            } else {
                let configuration = localConfiguration.removing(source.source)
                try configuration.saveDefault()
                localConfiguration = configuration
            }

            rebuildCoordinator()
            try store?.deleteSourceState(id: source.id)
            if let store {
                snapshot = try store.dashboardSnapshot()
            }
            lastErrorMessage = nil
        } catch {
            if source.id.hasPrefix("remote:") {
                remoteConfigurationError = error.localizedDescription
            }
            lastErrorMessage = error.localizedDescription
        }
    }

    func probeRemoteHost(_ host: RemoteHostConfiguration) async -> RemoteHostProbeResult {
        await Task.detached(priority: .userInitiated) {
            RemoteHostProbe(host: host).run()
        }.value
    }

    private func rebuildCoordinator() {
        guard let store else { return }
        coordinator = ScanCoordinator(
            store: store,
            adapters: SourceAdapterFactory.localAdapters(configuration: localConfiguration)
                + SourceAdapterFactory.remoteAdapters(configuration: remoteConfiguration)
        )
    }
}
