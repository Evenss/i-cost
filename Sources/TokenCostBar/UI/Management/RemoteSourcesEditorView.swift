import SwiftUI
import TokenCostBarCore

struct RemoteSourcesEditorView: View {
    @ObservedObject var model: AppModel
    @State private var draft = RemoteHostDraft()
    @State private var editingIndex: Int?
    @State private var isShowingEditor = false
    @State private var isTestingConnection = false
    @State private var connectionFailed = false
    @State private var needsSourceDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader
            hostList

            if isShowingEditor {
                editor
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SSH 远程")
                    .font(Geist.Fonts.heading16)
                    .foregroundStyle(Geist.Colors.primary)

                Text(remoteSummary)
                    .font(Geist.Fonts.label13)
                    .foregroundStyle(Geist.Colors.secondary)
            }

            Spacer()

            Button {
                editingIndex = nil
                draft = RemoteHostDraft()
                resetConnectionState()
                isShowingEditor = true
            } label: {
                Label("添加", systemImage: "plus")
                    .frame(height: 32)
            }
            .buttonStyle(GeistButtonStyle(kind: .secondary, height: 32))
        }
    }

    private var hostList: some View {
        VStack(spacing: 0) {
            if model.remoteConfiguration.hosts.isEmpty {
                Text("暂无远程主机")
                    .font(Geist.Fonts.label14)
                    .foregroundStyle(Geist.Colors.secondary)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .center)
            } else {
                ForEach(Array(model.remoteConfiguration.hosts.enumerated()), id: \.offset) { index, host in
                    RemoteHostRow(
                        host: host,
                        edit: {
                            editingIndex = index
                            draft = RemoteHostDraft(host: host)
                            resetConnectionState()
                            isShowingEditor = true
                        },
                        delete: {
                            deleteHost(at: index)
                        }
                    )

                    if index < model.remoteConfiguration.hosts.count - 1 {
                        Divider()
                            .overlay(Geist.Colors.separator)
                    }
                }
            }
        }
        .background(Geist.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.medium, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(editingIndex == nil ? "新增远程主机" : "编辑远程主机")
                    .font(Geist.Fonts.heading14)
                    .foregroundStyle(Geist.Colors.primary)

                Spacer()

                Button {
                    cancelEditing()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(GeistButtonStyle(kind: .icon, height: 32))
                .help("取消")
            }

            RemoteTextField(
                title: "SSH 地址",
                placeholder: "workstation 或 user@host",
                text: $draft.host
            )

            if connectionFailed {
                connectionDetails
            }

            if needsSourceDetails {
                sourceDetails
            }

            if let error = model.remoteConfigurationError {
                Text(error)
                    .font(Geist.Fonts.label13)
                    .foregroundStyle(Geist.Colors.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Spacer()

                Button("取消") {
                    cancelEditing()
                }
                .buttonStyle(GeistButtonStyle(kind: .tertiary, height: 32))

                Button(action: primaryAction) {
                    if isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                            .frame(height: 32)
                    } else {
                        Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                            .frame(height: 32)
                    }
                }
                .buttonStyle(GeistButtonStyle(kind: .primary, height: 32))
                .disabled(isTestingConnection || (needsSourceDetails ? !draft.canSave : !draft.canConnect))
            }
        }
        .padding(16)
        .background(Geist.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.medium, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }

    private var connectionDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("连接失败，请补充 SSH 信息")
                .font(Geist.Fonts.label13)
                .foregroundStyle(Geist.Colors.red)

            HStack(spacing: 12) {
                RemoteTextField(title: "远程用户名", placeholder: "可选", text: $draft.user)
                RemoteTextField(title: "端口", placeholder: "22", text: $draft.port)
                    .frame(maxWidth: 160)
            }

            RemoteTextField(
                title: "私钥",
                placeholder: "使用系统 SSH 配置",
                text: $draft.identityFile
            )
        }
    }

    private var sourceDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("未找到使用记录，请补充日志位置")
                .font(Geist.Fonts.label13)
                .foregroundStyle(Geist.Colors.secondary)

            HStack(spacing: 18) {
                Toggle(AgentSource.claudeCode.displayName, isOn: $draft.includeClaudeCode)
                Toggle(AgentSource.codex.displayName, isOn: $draft.includeCodex)
                Toggle(AgentSource.cursor.displayName, isOn: $draft.includeCursor)
            }
            .toggleStyle(.checkbox)
            .font(Geist.Fonts.label13)
            .foregroundStyle(Geist.Colors.primary)

            if draft.includeClaudeCode {
                RemoteTextField(title: "Claude 路径", placeholder: "~/.claude/projects", text: $draft.claudePath)
            }

            if draft.includeCodex {
                RemoteTextField(title: "Codex 路径", placeholder: "~/.codex/sessions", text: $draft.codexPath)
            }

            if draft.includeCursor {
                RemoteTextField(
                    title: "Cursor 路径",
                    placeholder: "~/Library/Application Support/Cursor/User",
                    text: $draft.cursorPath
                )
            }
        }
    }

    private var primaryButtonTitle: String {
        if needsSourceDetails {
            return "保存"
        }
        return connectionFailed ? "重新连接" : "连接"
    }

    private var primaryButtonIcon: String {
        needsSourceDetails ? "checkmark" : "network"
    }

    private var remoteSummary: String {
        let count = model.remoteConfiguration.hosts.count
        return count == 0 ? "未配置远程主机" : "\(count) 台远程主机"
    }

    private func saveDraft() {
        guard let host = draft.configuration else { return }

        var hosts = model.remoteConfiguration.hosts
        if let editingIndex, hosts.indices.contains(editingIndex) {
            hosts[editingIndex] = host
        } else {
            hosts.append(host)
        }

        model.saveRemoteConfiguration(RemoteSourcesConfiguration(hosts: hosts))
        cancelEditing()
    }

    private func primaryAction() {
        if needsSourceDetails {
            saveDraft()
            return
        }

        Task {
            await connectAndSave()
        }
    }

    @MainActor
    private func connectAndSave() async {
        guard let host = draft.configuration else { return }

        isTestingConnection = true
        let result = await model.probeRemoteHost(host)
        isTestingConnection = false

        guard result.isConnected else {
            connectionFailed = true
            needsSourceDetails = false
            return
        }

        connectionFailed = false
        if result.detectedSources.isEmpty {
            needsSourceDetails = true
            return
        }

        if editingIndex == nil {
            draft.useDetectedSources(result.detectedSources)
        }
        saveDraft()
    }

    private func deleteHost(at index: Int) {
        var hosts = model.remoteConfiguration.hosts
        guard hosts.indices.contains(index) else { return }

        hosts.remove(at: index)
        model.saveRemoteConfiguration(RemoteSourcesConfiguration(hosts: hosts))

        if editingIndex == index {
            cancelEditing()
        }
    }

    private func cancelEditing() {
        editingIndex = nil
        draft = RemoteHostDraft()
        resetConnectionState()
        isShowingEditor = false
    }

    private func resetConnectionState() {
        isTestingConnection = false
        connectionFailed = false
        needsSourceDetails = false
    }
}

