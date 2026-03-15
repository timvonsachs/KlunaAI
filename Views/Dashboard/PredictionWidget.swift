import SwiftUI

struct PredictionWidget: View {
    let prediction: ScorePrediction?
    let lastScore: Double?

    var body: some View {
        if let prediction {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nächste Erwartung")
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(prediction.expectedScore.rounded()))")
                            .font(KlunaFont.scoreDisplay(24))
                            .foregroundColor(.klunaPrimary)
                        Text(prediction.trend.icon)
                            .font(.title3)
                    }
                }
                Spacer()
                if let lastScore {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Zuletzt")
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                        Text("\(Int(lastScore.rounded()))")
                            .font(KlunaFont.scoreDisplay(22))
                            .foregroundColor(.klunaSecondary)
                    }
                }
            }
            .padding(KlunaSpacing.md)
            .background(Color.klunaSurface)
            .cornerRadius(KlunaRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: KlunaRadius.card)
                    .stroke(Color.klunaBorder, lineWidth: 1)
            )
        }
    }
}
