import SwiftUI

struct PremiumRadarChart: View {
    let current: DimensionScores
    let previous: DimensionScores?

    private let dimensions = PerformanceDimension.activeDimensions

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 30
            ZStack {
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { scale in
                    polygonPoints(center: center, radius: radius * scale)
                        .stroke(Color.klunaBorder, lineWidth: 0.5)
                }

                ForEach(0..<dimensions.count, id: \.self) { i in
                    let angle = Angle(degrees: Double(i) * (360.0 / Double(dimensions.count)) - 90)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pointOnCircle(center: center, radius: radius, angle: angle))
                    }
                    .stroke(Color.klunaBorder, lineWidth: 0.5)
                }

                if let previous {
                    radarShape(scores: previous, center: center, radius: radius)
                        .stroke(Color.klunaMuted, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                }

                radarShape(scores: current, center: center, radius: radius)
                    .fill(Color.klunaAccent.opacity(0.2))
                radarShape(scores: current, center: center, radius: radius)
                    .stroke(Color.klunaAccent, lineWidth: 2)

                ForEach(Array(dimensions.enumerated()), id: \.offset) { index, dim in
                    let angle = Angle(degrees: Double(index) * (360.0 / Double(dimensions.count)) - 90)
                    let p = pointOnCircle(center: center, radius: radius + 20, angle: angle)
                    Text(dim.shortName)
                        .font(KlunaFont.caption(11))
                        .foregroundColor(.klunaMuted)
                        .position(p)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }

    private func radarShape(scores: DimensionScores, center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for (index, dim) in dimensions.enumerated() {
                let value = scores.score(for: dim) / 100
                let angle = Angle(degrees: Double(index) * (360.0 / Double(dimensions.count)) - 90)
                let p = pointOnCircle(center: center, radius: radius * value, angle: angle)
                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }

    private func polygonPoints(center: CGPoint, radius: CGFloat) -> Path {
        Path { path in
            for i in 0..<dimensions.count {
                let angle = Angle(degrees: Double(i) * (360.0 / Double(dimensions.count)) - 90)
                let p = pointOnCircle(center: center, radius: radius, angle: angle)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        }
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(CGFloat(angle.radians)),
            y: center.y + radius * sin(CGFloat(angle.radians))
        )
    }
}

