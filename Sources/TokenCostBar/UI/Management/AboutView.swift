import AppKit
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 24) {
            appIdentity

            settingsCard {
                settingRow(
                    icon: "number",
                    title: "版本",
                    value: versionText
                )

                rowDivider

                settingRow(
                    icon: "laptopcomputer",
                    title: "系统要求",
                    value: "macOS 14+"
                )

                rowDivider

                settingRow(
                    icon: "externaldrive.fill",
                    title: "支持的来源",
                    subtitle: "Claude Code、Codex 和 Cursor",
                    value: "3 种"
                )
            }

            settingsCard {
                Link(destination: projectURL) {
                    settingRow(
                        icon: "globe",
                        title: "项目主页",
                        value: "GitHub",
                        showsArrow: true
                    )
                }
                .buttonStyle(.plain)

                rowDivider

                Link(destination: issuesURL) {
                    settingRow(
                        icon: "ladybug",
                        title: "报告问题",
                        value: "GitHub Issues",
                        showsArrow: true
                    )
                }
                .buttonStyle(.plain)

                rowDivider

                settingRow(
                    icon: "lock.shield",
                    title: "数据处理",
                    subtitle: "使用记录和花费数据均由这台 Mac 处理",
                    value: "仅本机"
                )
            }

            Label(
                "iCost 不会上传 Agent 对话内容。",
                systemImage: "checkmark.shield.fill"
            )
            .font(Geist.Fonts.label13)
            .foregroundStyle(Geist.Colors.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var appIdentity: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: Geist.Colors.shadow, radius: 12, y: 6)

            Text("iCost")
                .font(Geist.Fonts.heading24)
                .foregroundStyle(Geist.Colors.primary)

            Text("v\(shortVersion)")
                .font(Geist.Fonts.mono14)
                .foregroundStyle(Geist.Colors.secondary)
        }
        .padding(.vertical, 10)
    }

    private func settingsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity)
        .background(Geist.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.medium, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
    }

    private func settingRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        value: String,
        showsArrow: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Geist.Colors.primary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Geist.Fonts.label14.weight(.semibold))
                    .foregroundStyle(Geist.Colors.primary)

                if let subtitle {
                    Text(subtitle)
                        .font(Geist.Fonts.label12)
                        .foregroundStyle(Geist.Colors.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 16)

            Text(value)
                .font(Geist.Fonts.label13)
                .foregroundStyle(Geist.Colors.secondary)
                .multilineTextAlignment(.trailing)

            if showsArrow {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Geist.Colors.disabled)
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: subtitle == nil ? 58 : 72)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Geist.Colors.separator)
            .padding(.leading, 58)
            .padding(.trailing, 18)
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var versionText: String {
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(shortVersion) (\(build))"
    }

    private var projectURL: URL {
        URL(string: "https://github.com/Evenss/i-cost")!
    }

    private var issuesURL: URL {
        URL(string: "https://github.com/Evenss/i-cost/issues")!
    }
}
