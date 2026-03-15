import SwiftUI

struct ScoreDeltaBadge: View {
    let delta: Double
    @State private var visible = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 14, weight: .bold))
            Text(String(format: "%+.0f", delta))
                .font(KlunaFont.scoreLarge(18))
        }
        .foregroundColor(delta >= 0 ? .klunaGreen : .klunaRed)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background((delta >= 0 ? Color.klunaGreen : Color.klunaRed).opacity(0.15))
        .cornerRadius(KlunaRadius.pill)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 15)
        .onAppear {
            withAnimation(KlunaAnimation.spring.delay(1.6)) {
                visible = true
            }
        }
    }
}

