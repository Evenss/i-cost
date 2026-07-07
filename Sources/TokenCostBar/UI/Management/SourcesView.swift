import SwiftUI
import TokenCostBarCore

struct SourcesView: View {
    @ObservedObject var model: AppModel
    private let enabledColumnWidth: CGFloat = 90
    private let statusColumnWidth: CGFloat = 72
    private let headerHeight: CGFloat = 36
    private let rowHeight: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader
            table
            RemoteSourcesEditorView(model: model)
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("采集来源")
                    .font(Geist.Fonts.heading16)
                    .foregroundStyle(Geist.Colors.primary)

                Text("展示支持的本地与远程 AI Agent 日志读取状态。")
                    .font(Geist.Fonts.label13)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            Spacer()

            Button {
                model.refresh()
            } label: {
                RefreshGlyph(isRefreshing: model.isRefreshing, size: 14)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(GeistButtonStyle(kind: .icon, height: 32))
            .help(model.isRefreshing ? "刷新中" : "刷新数据")
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            tableHeader

            if model.snapshot.sourceStates.isEmpty {
                emptyState
            } else {
                ForEach(Array(model.snapshot.sourceStates.enumerated()), id: \.element.id) { index, source in
                    sourceRow(source)

                    if index < model.snapshot.sourceStates.count - 1 {
                        Divider()
                            .overlay(Geist.Colors.separator)
                    }
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

    private var tableHeader: some View {
        HStack(spacing: 16) {
            Text("来源")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("接入")
                .frame(width: enabledColumnWidth, height: headerHeight, alignment: .center)
            Text("状态")
                .frame(width: statusColumnWidth, height: headerHeight, alignment: .center)
        }
        .font(Geist.Fonts.label12.weight(.semibold))
        .foregroundStyle(Geist.Colors.secondary)
        .padding(.horizontal, 16)
        .frame(height: headerHeight)
        .background(Geist.Colors.overlay)
    }

    private func sourceRow(_ source: SourceState) -> some View {
        HStack(spacing: 16) {
            Text(source.displayName)
                .font(Geist.Fonts.label14.weight(.semibold))
                .foregroundStyle(Geist.Colors.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: rowHeight)

            Text(accessText(for: source))
                .font(Geist.Fonts.label13)
                .foregroundStyle(source.status == .ready ? Geist.Colors.primary : Geist.Colors.secondary)
                .frame(width: enabledColumnWidth, height: rowHeight, alignment: .center)

            SourceStatusDot(status: source.status, color: statusColor(source.status))
                .frame(width: statusColumnWidth, height: rowHeight, alignment: .center)
        }
        .padding(.horizontal, 16)
        .frame(height: rowHeight)
    }

    private var emptyState: some View {
        Text("暂无采集来源")
            .font(Geist.Fonts.label14)
            .foregroundStyle(Geist.Colors.secondary)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
    }

    private func accessText(for source: SourceState) -> String {
        source.status == .ready ? "已接入" : "未接入"
    }

    private func statusColor(_ status: SourceStatus) -> Color {
        switch status {
        case .ready:
            Geist.Colors.green
        case .missing:
            Geist.Colors.secondary
        case .disabled:
            Geist.Colors.secondary
        case .error:
            Geist.Colors.red
        }
    }
}

private struct SourceStatusDot: View {
    let status: SourceStatus
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .overlay {
                Circle()
                    .stroke(Geist.Colors.border, lineWidth: 1)
            }
            .help(helpText)
            .accessibilityLabel(helpText)
    }

    private var helpText: String {
        switch status {
        case .ready:
            "可运行"
        case .missing:
            "未找到"
        case .disabled:
            "已停用"
        case .error:
            "错误"
        }
    }
}
