import SwiftUI

struct InsightCardView: View {
    let insight: VoiceInsight
    let remaining: Int

    var body: some View {
        KlunaCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("🧬 Discovery \(insight.sessionNumber)/7")
                        .font(KlunaFonts.label(12))
                        .foregroundColor(KlunaColors.accent)
                    Spacer()
                    Text(insight.quadrant)
                        .font(KlunaFonts.label(11))
                        .foregroundColor(KlunaColors.textMuted)
                }

                Text(insight.title)
                    .font(KlunaFonts.headline(20))
                    .foregroundColor(KlunaColors.textPrimary)

                Text(insight.body)
                    .font(KlunaFonts.body(14))
                    .foregroundColor(KlunaColors.textSecondary)
                    .lineSpacing(4)

                if insight.value > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(Int(insight.value))/100")
                                .font(KlunaFonts.score(16))
                                .foregroundColor(KlunaColors.textPrimary)
                            Spacer()
                            Text(insight.benchmark)
                                .font(KlunaFonts.label(11))
                                .foregroundColor(KlunaColors.textMuted)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.white.opacity(0.08))
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(KlunaColors.accentGradient)
                                    .frame(width: geo.size.width * CGFloat(min(1, insight.value / 100)))
                            }
                        }
                        .frame(height: 10)
                    }
                }

                if remaining > 0 {
                    Text("Noch \(remaining) Erkenntnisse bis zu deinem vollstaendigen Stimmprofil.")
                        .font(KlunaFonts.label(12))
                        .foregroundColor(KlunaColors.textMuted)
                }
            }
        }
    }
}
