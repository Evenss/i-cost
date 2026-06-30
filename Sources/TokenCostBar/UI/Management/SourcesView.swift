import SwiftUI
import TokenCostBarCore

struct SourcesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader
            table
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("采集来源")
                    .font(Geist.Fonts.heading16)
                    .foregroundStyle(Geist.Colors.primary)

                Text("展示支持的本地 AI Agent 日志读取状态。")
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
                            .overlay(Geist.Colors.border)
                    }
                }
            }
        }
        .background(Geist.Colors.background)
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
            Text("启用")
                .frame(width: 90, alignment: .leading)
            Text("状态")
                .frame(width: 112, alignment: .leading)
        }
        .font(Geist.Fonts.label12.weight(.semibold))
        .foregroundStyle(Geist.Colors.secondary)
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(Geist.Colors.backgroundSecondary)
    }

    private func sourceRow(_ source: SourceState) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(source.displayName)
                    .font(Geist.Fonts.label14.weight(.semibold))
                    .foregroundStyle(Geist.Colors.primary)
                    .lineLimit(1)

                Text(detailText(source))
                    .font(Geist.Fonts.mono12)
                    .foregroundStyle(source.status == .error ? Geist.Colors.red : Geist.Colors.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(source.isEnabled ? "已启用" : "已停用")
                .font(Geist.Fonts.label13)
                .foregroundStyle(source.isEnabled ? Geist.Colors.primary : Geist.Colors.secondary)
                .frame(width: 90, alignment: .leading)

            GeistStatusBadge(text: statusText(source.status), color: statusColor(source.status))
                .frame(width: 112, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 58)
    }

    private var emptyState: some View {
        Text("暂无采集来源")
            .font(Geist.Fonts.label14)
            .foregroundStyle(Geist.Colors.secondary)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
    }

    private func detailText(_ source: SourceState) -> String {
        if let message = source.message, !message.isEmpty {
            return message
        }

        if let path = source.path, !path.isEmpty {
            return path
        }

        return source.source.defaultRelativePath
    }

    private func statusText(_ status: SourceStatus) -> String {
        switch status {
        case .ready:
            "可读取"
        case .missing:
            "未找到"
        case .disabled:
            "已停用"
        case .error:
            "错误"
        }
    }

    private func statusColor(_ status: SourceStatus) -> Color {
        switch status {
        case .ready:
            Geist.Colors.blue
        case .missing:
            Geist.Colors.secondary
        case .disabled:
            Geist.Colors.secondary
        case .error:
            Geist.Colors.red
        }
    }
}
