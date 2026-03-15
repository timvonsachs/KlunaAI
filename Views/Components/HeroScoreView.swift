import SwiftUI

struct HeroScoreView: View {
    let averageScore: Double
    let trend: Double?
    let subtitle: String

    @State private var animatedScore: Double = 0
    @State private var showTrend = false

    var body: some View {
        VStack(spacing: KlunaSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: KlunaSpacing.sm) {
                Text("\(Int(animatedScore.rounded()))")
                    .font(KlunaFont.scoreDisplay(64))
                    .foregroundColor(averageScore > 0 ? .klunaPrimary : .klunaMuted)
                    .contentTransition(.numericText())

                if let trend, trend != 0, averageScore > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 16, weight: .bold))
                        Text(String(format: "%+.0f", trend))
                            .font(KlunaFont.scoreLarge(18))
                    }
                    .foregroundColor(trend > 0 ? .klunaGreen : .klunaRed)
                    .opacity(showTrend ? 1 : 0)
                    .offset(y: showTrend ? 0 : 10)
                }
            }

            Text(subtitle)
                .font(KlunaFont.caption(14))
                .foregroundColor(.klunaMuted)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.klunaSurfaceLight)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.forScore(averageScore))
                        .frame(width: geo.size.width * (animatedScore / 100), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, KlunaSpacing.xl)
        }
        .padding(.vertical, KlunaSpacing.lg)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
        .onAppear {
            withAnimation(KlunaAnimation.scoreReveal) {
                animatedScore = averageScore
            }
            withAnimation(KlunaAnimation.spring.delay(1.0)) {
                showTrend = true
            }
        }
    }
}

