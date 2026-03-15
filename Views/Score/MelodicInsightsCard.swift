import SwiftUI

struct MelodicInsightsCard: View {
    let analysis: MelodicContourAnalysis
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(.purple)
                Text("Melodie-Analyse")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(analysis.intentionalityScore.rounded()))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(intentionalityColor))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    insightRow(
                        icon: "⛰️",
                        label: "Betonungsmuster",
                        value: "\(analysis.hatPatternCount) erkannt",
                        score: analysis.hatPatternScore,
                        tip: analysis.hatPatternCount < 3
                            ? "Betone Schlüsselwörter bewusst höher und lauter."
                            : nil
                    )
                    insightRow(
                        icon: "⬇️",
                        label: "Satzende-Absenkung",
                        value: analysis.finalLoweringPresent ? "Vorhanden" : "Fehlt",
                        score: analysis.finalLoweringStrength,
                        tip: !analysis.finalLoweringPresent
                            ? "Senke deine Stimme am Ende bewusst ab. Nicht fragen – feststellen."
                            : nil
                    )
                    insightRow(
                        icon: "🎯",
                        label: "Bewusste Betonung",
                        value: emphasisLabel,
                        score: max(0, analysis.emphasisCorrelation * 100),
                        tip: analysis.emphasisCorrelation < 0.2
                            ? "Werde lauter UND höher gleichzeitig auf wichtigen Wörtern."
                            : nil
                    )
                    insightRow(
                        icon: "📉",
                        label: "Autorität (Downstep)",
                        value: analysis.downstepPresent ? "Erkannt" : "Nicht erkannt",
                        score: analysis.downstepStrength,
                        tip: !analysis.downstepPresent
                            ? "Beginne jeden neuen Gedanken etwas tiefer als den letzten."
                            : nil
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05)))
        .padding(.horizontal)
    }

    private func insightRow(icon: String, label: String, value: String, score: Double, tip: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(icon).font(.caption)
                Text(label).font(.caption).foregroundColor(.gray)
                Spacer()
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(scoreColor(score))
            }
            if let tip {
                Text("💡 \(tip)")
                    .font(.caption2)
                    .foregroundColor(.yellow.opacity(0.8))
                    .padding(.leading, 20)
            }
        }
    }

    private var emphasisLabel: String {
        if analysis.emphasisCorrelation > 0.3 { return "Stark" }
        if analysis.emphasisCorrelation > 0.15 { return "Moderat" }
        if analysis.emphasisCorrelation > 0 { return "Schwach" }
        return "Nicht erkannt"
    }

    private var intentionalityColor: Color {
        if analysis.intentionalityScore > 65 { return .green }
        if analysis.intentionalityScore > 40 { return .orange }
        return .red
    }

    private func scoreColor(_ score: Double) -> Color {
        if score > 65 { return .green }
        if score > 40 { return .orange }
        return .red.opacity(0.8)
    }
}
