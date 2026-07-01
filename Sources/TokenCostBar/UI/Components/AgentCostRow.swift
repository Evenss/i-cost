import SwiftUI
import TokenCostBarCore

struct AgentCostRow: View {
    let agent: AgentCost

    var body: some View {
        HStack(spacing: Geist.Spacing.x3) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)

            Text(agent.source.displayName)
                .font(Geist.Fonts.label14)
                .foregroundStyle(Geist.Colors.primary)
                .lineLimit(1)

            Spacer()

            Text(MoneyFormatter.usd(agent.costUSD))
                .font(Geist.Fonts.mono14)
                .foregroundStyle(Geist.Colors.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, Geist.Spacing.x3)
        .frame(minHeight: 42)
    }

    private var color: Color {
        switch agent.source {
        case .claudeCode:
            Geist.Colors.primary
        case .codex:
            Geist.Colors.blue
        case .cursor:
            Geist.Colors.teal
        }
    }
}
