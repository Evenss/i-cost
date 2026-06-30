import SwiftUI
import TokenCostBarCore

struct SourcesView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x4) {
            sectionHeader

            VStack(spacing: 0) {
                tableHeader

                Divider()
                    .overlay(Geist.Colors.separator)

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
            .geistPanel(padding: 0, radius: Geist.Radius.medium)
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Geist.Spacing.x1) {
                Text("Sources")
                    .font(Geist.Fonts.heading16)
                    .foregroundStyle(Geist.Colors.primary)

                Text("Supported local agents and their read status.")
                    .font(Geist.Fonts.label13)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            Spacer()

            Button {
                model.refresh()
            } label: {
                Label(model.isRefreshing ? "Refreshing…" : "Refresh Data", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GeistButtonStyle(kind: .secondary, height: 32))
            .disabled(model.isRefreshing)
        }
    }

    private var tableHeader: some View {
        HStack(spacing: Geist.Spacing.x4) {
            Text("Source")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Enabled")
                .frame(width: 76, alignment: .leading)
            Text("Status")
                .frame(width: 116, alignment: .leading)
            Text("Synced")
                .frame(width: 92, alignment: .trailing)
        }
        .font(Geist.Fonts.label12)
        .foregroundStyle(Geist.Colors.secondary)
        .padding(.horizontal, Geist.Spacing.x4)
        .frame(height: 36)
        .background(Geist.Colors.backgroundSecondary)
    }

    private func sourceRow(_ source: SourceState) -> some View {
        HStack(spacing: Geist.Spacing.x4) {
            VStack(alignment: .leading, spacing: Geist.Spacing.x1) {
                Text(source.displayName)
                    .font(Geist.Fonts.label14)
                    .foregroundStyle(Geist.Colors.primary)
                    .lineLimit(1)

                Text(detailText(source))
                    .font(Geist.Fonts.mono12)
                    .foregroundStyle(source.status == .error ? Geist.Colors.red : Geist.Colors.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(source.isEnabled ? "Enabled" : "Disabled")
                .font(Geist.Fonts.label13)
                .foregroundStyle(source.isEnabled ? Geist.Colors.primary : Geist.Colors.secondary)
                .frame(width: 76, alignment: .leading)

            GeistStatusBadge(text: source.status.displayName, color: statusColor(source.status))
                .frame(width: 116, alignment: .leading)

            Text(syncText(source.lastSyncedAt))
                .font(Geist.Fonts.mono12)
                .foregroundStyle(Geist.Colors.secondary)
                .monospacedDigit()
                .frame(width: 92, alignment: .trailing)
        }
        .padding(.horizontal, Geist.Spacing.x4)
        .frame(minHeight: 58)
    }

    private var emptyState: some View {
        Text("No sources found")
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

    private func statusColor(_ status: SourceStatus) -> Color {
        switch status {
        case .ready:
            Geist.Colors.green
        case .missing:
            Geist.Colors.amber
        case .disabled:
            Geist.Colors.disabled
        case .error:
            Geist.Colors.red
        }
    }

    private func syncText(_ date: Date?) -> String {
        guard let date else { return "-" }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
