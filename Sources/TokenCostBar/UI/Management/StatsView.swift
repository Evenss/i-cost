import SwiftUI

struct StatsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader
            metricPanel
            trendPanel
            agentsPanel
            unpricedNotice
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("统计")
                    .font(Geist.Fonts.heading16)
                    .foregroundStyle(Geist.Colors.primary)

                Text("今天、本周、本月与 AI Agent 花费排行。")
                    .font(Geist.Fonts.label13)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            Spacer()

            Button {
                model.refresh()
            } label: {
                RefreshButtonLabel(isRefreshing: model.isRefreshing)
            }
            .buttonStyle(GeistButtonStyle(kind: .secondary, height: 32))
        }
    }

    private var metricPanel: some View {
        VStack(spacing: 0) {
            MetricLine(title: "今日", usd: model.snapshot.todayUSD, cny: model.snapshot.todayCNY)

            Divider()
                .overlay(Geist.Colors.separator)

            MetricLine(title: "本周", usd: model.snapshot.weekUSD, cny: model.snapshot.weekCNY)

            Divider()
                .overlay(Geist.Colors.separator)

            MetricLine(title: "本月", usd: model.snapshot.monthUSD, cny: model.snapshot.monthCNY)
        }
        .padding(.horizontal, 16)
        .background(Geist.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }

    private var trendPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("每日趋势")
                    .font(Geist.Fonts.heading14)
                    .foregroundStyle(Geist.Colors.primary)

                Spacer()

                Text("按天聚合")
                    .font(Geist.Fonts.label13)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            DailyTrendView(days: model.snapshot.dailyTrend)
        }
        .padding(16)
        .background(Geist.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }

    private var agentsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("AI Agent")
                    .font(Geist.Fonts.heading14)
                    .foregroundStyle(Geist.Colors.primary)

                Spacer()

                Text("今日花费排行")
                    .font(Geist.Fonts.label13)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            if model.snapshot.agentTotals.isEmpty {
                Text("今日暂无使用记录")
                    .font(Geist.Fonts.label14)
                    .foregroundStyle(Geist.Colors.secondary)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(Geist.Colors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                            .stroke(Geist.Colors.border, lineWidth: 1)
                    )
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
                .background(Geist.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                        .stroke(Geist.Colors.border, lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(Geist.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var unpricedNotice: some View {
        if model.snapshot.unpricedEventCount > 0 {
            Text("有 \(model.snapshot.unpricedEventCount) 条使用记录暂未计价。")
                .font(Geist.Fonts.label13)
                .foregroundStyle(Geist.Colors.secondary)
                .lineSpacing(2)
                .padding(12)
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
