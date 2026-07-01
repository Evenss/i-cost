import SwiftUI
import TokenCostBarCore

struct PopoverView: View {
    @ObservedObject var model: AppModel
    let openManagement: (ManagementTab) -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x3) {
            todaySection
            trendSection
            agentsSection
            footer
        }
        .padding(Geist.Spacing.x4)
        .frame(width: 390, height: 444, alignment: .topLeading)
        .background {
            NativeMaterialBackground(material: .popover)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x2) {
            sectionHead(title: "今日") {
                Button {
                    model.refresh()
                } label: {
                    RefreshGlyph(isRefreshing: model.isRefreshing, size: 14)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(GeistButtonStyle(kind: .icon, height: 32))
                .help(model.isRefreshing ? "刷新中" : "刷新数据")
            }

            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Text(MoneyFormatter.usd(model.snapshot.todayUSD))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(Geist.Colors.blue)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 8)

                Text(MoneyFormatter.cny(model.snapshot.todayCNY))
                    .font(Geist.Fonts.mono14)
                    .foregroundStyle(Geist.Colors.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x2) {
            sectionHead(title: "每日趋势") {
                Text("最近 7 天")
                    .font(Geist.Fonts.label12)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            DailyTrendView(days: model.snapshot.dailyTrend, compact: true)
                .padding(.horizontal, Geist.Spacing.x3)
                .padding(.vertical, Geist.Spacing.x2)
                .background(Geist.Colors.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                        .stroke(Geist.Colors.border, lineWidth: 1)
                )
        }
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x2) {
            sectionHead(title: "AI Agent") {
                Text("\(model.snapshot.agentTotals.count) 个来源")
                    .font(Geist.Fonts.label12)
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
    }

    private var footer: some View {
        VStack(spacing: Geist.Spacing.x3) {
            Divider()
                .overlay(Geist.Colors.separator)

            HStack(spacing: Geist.Spacing.x2) {
                Text("\(model.snapshot.lastUpdatedAt.formatted(date: .omitted, time: .shortened)) 已同步")
                    .font(Geist.Fonts.mono12)
                    .foregroundStyle(Geist.Colors.secondary)
                    .monospacedDigit()

                Spacer()

                HStack(spacing: Geist.Spacing.x2) {
                    footerButton("☰", help: "来源管理") {
                        openManagement(.sources)
                    }

                    footerIconButton("power", help: "退出应用") {
                        quit()
                    }
                }
            }
            .frame(height: 32)
        }
    }

    private func sectionHead<Trailing: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(Geist.Fonts.heading14)
                .foregroundStyle(Geist.Colors.primary)

            Spacer()

            trailing()
        }
        .frame(minHeight: 32)
    }

    private func footerButton(
        _ title: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Geist.Fonts.button14)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(GeistButtonStyle(kind: .icon, height: 32))
        .help(help)
    }

    private func footerIconButton(
        _ systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(GeistButtonStyle(kind: .icon, height: 32))
        .help(help)
    }
}
