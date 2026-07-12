import Foundation
import TokenCostBarCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot
    @Published private(set) var remoteConfiguration: RemoteSourcesConfiguration
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var remoteConfigurationError: String?

    private let store: SQLiteStore?
    private var coordinator: ScanCoordinator?
    private var refreshTimer: Timer?

    init(coordinator: ScanCoordinator) {
        store = nil
        self.coordinator = coordinator
        remoteConfiguration = (try? RemoteSourcesConfiguration.loadDefault()) ?? RemoteSourcesConfiguration()
        snapshot = (try? coordinator.currentSnapshot()) ?? .empty
    }

    init(store: SQLiteStore) {
        self.store = store
        let configuration = (try? RemoteSourcesConfiguration.loadDefault()) ?? RemoteSourcesConfiguration()
        remoteConfiguration = configuration
        coordinator = ScanCoordinator(
            store: store,
            adapters: SourceAdapterFactory.localAdapters()
                + SourceAdapterFactory.remoteAdapters(configuration: configuration)
        )
        snapshot = (try? coordinator?.currentSnapshot()) ?? .empty
    }

    init(errorMessage: String) {
        store = nil
        coordinator = nil
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
        guard !isRefreshing else { return }

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
        }
    }

    func saveRemoteConfiguration(_ configuration: RemoteSourcesConfiguration) {
        do {
            try configuration.saveDefault()
            remoteConfiguration = configuration
            remoteConfigurationError = nil

            if let store {
                coordinator = ScanCoordinator(
                    store: store,
                    adapters: SourceAdapterFactory.localAdapters()
                        + SourceAdapterFactory.remoteAdapters(configuration: configuration)
                )
            }

            refresh()
        } catch {
            remoteConfigurationError = error.localizedDescription
            lastErrorMessage = error.localizedDescription
        }
    }

    func probeRemoteHost(_ host: RemoteHostConfiguration) async -> RemoteHostProbeResult {
        await Task.detached(priority: .userInitiated) {
            RemoteHostProbe(host: host).run()
        }.value
    }
}
