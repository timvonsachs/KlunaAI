import SwiftUI

struct PersonalBestCard: View {
    let currentScores: DimensionScores
    let bestScores: DimensionScores
    let bestDate: Date
    let bestPitchType: String
    let language: String

    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.md) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaGold)
                Text(L10n.yourPersonalBest)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaGold)
                Spacer()
                Text(bestDate.shortFormat)
                    .font(KlunaFont.caption(11))
                    .foregroundColor(.klunaMuted)
            }

            VStack(spacing: KlunaSpacing.sm) {
                ComparisonRow(label: L10n.overallScore, current: currentScores.overall, best: bestScores.overall)
                ForEach(topGaps(limit: 3), id: \.dimension) { gap in
                    ComparisonRow(
                        label: gap.dimension.localizedName,
                        current: gap.current,
                        best: gap.best
                    )
                }
            }

            if let biggestGap = topGaps(limit: 1).first {
                HStack(spacing: KlunaSpacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.klunaAmber)
                    Text(insightText(gap: biggestGap, language: language))
                        .font(KlunaFont.body(13))
                        .foregroundColor(.klunaSecondary)
                        .lineSpacing(2)
                }
                .padding(KlunaSpacing.sm)
                .background(Color.klunaAmber.opacity(0.08))
                .cornerRadius(KlunaRadius.button)
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaGold.opacity(0.2), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(KlunaAnimation.spring.delay(0.3)) {
                visible = true
            }
        }
    }

    private func topGaps(limit: Int) -> [DimensionGap] {
        return PerformanceDimension.activeDimensions
            .map { dim in
                DimensionGap(
                    dimension: dim,
                    current: currentScores.value(for: dim),
                    best: bestScores.value(for: dim)
                )
            }
            .sorted { abs($0.best - $0.current) > abs($1.best - $1.current) }
            .prefix(limit)
            .map { $0 }
    }

    private func insightText(gap: DimensionGap, language: String) -> String {
        let diff = Int(gap.best - gap.current)
        let dimName = gap.dimension.localizedName
        if diff > 10 {
            return language == "de"
                ? "Dein \(dimName) war bei deinem Besten \(diff) Punkte hoeher. Das kannst du wieder erreichen."
                : "Your \(dimName) was \(diff) points higher at your best. You can reach that again."
        } else if diff > 0 {
            return language == "de"
                ? "Dein \(dimName) ist nah an deinem Besten – nur noch \(diff) Punkte."
                : "Your \(dimName) is close to your best – just \(diff) points away."
        } else {
            return language == "de"
                ? "Dein \(dimName) ist heute besser als je zuvor! Neues Personal Best."
                : "Your \(dimName) is better than ever today! New personal best."
        }
    }
}

struct DimensionGap {
    let dimension: PerformanceDimension
    let current: Double
    let best: Double
}

struct ComparisonRow: View {
    let label: String
    let current: Double
    let best: Double

    @State private var animatedCurrent: CGFloat = 0
    @State private var animatedBest: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaMuted)
                Spacer()
                Text("\(Int(current.rounded()))")
                    .font(KlunaFont.scoreDisplay(14))
                    .foregroundColor(.forScore(current))
                Text("/ \(Int(best.rounded()))")
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaGold.opacity(0.7))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.klunaSurfaceLight)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.klunaGold.opacity(0.3))
                        .frame(width: geo.size.width * (animatedBest / 100), height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.forScore(current))
                        .frame(width: geo.size.width * (animatedCurrent / 100), height: 6)
                }
            }
            .frame(height: 6)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                    animatedCurrent = current
                    animatedBest = best
                }
            }
        }
    }
}
