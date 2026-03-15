import SwiftUI

struct GoalCompletedBanner: View {
    let result: GoalCompletionResult
    let language: String
    let onNextGoal: () -> Void

    @State private var visible = false

    var body: some View {
        VStack(spacing: KlunaSpacing.md) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.klunaGreen)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language == "de" ? "Ziel erreicht!" : "Goal reached!")
                        .font(KlunaFont.heading(17))
                        .foregroundColor(.klunaGreen)

                    Text("\(result.goal.dimension.shortName(language: language)): \(Int(result.goal.startScore)) -> \(Int(result.achievedScore))")
                        .font(KlunaFont.body(14))
                        .foregroundColor(.klunaSecondary)
                }
                Spacer()
            }

            if result.totalGoalsCompleted > 1 {
                Text(language == "de"
                    ? "\(result.totalGoalsCompleted) Ziele erreicht! 💪"
                    : "\(result.totalGoalsCompleted) goals reached! 💪")
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaGold)
            }

            Button(action: onNextGoal) {
                Text(language == "de" ? "Nächstes Ziel setzen" : "Set next goal")
                    .font(KlunaFont.heading(14))
                    .foregroundColor(.klunaAccent)
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaGreen.opacity(0.08))
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaGreen.opacity(0.3), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(KlunaAnimation.spring.delay(0.2)) { visible = true }
            SoundManager.scoreHaptic()
        }
    }
}
