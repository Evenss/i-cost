import Foundation

public struct DailyCost: Identifiable, Codable, Equatable, Sendable {
    public var id: String { day }

    public let day: String
    public let costUSD: Decimal
    public let unpricedEventCount: Int

    public init(day: String, costUSD: Decimal, unpricedEventCount: Int = 0) {
        self.day = day
        self.costUSD = costUSD
        self.unpricedEventCount = unpricedEventCount
    }
}

public struct AgentCost: Identifiable, Codable, Equatable, Sendable {
    public var id: String { source.rawValue }

    public let source: AgentSource
    public let costUSD: Decimal
    public let eventCount: Int
    public let unpricedEventCount: Int

    public init(
        source: AgentSource,
        costUSD: Decimal,
        eventCount: Int,
        unpricedEventCount: Int = 0
    ) {
        self.source = source
        self.costUSD = costUSD
        self.eventCount = eventCount
        self.unpricedEventCount = unpricedEventCount
    }
}

public struct DashboardSnapshot: Codable, Equatable, Sendable {
    public let todayUSD: Decimal
    public let todayCNY: Decimal
    public let weekUSD: Decimal
    public let weekCNY: Decimal
    public let monthUSD: Decimal
    public let monthCNY: Decimal
    public let dailyTrend: [DailyCost]
    public let agentTotals: [AgentCost]
    public let sourceStates: [SourceState]
    public let unpricedEventCount: Int
    public let lastUpdatedAt: Date

    public init(
        todayUSD: Decimal,
        todayCNY: Decimal,
        weekUSD: Decimal,
        weekCNY: Decimal,
        monthUSD: Decimal,
        monthCNY: Decimal,
        dailyTrend: [DailyCost],
        agentTotals: [AgentCost],
        sourceStates: [SourceState],
        unpricedEventCount: Int,
        lastUpdatedAt: Date
    ) {
        self.todayUSD = todayUSD
        self.todayCNY = todayCNY
        self.weekUSD = weekUSD
        self.weekCNY = weekCNY
        self.monthUSD = monthUSD
        self.monthCNY = monthCNY
        self.dailyTrend = dailyTrend
        self.agentTotals = agentTotals
        self.sourceStates = sourceStates
        self.unpricedEventCount = unpricedEventCount
        self.lastUpdatedAt = lastUpdatedAt
    }

    public static var empty: DashboardSnapshot {
        DashboardSnapshot(
            todayUSD: 0,
            todayCNY: 0,
            weekUSD: 0,
            weekCNY: 0,
            monthUSD: 0,
            monthCNY: 0,
            dailyTrend: [],
            agentTotals: [],
            sourceStates: [],
            unpricedEventCount: 0,
            lastUpdatedAt: Date()
        )
    }
}
