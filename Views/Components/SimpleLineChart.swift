import SwiftUI

struct SimpleLineChart: View {
    let points: [(date: Date, value: Double)]
    let lineColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color.klunaSurface)
                linePath(in: geo.size)
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
    }

    private func linePath(in size: CGSize) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        let minDate = points.map(\.date).min() ?? Date()
        let maxDate = points.map(\.date).max() ?? Date()
        let range = max(1, maxDate.timeIntervalSince(minDate))
        let rect = CGRect(x: 12, y: 10, width: size.width - 24, height: size.height - 20)

        for (index, item) in points.enumerated() {
            let x = rect.minX + CGFloat(item.date.timeIntervalSince(minDate) / range) * rect.width
            let y = rect.maxY - CGFloat(item.value / 100) * rect.height
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }
}
