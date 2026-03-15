import SwiftUI

struct ConsistencyBadge: View {
    let consistency: ConsistencyResult

    var body: some View {
        HStack(spacing: 8) {
            Text(consistency.masteryLevel.icon)
                .font(.caption)
            Text(consistency.masteryLevel.title)
                .font(KlunaFont.caption(12))
                .fontWeight(.medium)
                .foregroundColor(.klunaPrimary)

            if consistency.currentStreak > 1 {
                Text("·")
                    .foregroundColor(.klunaMuted)
                Text("🔥 \(consistency.currentStreak) Tage")
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaOrange)
            }

            if consistency.totalSessions >= 5 {
                Text("·")
                    .foregroundColor(.klunaMuted)
                Text("🎯 \(Int(consistency.overallConsistency))%")
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.klunaSurface)
                .overlay(Capsule().stroke(Color.klunaBorder, lineWidth: 1))
        )
    }
}
