import SwiftUI

struct MicroDrillSuggestion: View {
    let drill: MicroDrill
    let weakScore: Double
    let language: String
    let onStart: () -> Void

    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaAccent)
                Text(L10n.targetedDrill)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaAccent)
                Spacer()
                HStack(spacing: 4) {
                    Text(drill.dimension.localizedName)
                        .font(KlunaFont.caption(11))
                    Text("\(Int(weakScore.rounded()))")
                        .font(KlunaFont.scoreDisplay(13))
                }
                .foregroundColor(.forScore(weakScore))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.forScore(weakScore).opacity(0.12))
                .cornerRadius(KlunaRadius.pill)
            }

            Text(drill.title(language: language))
                .font(KlunaFont.heading(16))
                .foregroundColor(.klunaPrimary)

            Text(drill.instruction(language: language))
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaSecondary)
                .lineSpacing(3)

            HStack(alignment: .top, spacing: KlunaSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.klunaAmber)
                    .padding(.top, 2)
                Text(drill.tip(language: language))
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaMuted)
                    .lineSpacing(2)
            }

            Button(action: onStart) {
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 13))
                    Text("\(drill.timeLimit)s \(L10n.drill)")
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
                .stroke(Color.klunaAccent.opacity(0.2), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 15)
        .onAppear {
            withAnimation(KlunaAnimation.spring.delay(2.8)) {
                visible = true
            }
        }
    }
}

struct DrillResultBanner: View {
    let dimension: PerformanceDimension
    let before: Double
    let after: Double
    let language: String

    var delta: Double { after - before }

    @State private var visible = false

    var body: some View {
        VStack(spacing: KlunaSpacing.sm) {
            Text(dimension.localizedName)
                .font(KlunaFont.caption(12))
                .foregroundColor(.klunaMuted)

            HStack(spacing: KlunaSpacing.lg) {
                VStack {
                    Text(L10n.before)
                        .font(KlunaFont.caption(10))
                        .foregroundColor(.klunaMuted)
                    Text("\(Int(before.rounded()))")
                        .font(KlunaFont.scoreDisplay(28))
                        .foregroundColor(.forScore(before))
                }

                VStack {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(delta > 0 ? .klunaGreen : .klunaRed)
                    if delta > 0 {
                        Text("+\(Int(delta.rounded()))")
                            .font(KlunaFont.scoreDisplay(16))
                            .foregroundColor(.klunaGreen)
                    }
                }

                VStack {
                    Text(L10n.after)
                        .font(KlunaFont.caption(10))
                        .foregroundColor(.klunaMuted)
                    Text("\(Int(after.rounded()))")
                        .font(KlunaFont.scoreDisplay(28))
                        .foregroundColor(.forScore(after))
                }
            }

            if delta > 10 {
                Text(language == "de" ? "In 30 Sekunden. Das ist Kluna." : "In 30 seconds. That's Kluna.")
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaGreen)
            } else if delta > 0 {
                Text(language == "de" ? "Fortschritt! Noch ein Drill?" : "Progress! Another drill?")
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaAccent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(KlunaSpacing.md)
        .background((delta > 0 ? Color.klunaGreen : Color.klunaAmber).opacity(0.08))
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke((delta > 0 ? Color.klunaGreen : Color.klunaAmber).opacity(0.2), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(KlunaAnimation.spring.delay(1.5)) {
                visible = true
            }
        }
    }
}
