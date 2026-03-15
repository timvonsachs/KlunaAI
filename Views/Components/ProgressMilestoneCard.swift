import SwiftUI

struct ProgressMilestoneCard: View {
    let initialScores: DimensionScores
    let currentScores: DimensionScores
    let totalSessions: Int
    let language: String

    var overallDelta: Double {
        currentScores.overall - initialScores.overall
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.md) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaGreen)
                Text(L10n.yourProgress)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaGreen)
                Spacer()
                Text(language == "de"
                    ? "Seit \(totalSessions) Sessions"
                    : "Over \(totalSessions) sessions"
                )
                .font(KlunaFont.caption(11))
                .foregroundColor(.klunaMuted)
            }

            HStack(spacing: KlunaSpacing.lg) {
                VStack(spacing: KlunaSpacing.xs) {
                    Text(L10n.firstSessions)
                        .font(KlunaFont.caption(10))
                        .foregroundColor(.klunaMuted)
                    Text("\(Int(initialScores.overall.rounded()))")
                        .font(KlunaFont.scoreDisplay(32))
                        .foregroundColor(.klunaMuted)
                }

                VStack(spacing: 2) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(overallDelta > 0 ? .klunaGreen : .klunaRed)
                    if overallDelta > 0 {
                        Text("+\(Int(overallDelta.rounded()))")
                            .font(KlunaFont.scoreDisplay(16))
                            .foregroundColor(.klunaGreen)
                    }
                }

                VStack(spacing: KlunaSpacing.xs) {
                    Text(L10n.now)
                        .font(KlunaFont.caption(10))
                        .foregroundColor(.klunaMuted)
                    Text("\(Int(currentScores.overall.rounded()))")
                        .font(KlunaFont.scoreDisplay(32))
                        .foregroundColor(.forScore(currentScores.overall))
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: KlunaSpacing.xs) {
                ForEach(dimensionDeltas(), id: \.dimension) { delta in
                    HStack {
                        Text(delta.dimension.localizedName)
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                        Spacer()
                        Text(String(format: "%+.0f", delta.change))
                            .font(KlunaFont.scoreDisplay(14))
                            .foregroundColor(delta.change >= 0 ? .klunaGreen : .klunaRed)
                    }
                }
            }
            .padding(KlunaSpacing.sm)
            .background(Color.klunaBackground)
            .cornerRadius(KlunaRadius.button)
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaGreen.opacity(0.2), lineWidth: 1)
        )
    }

    private func dimensionDeltas() -> [(dimension: PerformanceDimension, change: Double)] {
        PerformanceDimension.activeDimensions.map { dim in
            (dim, currentScores.value(for: dim) - initialScores.value(for: dim))
        }
        .sorted { abs($0.change) > abs($1.change) }
    }
}
