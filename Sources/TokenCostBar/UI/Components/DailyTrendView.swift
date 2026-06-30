import SwiftUI
import TokenCostBarCore

struct DailyTrendView: View {
    let days: [DailyCost]
    var compact = false

    @State private var hoveredIndex: Int?

    var body: some View {
        VStack(spacing: Geist.Spacing.x2) {
            GeometryReader { proxy in
                let points = chartPoints(in: proxy.size)
                let hoveredPoint = hoveredIndex.flatMap { index in
                    points.indices.contains(index) ? points[index] : nil
                }

                ZStack {
                    gridLines(in: proxy.size)
                        .stroke(Geist.Colors.border, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                    linePath(points: points)
                        .stroke(
                            Geist.Colors.blue,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(compact ? Geist.Colors.background : Geist.Colors.backgroundSecondary)
                            .frame(width: compact ? 8 : 10, height: compact ? 8 : 10)
                            .overlay(
                                Circle()
                                    .stroke(Geist.Colors.blue, lineWidth: 2)
                            )
                            .position(point)
                    }

                    if let hoveredIndex, let hoveredPoint, days.indices.contains(hoveredIndex) {
                        hoverIndicator(
                            point: hoveredPoint,
                            day: days[hoveredIndex],
                            size: proxy.size
                        )
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoveredIndex = nearestIndex(to: location.x, width: proxy.size.width)
                    case .ended:
                        hoveredIndex = nil
                    }
                }
            }
            .frame(height: compact ? 84 : 166)
            .background(compact ? Geist.Colors.background : Geist.Colors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                    .stroke(compact ? Color.clear : Geist.Colors.border, lineWidth: 1)
            )

            HStack {
                Text(days.first.map { shortLabel($0.day) } ?? "")
                Spacer()
                Text(days.last.map { shortLabel($0.day) } ?? "")
            }
            .font(Geist.Fonts.mono12)
            .foregroundStyle(Geist.Colors.secondary)
            .monospacedDigit()
            .padding(.horizontal, 2)
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !days.isEmpty else { return [] }

        let values = days.map(\.costUSD.doubleValue)
        let maxValue = max(values.max() ?? 0, 0.01)
        let minValue = min(values.min() ?? 0, 0)
        let range = max(maxValue - minValue, 0.01)
        let horizontalInset: CGFloat = compact ? 4 : 24
        let topPadding: CGFloat = compact ? 14 : 28
        let bottomPadding: CGFloat = compact ? 14 : 26
        let width = max(1, size.width - horizontalInset * 2)
        let height = max(1, size.height - topPadding - bottomPadding)
        let xStep = days.count > 1 ? width / CGFloat(days.count - 1) : 0

        return values.enumerated().map { index, value in
            let x = horizontalInset + CGFloat(index) * xStep
            let normalized = (value - minValue) / range
            let y = topPadding + CGFloat(1 - normalized) * height
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func gridLines(in size: CGSize) -> Path {
        Path { path in
            let first = compact ? size.height - 14 : size.height - 36
            path.move(to: CGPoint(x: compact ? 0 : 24, y: first))
            path.addLine(to: CGPoint(x: compact ? size.width : size.width - 24, y: first))

            if !compact {
                let second = size.height - 80
                path.move(to: CGPoint(x: 24, y: second))
                path.addLine(to: CGPoint(x: size.width - 24, y: second))
            }
        }
    }

    @ViewBuilder
    private func hoverIndicator(point: CGPoint, day: DailyCost, size: CGSize) -> some View {
        let tooltipWidth: CGFloat = 92
        let tooltipHeight: CGFloat = 42
        let x = min(max(point.x, tooltipWidth / 2), size.width - tooltipWidth / 2)
        let y = max(tooltipHeight / 2, point.y - 30)

        VStack(spacing: 2) {
            Text(shortLabel(day.day))
                .font(Geist.Fonts.mono12)
                .foregroundStyle(Geist.Colors.secondary)
            Text(MoneyFormatter.usd(day.costUSD))
                .font(Geist.Fonts.mono12.weight(.semibold))
                .foregroundStyle(Geist.Colors.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, Geist.Spacing.x2)
        .frame(width: tooltipWidth, height: tooltipHeight)
        .background(Geist.Colors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.small, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
        .position(x: x, y: y)
    }

    private func nearestIndex(to x: CGFloat, width: CGFloat) -> Int? {
        guard days.count > 1 else {
            return days.isEmpty ? nil : 0
        }

        let horizontalInset: CGFloat = compact ? 4 : 24
        let clamped = min(max(horizontalInset, x), width - horizontalInset)
        let step = (width - horizontalInset * 2) / CGFloat(days.count - 1)
        guard step > 0 else { return nil }
        let index = Int(((clamped - horizontalInset) / step).rounded())
        return min(max(0, index), days.count - 1)
    }

    private func shortLabel(_ day: String) -> String {
        String(day.suffix(5))
    }
}
