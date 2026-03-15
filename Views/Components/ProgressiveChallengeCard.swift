import SwiftUI

struct ProgressiveChallengeCard: View {
    let challenge: ProgressiveChallenge
    let currentLevel: Int
    let totalXP: Int
    let language: String
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                    Text("Level \(currentLevel)")
                        .font(KlunaFont.scoreDisplay(13))
                }
                .foregroundColor(.klunaAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.klunaAccent.opacity(0.12))
                .cornerRadius(KlunaRadius.pill)

                Spacer()
                Text("\(totalXP) XP")
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaGold)
            }

            Text(challenge.title(language: language))
                .font(KlunaFont.heading(17))
                .foregroundColor(.klunaPrimary)

            Text(challenge.description(language: language))
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaSecondary)
                .lineSpacing(2)

            HStack(spacing: KlunaSpacing.md) {
                CriterionPill(icon: "target", text: ">= \(Int(challenge.successCriteria.minScore))", color: .klunaAccent)
                CriterionPill(icon: "timer", text: "\(challenge.timeLimit)s", color: .klunaMuted)
                CriterionPill(icon: "sparkles", text: "+\(challenge.xpReward) XP", color: .klunaGold)
            }

            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13))
                    Text(language == "de" ? "Challenge starten" : "Start Challenge")
                        .font(KlunaFont.heading(15))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KlunaSpacing.sm + 2)
                .background(Color.klunaAccent)
                .cornerRadius(KlunaRadius.button)
            }

            LevelProgressBar(currentLevel: currentLevel, totalLevels: 15)
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

struct CriterionPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(KlunaFont.caption(11))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.08))
        .cornerRadius(KlunaRadius.pill)
    }
}

struct LevelProgressBar: View {
    let currentLevel: Int
    let totalLevels: Int

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.klunaSurfaceLight)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [.klunaAccent, .klunaGreen], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(currentLevel) / CGFloat(totalLevels))
                }
            }
            .frame(height: 4)

            HStack {
                Text("Level \(currentLevel)/\(totalLevels)")
                    .font(KlunaFont.caption(10))
                    .foregroundColor(.klunaMuted)
                Spacer()
            }
        }
    }
}
