import SwiftUI

struct BiomarkerResultBanner: View {
    let result: BiomarkerResult
    let language: String

    var body: some View {
        HStack(spacing: KlunaSpacing.md) {
            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(result.passed ? .klunaGreen : .klunaAmber)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.challenge.title(language: language))
                    .font(KlunaFont.heading(14))
                    .foregroundColor(.klunaPrimary)

                HStack(spacing: KlunaSpacing.sm) {
                    Text(language == "de" ? "Erreicht:" : "Achieved:")
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                    Text(String(format: "%.2f", result.achievedValue))
                        .font(KlunaFont.scoreDisplay(14))
                        .foregroundColor(result.passed ? .klunaGreen : .klunaAmber)

                    Text(language == "de" ? "Ziel:" : "Target:")
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                    Text(result.targetDescription)
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                }

                if result.passed {
                    Text("+\(result.challenge.xpReward) XP")
                        .font(KlunaFont.scoreDisplay(13))
                        .foregroundColor(.klunaGold)
                }
            }

            Spacer()
        }
        .padding(KlunaSpacing.md)
        .background((result.passed ? Color.klunaGreen : Color.klunaAmber).opacity(0.08))
        .cornerRadius(KlunaRadius.card)
    }
}
