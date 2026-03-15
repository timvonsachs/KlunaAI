import SwiftUI

struct LevelUpView: View {
    let result: ChallengeResult
    let language: String
    let onContinue: () -> Void

    @State private var ringScale: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.klunaBackground.ignoresSafeArea()

            VStack(spacing: KlunaSpacing.xl) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.klunaGold.opacity(0.3), lineWidth: 4)
                        .frame(width: 150, height: 150)

                    Circle()
                        .trim(from: 0, to: ringScale)
                        .stroke(Color.klunaGold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.klunaGold)
                        Text("Level \(result.challenge.level)")
                            .font(KlunaFont.scoreDisplay(28))
                            .foregroundColor(.klunaPrimary)
                    }
                }
                .scaleEffect(ringScale > 0 ? 1.0 : 0.5)

                VStack(spacing: KlunaSpacing.sm) {
                    Text(language == "de" ? "Geschafft!" : "Completed!")
                        .font(KlunaFont.heading(28))
                        .foregroundColor(.klunaGold)

                    Text(result.challenge.title(language: language))
                        .font(KlunaFont.heading(18))
                        .foregroundColor(.klunaPrimary)

                    HStack(spacing: KlunaSpacing.sm) {
                        Text(language == "de" ? "Erreicht:" : "Achieved:")
                            .font(KlunaFont.body(14))
                            .foregroundColor(.klunaMuted)
                        Text("\(Int(result.achievedScore))")
                            .font(KlunaFont.scoreDisplay(20))
                            .foregroundColor(.forScore(result.achievedScore))
                        Text("/ \(Int(result.requiredScore))")
                            .font(KlunaFont.caption(14))
                            .foregroundColor(.klunaMuted)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 14))
                        Text("+\(result.challenge.xpReward) XP").font(KlunaFont.scoreDisplay(18))
                    }
                    .foregroundColor(.klunaGold)
                    .padding(.top, KlunaSpacing.sm)
                }
                .opacity(textOpacity)

                Spacer()

                Button(action: onContinue) {
                    Text(language == "de"
                         ? "Weiter zu Level \(min(result.challenge.level + 1, 15))"
                         : "Continue to Level \(min(result.challenge.level + 1, 15))")
                    .font(KlunaFont.heading(17))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KlunaSpacing.md)
                    .background(Color.klunaGold)
                    .cornerRadius(KlunaRadius.button)
                }
                .padding(.horizontal, KlunaSpacing.lg)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { ringScale = 1.0 }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) { textOpacity = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SoundManager.scoreHaptic()
            }
        }
    }
}
