import SwiftUI

enum TimeRange: String, CaseIterable {
    case week = "7T"
    case month = "30T"
    case quarter = "90T"
    case all = "Alles"

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .all: return 9999
        }
    }
}

struct PremiumLineChart: View {
    let dataPoints: [(date: Date, score: Double)]
    var emptyText: String = "No chart data yet."

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            GeometryReader { geo in
                chart(in: geo.size)
            }
            .frame(height: 200)
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func chart(in size: CGSize) -> some View {
        if dataPoints.count <= 1 {
            VStack(spacing: KlunaSpacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24))
                    .foregroundColor(.klunaMuted)
                Text(emptyText)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.klunaSurfaceLight)
            )
        } else {
            let minVal = 0.0
            let maxVal = 100.0
            let range = maxVal - minVal
            let points = dataPoints.enumerated().map { idx, item in
                CGPoint(
                    x: size.width * CGFloat(idx) / CGFloat(max(dataPoints.count - 1, 1)),
                    y: size.height * (1 - CGFloat((item.score - minVal) / range))
                )
            }

            ZStack(alignment: .bottomLeading) {
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
                    path.addLine(to: CGPoint(x: last.x, y: size.height))
                    path.addLine(to: CGPoint(x: first.x, y: size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color.klunaAccent.opacity(0.25), Color.klunaAccent.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                    Circle()
                        .fill(Color.klunaAccent)
                        .frame(width: 4, height: 4)
                        .position(p)
                }
            }
        }
    }
}

