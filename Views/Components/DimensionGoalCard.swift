import SwiftUI

struct DimensionGoalCard: View {
    let goal: DimensionGoal
    let currentScore: Double
    let progress: Double
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            HStack {
                Image(systemName: "scope")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaAccent)
                Text(language == "de" ? "Dein Ziel" : "Your Goal")
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaAccent)
                Spacer()
            }

            Text(goalText(language: language))
                .font(KlunaFont.heading(16))
                .foregroundColor(.klunaPrimary)

            VStack(spacing: KlunaSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.klunaSurfaceLight)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geo.size.width * min(1.0, max(0, progress)), height: 8)
                            .animation(.easeOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(goal.startScore))")
                        .font(KlunaFont.caption(11))
                        .foregroundColor(.klunaMuted)
                    Spacer()
                    if progress > 0 && progress < 1 {
                        Text("\(Int(currentScore))")
                            .font(KlunaFont.scoreDisplay(13))
                            .foregroundColor(.klunaAccent)
                    }
                    Spacer()
                    Text("\(Int(goal.targetScore))")
                        .font(KlunaFont.caption(11))
                        .foregroundColor(progress >= 1 ? .klunaGreen : .klunaMuted)
                }
            }

            Text(motivationText(language: language))
                .font(KlunaFont.caption(12))
                .foregroundColor(.klunaMuted)
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaAccent.opacity(0.15), lineWidth: 1)
        )
    }

    private var progressColor: Color {
        if progress >= 1.0 { return .klunaGreen }
        if progress >= 0.6 { return .klunaAccent }
        return .klunaAmber
    }

    private func goalText(language: String) -> String {
        let dimName = goal.dimension.shortName(language: language)
        let points = max(1, Int(goal.improvementNeeded.rounded()))
        return language == "de"
            ? "Steigere \(dimName) um \(points) Punkte auf \(Int(goal.targetScore))"
            : "Raise \(dimName) by \(points) points to \(Int(goal.targetScore))"
    }

    private func motivationText(language: String) -> String {
        let remaining = max(0, Int(goal.targetScore - currentScore))
        if progress >= 1.0 {
            return language == "de" ? "Ziel erreicht! 🎯" : "Goal reached! 🎯"
        } else if remaining <= 2 {
            return language == "de" ? "Fast da! Nur noch \(remaining) Punkte." : "Almost there! Just \(remaining) points."
        } else if progress >= 0.5 {
            return language == "de" ? "Mehr als die Hälfte geschafft!" : "Past the halfway mark!"
        } else {
            let dimName = goal.dimension.shortName(language: language)
            return language == "de" ? "Fokussiere auf \(dimName)-Drills." : "Focus on \(dimName) drills."
        }
    }
}
