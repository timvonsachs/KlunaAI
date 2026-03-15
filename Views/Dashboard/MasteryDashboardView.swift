import SwiftUI

struct MasteryDashboardView: View {
    let consistency: ConsistencyResult

    var body: some View {
        VStack(spacing: 16) {
            MasteryLevelCard(
                level: consistency.masteryLevel,
                totalSessions: consistency.totalSessions,
                consistencyScore: consistency.overallConsistency
            )

            HStack(spacing: 12) {
                StatCard(icon: "🔥", value: "\(consistency.currentStreak)", label: "Tage-Streak")
                StatCard(icon: "🏆", value: "\(consistency.longestStreak)", label: "Rekord")
                StatCard(icon: "🎯", value: "\(Int(consistency.overallConsistency))", label: "Konsistenz")
            }

            if consistency.totalSessions >= 5 {
                DimensionConsistencyView(dimensions: consistency.dimensionConsistency)
            }
        }
    }
}

struct MasteryLevelCard: View {
    let level: MasteryLevel
    let totalSessions: Int
    let consistencyScore: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(level.icon).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.title)
                        .font(KlunaFont.heading(16))
                        .foregroundColor(.klunaPrimary)
                    Text(level.description)
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                }
                Spacer()
                Text("\(Int(consistencyScore))")
                    .font(KlunaFont.scoreLarge(20))
                    .foregroundColor(.klunaAccent)
            }

            if level != .expert {
                let nextThreshold = level.nextLevelSessions
                let progress = min(1.0, Double(totalSessions) / Double(nextThreshold))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Nächstes Level")
                            .font(KlunaFont.caption(11))
                            .foregroundColor(.klunaMuted)
                        Spacer()
                        Text("\(totalSessions)/\(nextThreshold) Sessions")
                            .font(KlunaFont.caption(11))
                            .foregroundColor(.klunaMuted)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.klunaSurfaceLight)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.klunaAccent.opacity(0.75))
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 8)
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

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(icon).font(.title3)
            Text(value)
                .font(KlunaFont.heading(18))
                .foregroundColor(.klunaPrimary)
            Text(label)
                .font(KlunaFont.caption(11))
                .foregroundColor(.klunaMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }
}

private struct DimensionConsistencyView: View {
    let dimensions: [String: DimensionConsistency]

    private let labels: [String: String] = [
        "confidence": "Confidence",
        "energy": "Energy",
        "tempo": "Tempo",
        "stability": "Gelassenheit",
        "charisma": "Charisma",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Konsistenz pro Dimension")
                .font(KlunaFont.caption(12))
                .foregroundColor(.klunaMuted)

            ForEach(sortedDimensions, id: \.key) { key, dim in
                HStack(spacing: 8) {
                    Text(labels[key] ?? key)
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaSecondary)
                        .frame(width: 76, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.klunaSurfaceLight)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(consistencyColor(dim.consistencyScore))
                                .frame(width: geo.size.width * min(1, dim.consistencyScore / 100))
                        }
                    }
                    .frame(height: 6)

                    Text("\(Int(dim.consistencyScore))")
                        .font(KlunaFont.caption(11))
                        .foregroundColor(.klunaMuted)
                        .frame(width: 24, alignment: .trailing)

                    Text(dim.trend > 1.5 ? "↗" : dim.trend < -1.5 ? "↘" : "→")
                        .font(KlunaFont.caption(11))
                        .foregroundColor(dim.trend > 1.5 ? .klunaGreen : dim.trend < -1.5 ? .klunaOrange : .klunaMuted)
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

    private var sortedDimensions: [(key: String, value: DimensionConsistency)] {
        let order = ["confidence", "energy", "tempo", "stability", "charisma"]
        return order.compactMap { key in
            guard let dim = dimensions[key] else { return nil }
            return (key: key, value: dim)
        }
    }

    private func consistencyColor(_ score: Double) -> Color {
        if score >= 70 { return .klunaGreen }
        if score >= 45 { return .klunaAmber }
        return .klunaOrange
    }
}
