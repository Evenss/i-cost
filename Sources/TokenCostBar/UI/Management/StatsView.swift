import SwiftUI

struct StatsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x4) {
            sectionHeader
            metricPanel
            trendPanel
            agentsPanel
            unpricedNotice

            Spacer(minLength: 0)
        }
    }

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x1) {
            Text("Stats")
                .font(Geist.Fonts.heading16)
                .foregroundStyle(Geist.Colors.primary)

            Text("Today, week, month, and agent-level spend.")
                .font(Geist.Fonts.label13)
                .foregroundStyle(Geist.Colors.secondary)
        }
    }

    private var metricPanel: some View {
        VStack(spacing: 0) {
            MetricLine(title: "Today", usd: model.snapshot.todayUSD, cny: model.snapshot.todayCNY)

            Divider()
                .overlay(Geist.Colors.separator)

            MetricLine(title: "This Week", usd: model.snapshot.weekUSD, cny: model.snapshot.weekCNY)

            Divider()
                .overlay(Geist.Colors.separator)

            MetricLine(title: "This Month", usd: model.snapshot.monthUSD, cny: model.snapshot.monthCNY)
        }
        .padding(.horizontal, Geist.Spacing.x4)
        .geistPanel(padding: 0, radius: Geist.Radius.medium)
    }

    private var trendPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x3) {
            DailyTrendView(days: model.snapshot.dailyTrend)
                .frame(height: 180)
        }
        .geistPanel(padding: Geist.Spacing.x4, radius: Geist.Radius.medium)
    }

    private var agentsPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x3) {
            HStack {
                Text("Agents")
                    .font(Geist.Fonts.heading14)
                    .foregroundStyle(Geist.Colors.primary)

                Spacer()

                Text("\(model.snapshot.agentTotals.count)")
                    .font(Geist.Fonts.mono12)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            if model.snapshot.agentTotals.isEmpty {
                Text("No usage today")
                    .font(Geist.Fonts.label14)
                    .foregroundStyle(Geist.Colors.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Geist.Spacing.x2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.snapshot.agentTotals.enumerated()), id: \.element.id) { index, agent in
                        AgentCostRow(agent: agent)

                        if index < model.snapshot.agentTotals.count - 1 {
                            Divider()
                                .overlay(Geist.Colors.separator)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
            }
        }
        .geistPanel(padding: Geist.Spacing.x4, radius: Geist.Radius.medium)
    }

    @ViewBuilder
    private var unpricedNotice: some View {
        if model.snapshot.unpricedEventCount > 0 {
            HStack(spacing: Geist.Spacing.x2) {
                Image(systemName: "exclamationmark.triangle")
                Text("Some usage could not be priced")
            }
            .font(Geist.Fonts.label12)
            .foregroundStyle(Geist.Colors.amber)
            .padding(Geist.Spacing.x3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Geist.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                    .stroke(Geist.Colors.border, lineWidth: 1)
            )
        }
    }
}