private struct RemoteHostRow: View {
    let host: RemoteHostConfiguration
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "network")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Geist.Colors.secondary)
                .frame(width: 28, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(host.displayName)
                    .font(Geist.Fonts.label14.weight(.semibold))
                    .foregroundStyle(Geist.Colors.primary)
                    .lineLimit(1)

                Text(host.target)
                    .font(Geist.Fonts.mono12)
                    .foregroundStyle(Geist.Colors.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(host.enabledSources, id: \.rawValue) { source in
                    Text(shortName(for: source))
                        .font(Geist.Fonts.label12)
                        .foregroundStyle(Geist.Colors.primary)
                        .padding(.horizontal, 7)
                        .frame(height: 24)
                        .background(Geist.Colors.neutral)
                        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
                }
            }
            .frame(minWidth: 132, alignment: .trailing)

            HStack(spacing: 6) {
                Button(action: edit) {
                    Image(systemName: "square.and.pencil")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(GeistButtonStyle(kind: .icon, height: 30))
                .help("编辑")

                Button(action: delete) {
                    Image(systemName: "trash")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(GeistButtonStyle(kind: .icon, height: 30))
                .help("删除")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
    }

    private func shortName(for source: AgentSource) -> String {
        switch source {
        case .claudeCode:
            "Claude"
        case .codex:
            "Codex"
        case .cursor:
            "Cursor"
        }
    }
}

private struct RemoteTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Geist.Fonts.label12.weight(.semibold))
                .foregroundStyle(Geist.Colors.secondary)

            TextField(placeholder, text: $text)
                .font(Geist.Fonts.label13)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Geist.Colors.overlay)
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                        .stroke(Geist.Colors.border, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RemoteHostDraft: Equatable {
    var id = ""
    var host = ""
    var user = ""
    var port = ""
    var identityFile = ""
    var connectTimeoutSeconds = ""
    var includeClaudeCode = true
    var includeCodex = true
    var includeCursor = false
    var claudePath = "~/.claude/projects"
    var codexPath = "~/.codex/sessions"
    var cursorPath = "~/Library/Application Support/Cursor/User"

    init() {}

    init(host configuration: RemoteHostConfiguration) {
        id = configuration.id ?? ""
        host = configuration.host
        user = configuration.user ?? ""
        port = configuration.port.map(String.init) ?? ""
        identityFile = configuration.identityFile ?? ""
        connectTimeoutSeconds = configuration.connectTimeoutSeconds.map(String.init) ?? ""
        includeClaudeCode = configuration.enabledSources.contains(.claudeCode)
        includeCodex = configuration.enabledSources.contains(.codex)
        includeCursor = configuration.enabledSources.contains(.cursor)
        claudePath = configuration.remotePath(for: .claudeCode)
        codexPath = configuration.remotePath(for: .codex)
        cursorPath = configuration.remotePath(for: .cursor)
    }

    var canSave: Bool {
        canConnect
            && !selectedSources.isEmpty
    }

    var canConnect: Bool {
        parsedAddress != nil
            && parsedPositiveInteger(port) != nil
            && parsedPositiveInteger(connectTimeoutSeconds) != nil
    }

    var configuration: RemoteHostConfiguration? {
        guard canConnect, let parsedAddress else { return nil }

        return RemoteHostConfiguration(
            id: optionalString(id),
            host: parsedAddress.host,
            user: optionalString(user) ?? parsedAddress.user,
            port: integerValue(port),
            identityFile: optionalString(identityFile),
            sources: selectedSources,
            paths: selectedPaths,
            connectTimeoutSeconds: integerValue(connectTimeoutSeconds)
        )
    }

    mutating func useDetectedSources(_ sources: [AgentSource]) {
        includeClaudeCode = sources.contains(.claudeCode)
        includeCodex = sources.contains(.codex)
        includeCursor = sources.contains(.cursor)
    }

    private var parsedAddress: (user: String?, host: String)? {
        let address = trimmed(host)
        guard !address.isEmpty else { return nil }

        guard let separator = address.lastIndex(of: "@") else {
            return (nil, address)
        }

        let addressUser = trimmed(String(address[..<separator]))
        let addressHost = trimmed(String(address[address.index(after: separator)...]))
        guard !addressUser.isEmpty, !addressHost.isEmpty else { return nil }
        return (addressUser, addressHost)
    }

    private var selectedSources: [AgentSource] {
        var sources: [AgentSource] = []
        if includeClaudeCode {
            sources.append(.claudeCode)
        }
        if includeCodex {
            sources.append(.codex)
        }
        if includeCursor {
            sources.append(.cursor)
        }
        return sources
    }

    private var selectedPaths: [String: String] {
        var paths: [String: String] = [:]
        if includeClaudeCode {
            paths[AgentSource.claudeCode.rawValue] = trimmed(claudePath)
        }
        if includeCodex {
            paths[AgentSource.codex.rawValue] = trimmed(codexPath)
        }
        if includeCursor {
            paths[AgentSource.cursor.rawValue] = trimmed(cursorPath)
        }
        return paths
    }

    private func optionalString(_ value: String) -> String? {
        let value = trimmed(value)
        return value.isEmpty ? nil : value
    }

    private func integerValue(_ value: String) -> Int? {
        let value = trimmed(value)
        return value.isEmpty ? nil : Int(value)
    }

    private func parsedPositiveInteger(_ value: String) -> Int? {
        let value = trimmed(value)
        guard !value.isEmpty else { return 1 }
        guard let intValue = Int(value), intValue > 0 else { return nil }
        return intValue
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
