import SwiftUI
import UIKit

struct PredictionRevealView: View {
    let prediction: ScorePrediction
    let actualScore: Double

    @State private var phase: RevealPhase = .showingPrediction
    @State private var displayedScore: Double = 0
    @State private var showDelta = false
    @State private var deltaOpacity: Double = 0
    @State private var deltaOffset: CGFloat = 20

    private var error: PredictionError {
        prediction.predictionError(actualScore: actualScore)
    }

    enum RevealPhase {
        case showingPrediction
        case transitioning
        case showingDelta
    }

    var body: some View {
        VStack(spacing: 16) {
            if phase == .showingPrediction || phase == .transitioning {
                Text("Kluna erwartet...")
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaMuted)
                    .transition(.opacity)
            }

            Text("\(Int(round(displayedScore)))")
                .font(KlunaFonts.score(80))
                .foregroundStyle(KlunaColors.scoreGradient(displayedScore))
                .contentTransition(.numericText())

            if showDelta {
                PremiumPredictionDelta(delta: Int(round(error.delta)), expectedScore: prediction.expectedScore)
                .opacity(deltaOpacity)
                .offset(y: deltaOffset)
            }

            if phase == .showingDelta {
                Text(error.message)
                    .font(KlunaFont.body(13))
                    .foregroundColor(.klunaSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .transition(.opacity)

            }
        }
        .onAppear(perform: startRevealSequence)
    }

    private func startRevealSequence() {
        displayedScore = prediction.expectedScore
        phase = .showingPrediction

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.8)) {
                phase = .transitioning
                displayedScore = actualScore
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    phase = .showingDelta
                    showDelta = true
                    deltaOpacity = 1
                    deltaOffset = 0
                }
                if error.category == .strongPositive || error.category == .positive {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else if error.category == .negative || error.category == .strongNegative {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

}

struct PremiumPredictionDelta: View {
    let delta: Int
    let expectedScore: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                    .font(KlunaFonts.score(28))
                    .foregroundColor(deltaColor)
                Text("vs. Erwartung")
                    .font(KlunaFonts.label(14))
                    .foregroundColor(KlunaColors.textSecondary)
            }
            Text(deltaLabel)
                .font(KlunaFonts.body(14))
                .foregroundColor(KlunaColors.textSecondary)
            HStack(spacing: 6) {
                Image(systemName: trendIcon)
                    .font(.system(size: 11))
                Text("Trend: stabil")
                    .font(KlunaFonts.label(12))
            }
            .foregroundColor(KlunaColors.textMuted)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.04)))
        }
    }

    private var deltaColor: Color {
        if delta > 5 { return KlunaColors.accent }
        if delta > 0 { return KlunaColors.accent.opacity(0.7) }
        if delta >= -3 { return KlunaColors.textSecondary }
        return KlunaColors.tense
    }

    private var deltaLabel: String {
        if delta > 8 { return "Weit über Erwartung. Stark!" }
        if delta > 3 { return "Über Erwartung. Gut gemacht." }
        if delta >= -3 { return "Im erwarteten Bereich. Solide." }
        if delta >= -8 { return "Etwas unter Erwartung." }
        return "Deutlich unter Erwartung."
    }

    private var trendIcon: String {
        if delta > 3 { return "arrow.up.right" }
        if delta < -3 { return "arrow.down.right" }
        return "arrow.right"
    }
}
