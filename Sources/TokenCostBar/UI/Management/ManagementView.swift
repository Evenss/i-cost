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
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(Geist.Colors.border)
                .frame(width: 1)

            page
        }
        .frame(minWidth: 840, minHeight: 600)
        .background {
            NativeMaterialBackground(material: .windowBackground)
                .ignoresSafeArea()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarSection(title: "概览", tabs: [.stats])

            sidebarSection(title: "连接", tabs: [.sources])

            Spacer(minLength: 24)

            sidebarSection(title: "iCost", tabs: [.about])
        }
        .padding(.top, 52)
        .padding(.horizontal, 14)
        .frame(width: 218)
        .background(Geist.Colors.backgroundSecondary.opacity(0.72))
    }

    private func sidebarSection(title: String, tabs: [ManagementTab]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(Geist.Fonts.label12.weight(.semibold))
                .foregroundStyle(Geist.Colors.secondary)
                .padding(.horizontal, 12)

            VStack(spacing: 4) {
                ForEach(tabs) { tab in
                    sidebarButton(tab)
                }
            }
        }
        .padding(.bottom, 22)
    }

    private func sidebarButton(_ tab: ManagementTab) -> some View {
        let isSelected = navigation.selectedTab == tab

        return Button {
            navigation.selectedTab = tab
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tab.tint.opacity(0.76), tab.tint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: tab.tint.opacity(0.2), radius: 3, y: 1)

                Text(tab.title)
                    .font(Geist.Fonts.button14)
                    .foregroundStyle(Geist.Colors.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(isSelected ? Geist.Colors.neutral : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tab.title)
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                pageHeader

                switch navigation.selectedTab {
                case .sources:
                    SourcesView(model: model)
                case .stats:
                    StatsView(model: model)
                case .about:
                    AboutView()
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: 920, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollIndicators(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pageHeader: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [navigation.selectedTab.tint.opacity(0.74), navigation.selectedTab.tint],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: navigation.selectedTab.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

            Text(navigation.selectedTab.title)
                .font(Geist.Fonts.heading24)
                .foregroundStyle(Geist.Colors.primary)
        }
    }
}

enum ManagementTab: String, CaseIterable, Identifiable {
    case sources
    case stats
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sources:
            "采集来源"
        case .stats:
            "花费统计"
        case .about:
            "关于"
        }
    }

    var icon: String {
        switch self {
        case .sources:
            "externaldrive.connected.to.line.below"
        case .stats:
            "chart.bar.xaxis"
        case .about:
            "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .sources:
            Geist.Colors.teal
        case .stats:
            Geist.Colors.blue
        case .about:
            Color(light: "#5856d6", dark: "#7d7aff")
        }
    }
}
