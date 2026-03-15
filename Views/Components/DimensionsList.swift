import SwiftUI

struct DimensionsList: View {
    let scores: DimensionScores
    let previousScores: DimensionScores?
    let visibleDimensions: [PerformanceDimension]

    var body: some View {
        VStack(spacing: KlunaSpacing.sm) {
            ForEach(Array(visibleDimensions.enumerated()), id: \.element) { index, dimension in
                DimensionRow(
                    dimension: dimension,
                    score: scores.score(for: dimension),
                    previousScore: previousScores?.score(for: dimension),
                    delay: Double(index) * KlunaAnimation.stagger
                )
            }
        }
    }
}

struct DimensionRow: View {
    let dimension: PerformanceDimension
    let score: Double
    let previousScore: Double?
    let delay: TimeInterval

    @State private var visible = false
    @State private var barProgress: CGFloat = 0
    @State private var showExplanation = false

    var body: some View {
        VStack(spacing: KlunaSpacing.xs) {
            HStack {
                Text(dimension.localizedName)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaSecondary)
                Spacer()
                if let prev = previousScore {
                    let delta = score - prev
                    if abs(delta) > 1 {
                        Text(String(format: "%+.0f", delta))
                            .font(KlunaFont.caption(12))
                            .foregroundColor(delta > 0 ? .klunaGreen : .klunaRed)
                    }
                }
                Text("\(Int(score.rounded()))")
                    .font(KlunaFont.scoreDisplay(18))
                    .foregroundColor(.forScore(score))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.klunaSurfaceLight)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.forScore(score))
                        .frame(width: geo.size.width * barProgress, height: 4)
                }
            }
            .frame(height: 4)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(delay + 1.8)) {
                    barProgress = CGFloat(score / 100)
                }
            }

            if showExplanation {
                Text(dimension.explanation)
                    .font(KlunaFont.body(12))
                    .foregroundColor(.klunaMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, KlunaSpacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(KlunaAnimation.springFast) {
                showExplanation.toggle()
            }
        }
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : 20)
        .onAppear {
            withAnimation(KlunaAnimation.spring.delay(delay + 1.5)) {
                visible = true
            }
        }
    }
}

