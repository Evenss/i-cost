import SwiftUI
import TokenCostBarCore

struct DailyTrendView: View {
    let days: [DailyCost]
    var compact = false

    @State private var hoveredIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.x3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Trend")
                    .font(Geist.Fonts.heading14)
                    .foregroundStyle(Geist.Colors.primary)

                Spacer()

                if compact, let last = days.last {
                    Text(shortLabel(last.day))
                        .font(Geist.Fonts.mono12)
                        .foregroundStyle(Geist.Colors.secondary)
                }
            }

            GeometryReader { proxy in
                let points = chartPoints(in: proxy.size)
                let hoveredPoint = hoveredIndex.flatMap { index in
                    points.indices.contains(index) ? points[index] : nil
                }

                ZStack {
                    baseline(in: proxy.size)
                        .stroke(Geist.Colors.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                    areaPath(points: points, size: proxy.size)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Geist.Colors.blue.opacity(0.14),
                                    Geist.Colors.blue.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(points: points)
                        .stroke(
                            Geist.Colors.blue,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(Geist.Colors.blue)
                            .frame(width: compact ? 4 : 5, height: compact ? 4 : 5)
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
                .padding(.vertical, 4)
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

            if !compact {
                HStack {
                Text(days.first.map { shortLabel($0.day) } ?? "")
                Spacer()
                Text(days.last.map { shortLabel($0.day) } ?? "")
            }
            .font(Geist.Fonts.mono12)
            .foregroundStyle(Geist.Colors.secondary)
        }
    }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !days.isEmpty else { return [] }

        let values = days.map(\.costUSD.doubleValue)
        let maxValue = max(values.max() ?? 0, 0.01)
        let minValue = min(values.min() ?? 0, 0)
        let range = max(maxValue - minValue, 0.01)
        let xStep = days.count > 1 ? size.width / CGFloat(days.count - 1) : 0
        let topPadding: CGFloat = 8
        let bottomPadding: CGFloat = 12
        let drawableHeight = max(1, size.height - topPadding - bottomPadding)

        return values.enumerated().map { index, value in
            let x = CGFloat(index) * xStep
            let normalized = (value - minValue) / range
            let y = topPadding + CGFloat(1 - normalized) * drawableHeight
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

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }

    private func baseline(in size: CGSize) -> Path {
        Path { path in
            let y = size.height - 12
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
    }

    @ViewBuilder
    private func hoverIndicator(point: CGPoint, day: DailyCost, size: CGSize) -> some View {
        let tooltipWidth: CGFloat = 92
        let tooltipHeight: CGFloat = 42
        let x = min(max(point.x, tooltipWidth / 2), size.width - tooltipWidth / 2)
        let y = max(tooltipHeight / 2, point.y - 28)

        Path { path in
            path.move(to: CGPoint(x: point.x, y: 4))
            path.addLine(to: CGPoint(x: point.x, y: size.height - 8))
        }
        .stroke(Geist.Colors.borderHover, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

        Circle()
            .fill(Geist.Colors.background)
            .frame(width: 11, height: 11)
            .overlay(
                Circle()
                    .stroke(Geist.Colors.blue, lineWidth: 2)
            )
            .position(point)

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
        .background(Geist.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.medium, style: .continuous)
                .stroke(Geist.Colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 8)
        .position(x: x, y: y)
    }

    private func nearestIndex(to x: CGFloat, width: CGFloat) -> Int? {
        guard days.count > 1 else {
            return days.isEmpty ? nil : 0
        }

        let clamped = min(max(0, x), width)
        let step = width / CGFloat(days.count - 1)
        guard step > 0 else { return nil }
        let index = Int((clamped / step).rounded())
        return min(max(0, index), days.count - 1)
    }

    private func shortLabel(_ day: String) -> String {
        String(day.suffix(5))
    }
}
