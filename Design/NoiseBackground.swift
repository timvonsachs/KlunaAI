import SwiftUI

struct NoiseBackground: View {
    var body: some View {
        ZStack {
            KlunaColors.bg.ignoresSafeArea()
            RadialGradient(
                colors: [KlunaColors.accent.opacity(0.015), Color.clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            Canvas { context, size in
                for _ in 0..<300 {
                    let x = CGFloat.random(in: 0..<size.width)
                    let y = CGFloat.random(in: 0..<size.height)
                    let opacity = Double.random(in: 0.01...0.03)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white.opacity(opacity))
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
