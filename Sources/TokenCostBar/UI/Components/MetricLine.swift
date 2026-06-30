import SwiftUI
import TokenCostBarCore

struct MetricLine: View {
    let title: String
    let usd: Decimal
    let cny: Decimal

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Geist.Fonts.label14)
                .foregroundStyle(Geist.Colors.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormatter.usd(usd))
                    .font(Geist.Fonts.mono14)
                    .foregroundStyle(Geist.Colors.primary)
                    .monospacedDigit()
                Text(MoneyFormatter.cny(cny))
                    .font(Geist.Fonts.mono12)
                    .foregroundStyle(Geist.Colors.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, Geist.Spacing.x2)
    }
}
