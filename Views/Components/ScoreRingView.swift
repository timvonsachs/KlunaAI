import SwiftUI

struct ScoreRingView: View {
    let score: Double
    let isPreliminary: Bool
    let isNewHighScore: Bool

    @State private var animatedProgress: Double = 0
    @State private var showScore = false
    @State private var showGlow = false
    @State private var displayedScore: Int = 0

    private let ringSize: CGFloat = 200
    private let lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.klunaSurfaceLight, lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    Color.forScore(score),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))

            if isNewHighScore && showGlow {
                Circle()
                    .stroke(Color.klunaGold.opacity(0.4), lineWidth: lineWidth + 8)
                    .frame(width: ringSize, height: ringSize)
                    .blur(radius: 8)
                    .transition(.opacity)
            }

            VStack(spacing: KlunaSpacing.xs) {
                Text("\(displayedScore)")
                    .font(KlunaFont.scoreDisplay(56))
                    .foregroundColor(.klunaPrimary)
                    .scaleEffect(showScore ? 1.0 : 1.2)
                    .opacity(showScore ? 1.0 : 0)

                if isPreliminary {
                    Text(L10n.preliminary)
                        .font(KlunaFont.caption(11))
                        .foregroundColor(.klunaMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.klunaSurface)
                        .cornerRadius(6)
                }
            }
        }
        .onAppear {
            withAnimation(KlunaAnimation.scoreReveal) {
                animatedProgress = score / 100
            }
            animateScoreCounter()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                withAnimation(KlunaAnimation.springBouncy) {
                    showScore = true
                }
                SoundManager.scoreHaptic()
                SoundManager.playScoreReveal()
            }
            if isNewHighScore {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
                    withAnimation(KlunaAnimation.spring) {
                        showGlow = true
                    }
                    SoundManager.playNewHighScore()
                }
            }
        }
    }

    private func animateScoreCounter() {
        let duration: Double = 1.5
        let steps = Int(score.rounded())
        let stepDuration = duration / Double(max(steps, 1))
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                displayedScore = i
            }
        }
    }
}

