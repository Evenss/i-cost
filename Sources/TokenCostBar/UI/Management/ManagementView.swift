import SwiftUI

struct ManagementView: View {
    @ObservedObject var model: AppModel
    @State private var selectedTab = ManagementTab.sources

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fixedHeader

            ScrollView {
                Group {
                    switch selectedTab {
                    case .sources:
                        SourcesView(model: model)
                    case .stats:
                        StatsView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, Geist.Spacing.x6)
                .padding(.bottom, Geist.Spacing.x6)
            }
            .scrollIndicators(.automatic)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 480)
        .background(Geist.Colors.background)
    }

    private var fixedHeader: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x4) {
            header
            tabBar
        }
        .padding(Geist.Spacing.x6)
        .padding(.bottom, Geist.Spacing.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.Colors.background)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(Geist.Colors.separator)
        }
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(10)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Geist.Spacing.x1) {
                Text("TokenCostBar")
                    .font(Geist.Fonts.heading20)
                    .foregroundStyle(Geist.Colors.primary)

                Text("Local token spend, summarized quietly.")
                    .font(Geist.Fonts.label13)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            Spacer()

            Text(model.snapshot.lastUpdatedAt.formatted(date: .omitted, time: .shortened))
                .font(Geist.Fonts.mono12)
                .foregroundStyle(Geist.Colors.secondary)
                .monospacedDigit()
        }
    }

    private var tabBar: some View {
        HStack(spacing: Geist.Spacing.x1) {
            ForEach(ManagementTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(Geist.Spacing.x1)
        .background(Geist.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }

    private func tabButton(_ tab: ManagementTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: Geist.Spacing.x2) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: .semibold))

                Text(tab.title)
                    .font(Geist.Fonts.button14)
            }
            .foregroundStyle(isSelected ? Geist.Colors.primary : Geist.Colors.secondary)
            .frame(width: 104, height: 32)
            .background(isSelected ? Geist.Colors.neutral : .clear)
            .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }
}

private enum ManagementTab: String, CaseIterable, Identifiable {
    case sources
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sources:
            "Sources"
        case .stats:
            "Stats"
        }
    }

    var systemImage: String {
        switch self {
        case .sources:
            "tray.full"
        case .stats:
            "chart.line.uptrend.xyaxis"
        }
    }
}
