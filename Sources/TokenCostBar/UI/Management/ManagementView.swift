import SwiftUI

final class ManagementNavigation: ObservableObject {
    @Published var selectedTab: ManagementTab

    init(selectedTab: ManagementTab = .sources) {
        self.selectedTab = selectedTab
    }
}

struct ManagementView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var navigation: ManagementNavigation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                switch navigation.selectedTab {
                case .sources:
                    SourcesView(model: model)
                case .stats:
                    StatsView(model: model)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.automatic)
        .frame(minWidth: 680, minHeight: 480)
        .background(Geist.Colors.background)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("管理")
                    .font(Geist.Fonts.heading20)
                    .foregroundStyle(Geist.Colors.primary)
            }

            Spacer(minLength: 16)

            tabBar
        }
    }

    private var tabBar: some View {
        HStack(spacing: Geist.Spacing.x1) {
            ForEach(ManagementTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(Geist.Spacing.x1)
        .background(Geist.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }

    private func tabButton(_ tab: ManagementTab) -> some View {
        let isSelected = navigation.selectedTab == tab

        return Button {
            navigation.selectedTab = tab
        } label: {
            Text(tab.title)
                .font(Geist.Fonts.button14)
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

enum ManagementTab: String, CaseIterable, Identifiable {
    case sources
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sources:
            "来源"
        case .stats:
            "统计"
        }
    }
}
