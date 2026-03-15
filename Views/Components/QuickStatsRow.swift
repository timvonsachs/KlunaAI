import SwiftUI

struct QuickStatsRow: View {
    let totalSessions: Int
    let bestScore: Double
    let streakWeeks: Int

    var body: some View {
        HStack(spacing: KlunaSpacing.md) {
            PremiumStatCard(value: "\(totalSessions)", label: L10n.sessions)
            PremiumStatCard(value: "\(Int(bestScore.rounded()))", label: L10n.best, valueColor: .forScore(bestScore))
            PremiumStatCard(
                value: "\(max(streakWeeks, 0))",
                label: L10n.streak,
                valueColor: streakWeeks > 0 ? .klunaOrange : .klunaMuted
            )
        }
    }
}

struct PremiumStatCard: View {
    let value: String
    let label: String
    var valueColor: Color = .klunaPrimary

    var body: some View {
        VStack(spacing: KlunaSpacing.xs) {
            Text(value)
                .font(KlunaFont.scoreDisplay(28))
                .foregroundColor(valueColor)
            Text(label)
                .font(KlunaFont.caption(11))
                .foregroundColor(.klunaMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }
}

