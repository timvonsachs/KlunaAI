import SwiftUI

struct BiomarkerChallengeCard: View {
    let challenge: BiomarkerChallenge
    let language: String
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            HStack {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaAccent)
                Text(language == "de" ? "Biomarker-Challenge" : "Biomarker Challenge")
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaAccent)
                Spacer()
                Text("+\(challenge.xpReward) XP")
                    .font(KlunaFont.caption(11))
                    .foregroundColor(.klunaGold)
            }

            Text(challenge.title(language: language))
                .font(KlunaFont.heading(16))
                .foregroundColor(.klunaPrimary)

            Text(challenge.instruction(language: language))
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaSecondary)
                .lineSpacing(3)

            HStack(spacing: KlunaSpacing.sm) {
                Image(systemName: "cpu")
                    .font(.system(size: 11))
                    .foregroundColor(.klunaMuted)
                Text(language == "de" ? "Kluna misst das in Echtzeit" : "Kluna measures this in real-time")
                    .font(KlunaFont.caption(11))
                    .foregroundColor(.klunaMuted)
            }

            Button(action: onStart) {
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 13))
                    Text("\(challenge.timeLimit)s Challenge")
                        .font(KlunaFont.heading(14))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KlunaSpacing.sm + 2)
                .background(Color.klunaAccent)
                .cornerRadius(KlunaRadius.button)
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaAccent.opacity(0.15), lineWidth: 1)
        )
    }
}
