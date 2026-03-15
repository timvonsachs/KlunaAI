import SwiftUI

struct SpectralInsightsCard: View {
    let result: SpectralBandResult
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.purple)
                    Text("Stimmklang")
                        .font(KlunaFont.caption(13))
                        .fontWeight(.semibold)
                        .foregroundColor(.klunaPrimary)
                    Spacer()
                    Text("\(Int(result.overallTimbreScore))")
                        .font(KlunaFont.caption(13))
                        .fontWeight(.bold)
                        .foregroundColor(timbreColor)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.klunaMuted)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    Divider().background(Color.klunaBorder)

                    SpectralBandBar(
                        label: "Wärme",
                        detail: "200-500 Hz",
                        score: result.warmthScore,
                        color: .orange,
                        tip: warmthTip
                    )
                    SpectralBandBar(
                        label: "Körper",
                        detail: "80-200 Hz",
                        score: result.bodyScore,
                        color: .red,
                        tip: bodyTip
                    )
                    SpectralBandBar(
                        label: "Präsenz",
                        detail: "2-5 kHz",
                        score: result.presenceScore,
                        color: .cyan,
                        tip: presenceTip
                    )
                    SpectralBandBar(
                        label: "Brillanz",
                        detail: "6+ kHz",
                        score: result.airScore,
                        color: .blue,
                        tip: airTip
                    )

                    HStack {
                        Text("Balance")
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                        Spacer()
                        Text("\(Int(result.spectralBalance))%")
                            .font(KlunaFont.caption(12))
                            .fontWeight(.medium)
                            .foregroundColor(.klunaSecondary)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.klunaSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.klunaBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, KlunaSpacing.md)
    }

    private var warmthTip: String? {
        if result.warmthScore < 40 { return "Sprich etwas tiefer und entspannter." }
        if result.warmthScore > 90 { return "Sehr warme Stimme - achte auf Deutlichkeit." }
        return nil
    }

    private var bodyTip: String? {
        if result.bodyScore < 40 { return "Mehr aus der Brust heraus sprechen." }
        return nil
    }

    private var presenceTip: String? {
        if result.presenceScore < 40 { return "Mund weiter öffnen und Konsonanten klarer sprechen." }
        if result.presenceScore < 60 { return "Etwas deutlicher artikulieren." }
        return nil
    }

    private var airTip: String? {
        if result.airScore < 20 { return "Die Stimmgebung klingt etwas dumpf." }
        return nil
    }

    private var timbreColor: Color {
        if result.overallTimbreScore >= 70 { return .klunaGreen }
        if result.overallTimbreScore >= 50 { return .klunaAmber }
        return .klunaOrange
    }
}

struct SpectralBandBar: View {
    let label: String
    let detail: String
    let score: Float
    let color: Color
    let tip: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(KlunaFont.caption(12))
                    .fontWeight(.medium)
                    .foregroundColor(.klunaPrimary)
                Text(detail)
                    .font(KlunaFont.caption(11))
                    .foregroundColor(.klunaMuted)
                Spacer()
                Text("\(Int(score))")
                    .font(KlunaFont.caption(12))
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.klunaSurfaceLight)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.7))
                        .frame(width: geo.size.width * CGFloat(score / 100))
                }
            }
            .frame(height: 6)

            if let tip {
                Text("Tipp: \(tip)")
                    .font(KlunaFont.caption(11))
                    .foregroundColor(.klunaMuted)
            }
        }
    }

    private var scoreColor: Color {
        if score >= 70 { return .klunaGreen }
        if score >= 50 { return .klunaAmber }
        return .klunaOrange
    }
}
