import Foundation
import TokenCostBarCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastErrorMessage: String?

    private let coordinator: ScanCoordinator?
    private var refreshTimer: Timer?

    init(coordinator: ScanCoordinator) {
        self.coordinator = coordinator
        snapshot = (try? coordinator.currentSnapshot()) ?? .empty
    }

    init(errorMessage: String) {
        coordinator = nil
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

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let summary = try coordinator.scanAll()
            snapshot = summary.snapshot
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
