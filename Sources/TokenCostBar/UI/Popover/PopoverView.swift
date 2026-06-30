import SwiftUI
import TokenCostBarCore

struct PopoverView: View {
    @ObservedObject var model: AppModel
    let openManagement: () -> Void
    let quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x4) {
            todaySection

            Divider()
                .overlay(Geist.Colors.separator)

            DailyTrendView(days: model.snapshot.dailyTrend, compact: true)
                .frame(height: 112)

            Divider()
                .overlay(Geist.Colors.separator)

            agentsSection

            Spacer(minLength: 0)
            footer
        }
        .padding(Geist.Spacing.x4)
        .frame(width: 390, height: 392)
        .background(Geist.Colors.background)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x2) {
            HStack {
                Text("Today")
                    .font(Geist.Fonts.heading14)
                    .foregroundStyle(Geist.Colors.primary)

                Spacer()

                Button {
                    model.refresh()
                } label: {
                    Label(model.isRefreshing ? "Refreshing…" : "Refresh Data", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(GeistButtonStyle(kind: .icon, height: 32))
                .disabled(model.isRefreshing)
                .help(model.isRefreshing ? "Refreshing…" : "Refresh Data")
            }

            HStack(alignment: .firstTextBaseline) {
                Text(MoneyFormatter.usd(model.snapshot.todayUSD))
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Geist.Colors.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer()

                Text(MoneyFormatter.cny(model.snapshot.todayCNY))
                    .font(Geist.Fonts.mono14)
                    .foregroundStyle(Geist.Colors.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var agentsSection: some View {
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
                .geistPanel(padding: 0, radius: Geist.Radius.small)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: Geist.Spacing.x2) {
            Button {
                openManagement()
            } label: {
                Label("Manage Sources", systemImage: "slider.horizontal.3")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(GeistButtonStyle(kind: .tertiary, height: 32))
            .help("Manage Sources")

            Spacer()

            Button {
                quit()
            } label: {
                Label("Quit App", systemImage: "power")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(GeistButtonStyle(kind: .tertiary, height: 32))
            .help("Quit App")
        }
    }
}
