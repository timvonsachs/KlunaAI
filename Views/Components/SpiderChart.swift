import SwiftUI

struct SpiderChart: View {
    let values: [Double]
    let referenceValues: [Double]?
    let labels: [String]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size * 0.36
            ZStack {
                ForEach(1..<5, id: \.self) { step in
                    polygon(Array(repeating: 100.0 * Double(step) / 4.0, count: max(values.count, 3)), center: center, radius: radius)
                        .stroke(Color.klunaMuted.opacity(0.2), lineWidth: 1)
                }
                if let referenceValues {
                    polygon(referenceValues, center: center, radius: radius)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        .foregroundColor(.klunaMuted)
                }
                polygon(values, center: center, radius: radius)
                    .fill(Color.klunaAccent.opacity(0.25))
                polygon(values, center: center, radius: radius)
                    .stroke(Color.klunaAccent, lineWidth: 2)
            }
        }
    }

    private func polygon(_ values: [Double], center: CGPoint, radius: CGFloat) -> Path {
        var p = Path()
        guard !values.isEmpty else { return p }
        let pts = values.indices.map { idx -> CGPoint in
            let angle = (Double(idx) / Double(values.count)) * 2 * Double.pi - Double.pi / 2
            let normalized = max(0, min(1, values[idx] / 100))
            return CGPoint(
                x: center.x + cos(angle) * radius * normalized,
                y: center.y + sin(angle) * radius * normalized
            )
        }
        p.move(to: pts[0])
        pts.dropFirst().forEach { p.addLine(to: $0) }
        p.closeSubpath()
        return p
    }
}
