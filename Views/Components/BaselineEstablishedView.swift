import SwiftUI

struct BaselineEstablishedView: View {
    let language: String
    let onContinue: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var textVisible = false
    @State private var badgeScale: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color.klunaBackground.ignoresSafeArea()

            VStack(spacing: KlunaSpacing.xl) {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.klunaGold.opacity(0.2), lineWidth: 6)
                        .frame(width: 180, height: 180)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Color.klunaGold, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.klunaGold)
                            .scaleEffect(badgeScale)
                        Text("100%")
                            .font(KlunaFont.scoreDisplay(24))
                            .foregroundColor(.klunaGold)
                    }
                }

                VStack(spacing: KlunaSpacing.sm) {
                    Text(language == "de" ? "Kluna kennt deine Stimme" : "Kluna knows your voice")
                        .font(KlunaFont.heading(26))
                        .foregroundColor(.klunaPrimary)
                    Text(language == "de"
                         ? "Ab jetzt basiert jeder Score auf deiner persoenlichen Baseline."
                         : "From now on, every score is based on your personal baseline.")
                    .font(KlunaFont.body(16))
                    .foregroundColor(.klunaSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, KlunaSpacing.xl)
                }
                .opacity(textVisible ? 1 : 0)

                Spacer()

                Button(action: onContinue) {
                    Text(language == "de" ? "Weiter" : "Continue")
                        .font(KlunaFont.heading(17))
                        .foregroundColor(.klunaBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KlunaSpacing.md)
                        .background(Color.klunaGold)
                        .cornerRadius(KlunaRadius.button)
                }
                .padding(.horizontal, KlunaSpacing.lg)
                .opacity(textVisible ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) { ringProgress = 1.0 }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(1.0)) { badgeScale = 1.0 }
            withAnimation(.easeOut(duration: 0.5).delay(1.3)) { textVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                SoundManager.scoreHaptic()
            }
        }
    }
}
