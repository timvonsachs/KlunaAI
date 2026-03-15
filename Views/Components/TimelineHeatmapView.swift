import SwiftUI

struct TimelineHeatmapView: View {
    let segments: [HeatmapSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            Text(L10n.performanceOverTime)
                .font(KlunaFont.caption(13))
                .foregroundColor(.klunaMuted)

            HStack(spacing: 3) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.forScore(segment.scores.overall))
                        .frame(height: 40)
                        .overlay(
                            Text("\(Int(segment.scores.overall.rounded()))")
                                .font(KlunaFont.scoreDisplay(16))
                                .foregroundColor(.white)
                        )
                        .overlay(alignment: .topLeading) {
                            Text("\(index + 1)")
                                .font(KlunaFont.caption(10))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(4)
                        }
                }
            }

            HStack {
                Text(L10n.start)
                    .font(KlunaFont.caption(10))
                    .foregroundColor(.klunaMuted)
                Spacer()
                Text(L10n.end)
                    .font(KlunaFont.caption(10))
                    .foregroundColor(.klunaMuted)
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
