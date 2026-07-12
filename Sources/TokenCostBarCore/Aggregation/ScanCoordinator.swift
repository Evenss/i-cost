import Foundation

public struct ScanSummary: Sendable {
    public let insertedEventCount: Int
    public let snapshot: DashboardSnapshot

    public init(insertedEventCount: Int, snapshot: DashboardSnapshot) {
        self.insertedEventCount = insertedEventCount
        self.snapshot = snapshot
    }
}

public final class ScanCoordinator: @unchecked Sendable {
    private let store: SQLiteStore
    private let priceCatalog: PriceCatalog
    private let adapters: [UsageSourceAdapter]

    public init(
        store: SQLiteStore,
        priceCatalog: PriceCatalog = PriceCatalog(),
        adapters: [UsageSourceAdapter] = SourceAdapterFactory.defaultAdapters()
    ) {
        self.store = store
        self.priceCatalog = priceCatalog
        self.adapters = adapters
    }

    public func scanAll() throws -> ScanSummary {
        var insertedCount = 0

        try store.deleteSourceStates(excluding: Set(adapters.map(\.stateID)))
        try store.deleteUnknownModelEventsAndResetCursors()

        for adapter in adapters {
            do {
                let cursors = try store.loadCursors(for: adapter.source)
                let output = try adapter.scan(cursors: cursors)

                try store.upsertSourceState(output.state)

                let costedEvents = output.events.map { priceCatalog.cost(for: $0) }
                insertedCount += try store.store(events: output.events, costedEvents: costedEvents)

                for cursor in output.cursors {
                    try store.saveCursor(cursor)
                }
            } catch {
                try store.upsertSourceState(
                    SourceState(
                        id: adapter.stateID,
                        source: adapter.source,
                        displayName: adapter.displayName,
                        status: .error,
                        path: adapter.discover().path,
                        lastSyncedAt: nil,
                        message: error.localizedDescription
                    )
                )
            }
        }

        try store.repriceAllEvents(using: priceCatalog)
        let snapshot = try store.dashboardSnapshot()
        return ScanSummary(insertedEventCount: insertedCount, snapshot: snapshot)
    }

    public func currentSnapshot() throws -> DashboardSnapshot {
        try store.dashboardSnapshot()
    }
}
