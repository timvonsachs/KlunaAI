import SwiftUI

struct SparklineView: View {
    let dataPoints: [Double]
    var labels: [String] = []
    var emptyLabel: String? = nil
    var title: String = "7-Tage Verlauf (Overall)"
    @State private var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            Text(title)
                .font(KlunaFont.caption(13))
                .foregroundColor(.klunaMuted)

            GeometryReader { geo in
                if dataPoints.count > 1 {
                    let minVal = (dataPoints.min() ?? 0) - 5
                    let maxVal = (dataPoints.max() ?? 100) + 5
                    let range = max(maxVal - minVal, 1)

                    let points = dataPoints.enumerated().map { index, point in
                        CGPoint(
                            x: geo.size.width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1)),
                            y: geo.size.height * (1 - CGFloat((point - minVal) / range))
                        )
                    }

                    ZStack(alignment: .topLeading) {
                        // Y-Achsen-Hinweise
                        VStack {
                            HStack {
                                Text("\(Int(maxVal.rounded()))")
                                    .font(KlunaFont.caption(10))
                                    .foregroundColor(.klunaMuted)
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Text("\(Int(minVal.rounded()))")
                                    .font(KlunaFont.caption(10))
                                    .foregroundColor(.klunaMuted)
                                Spacer()
                            }
                        }

                        Path { path in
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for idx in 1..<points.count {
                                let prev = points[idx - 1]
                                let current = points[idx]
                                let midX = (prev.x + current.x) / 2
                                path.addCurve(
                                    to: current,
                                    control1: CGPoint(x: midX, y: prev.y),
                                    control2: CGPoint(x: midX, y: current.y)
                                )
                            }
                        }
                        .stroke(Color.klunaAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        Path { path in
                            guard let first = points.first, let last = points.last else { return }
                            path.move(to: first)
                            for idx in 1..<points.count {
                                let prev = points[idx - 1]
                                let current = points[idx]
                                let midX = (prev.x + current.x) / 2
                                path.addCurve(
                                    to: current,
                                    control1: CGPoint(x: midX, y: prev.y),
                                    control2: CGPoint(x: midX, y: current.y)
                                )
                            }
                            path.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                            path.addLine(to: CGPoint(x: first.x, y: geo.size.height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [Color.klunaAccent.opacity(0.25), Color.klunaAccent.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        if let selectedIndex,
                           selectedIndex >= 0,
                           selectedIndex < points.count {
                            let point = points[selectedIndex]
                            Path { path in
                                path.move(to: CGPoint(x: point.x, y: 0))
                                path.addLine(to: CGPoint(x: point.x, y: geo.size.height))
                            }
                            .stroke(Color.klunaAccent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                            Circle()
                                .fill(Color.klunaAccent)
                                .frame(width: 8, height: 8)
                                .position(point)

                            let label = labelForPoint(at: selectedIndex)
                            Text("\(label): \(Int(dataPoints[selectedIndex].rounded()))")
                                .font(KlunaFont.caption(11))
                                .foregroundColor(.klunaPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.klunaSurfaceLight)
                                .cornerRadius(KlunaRadius.button)
                                .position(
                                    x: min(max(70, point.x), geo.size.width - 70),
                                    y: max(12, point.y - 18)
                                )
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                selectedIndex = nearestIndex(at: value.location.x, width: geo.size.width)
                            }
                    )
                } else if let single = dataPoints.first {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(emptyLabel ?? (L10n.thisWeek))
                                .font(KlunaFont.caption(12))
                                .foregroundColor(.klunaMuted)
                            Text("\(Int(single.rounded()))")
                                .font(KlunaFont.scoreDisplay(24))
                                .foregroundColor(.forScore(single))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, KlunaSpacing.sm)
                } else {
                    VStack(spacing: KlunaSpacing.sm) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.klunaMuted)
                        Text(emptyLabel ?? (L10n.startRecording))
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 90)

            if dataPoints.count > 1 {
                HStack {
                    Text(labelForPoint(at: 0))
                    Spacer()
                    Text(labelForPoint(at: dataPoints.count - 1))
                }
                .font(KlunaFont.caption(11))
                .foregroundColor(.klunaMuted)
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }

    private func nearestIndex(at x: CGFloat, width: CGFloat) -> Int {
        guard dataPoints.count > 1 else { return 0 }
        let normalized = max(0, min(1, x / max(width, 1)))
        return Int(round(normalized * CGFloat(dataPoints.count - 1)))
    }

    private func labelForPoint(at index: Int) -> String {
        guard index >= 0 else { return "" }
        if index < labels.count, !labels[index].isEmpty { return labels[index] }
        return "\(index + 1)"
    }
}

