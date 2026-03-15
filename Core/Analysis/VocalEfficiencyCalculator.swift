import Foundation

struct VocalEfficiencyResult {
    let efficiencyScore: Double
    let presencePerJitter: Double
    let warmthPerEffort: Double
    let category: EfficiencyCategory
    let trend: Double?
}

enum EfficiencyCategory: String, Codable {
    case efficient = "effizient"
    case balanced = "ausgewogen"
    case forceful = "angestrengt"
    case weak = "zurueckhaltend"

    var icon: String {
        switch self {
        case .efficient: return "✅"
        case .balanced: return "⚖️"
        case .forceful: return "💪"
        case .weak: return "🤫"
        }
    }

    var tip: String {
        switch self {
        case .efficient: return "Deine Stimme arbeitet effizient - gute Resonanz ohne Ueberanstrengung."
        case .balanced: return "Solide Technik. Mehr Brust-Resonanz koennte die Effizienz steigern."
        case .forceful: return "Du drueckst zu viel Luft. Versuch mit weniger Kraft klarer zu klingen."
        case .weak: return "Deine Stimme koennte mehr Praesenz vertragen. Oeffne den Mund weiter."
        }
    }
}

enum VocalEfficiencyCalculator {
    static func calculate(
        spectral: SpectralBandResult,
        jitter: Double,
        shimmer: Double,
        loudnessRMS: Double,
        loudnessOriginal: Double
    ) -> VocalEfficiencyResult {
        let presence = Double(spectral.presenceScore)
        let warmth = Double(spectral.warmthScore)
        let body = Double(spectral.bodyScore)

        let jitterNormalized = max(0.005, jitter)
        let presencePerJitter = presence / (jitterNormalized * 1000.0)

        let gainFactor = loudnessRMS / max(0.0001, loudnessOriginal)
        let warmthPerEffort = warmth / max(1.0, gainFactor)

        let jitterPenalty = max(0.0, (jitter - 0.020) / 0.015) * 25.0
        let shimmerPenalty = max(0.0, (shimmer - 0.15) / 0.05) * 15.0

        var score = presence * 0.4 + warmth * 0.3 + body * 0.3
        score -= jitterPenalty + shimmerPenalty
        score = min(100, max(0, score))

        let category: EfficiencyCategory
        if presence > 55 && jitter < 0.022 {
            category = .efficient
        } else if presence > 55 && jitter >= 0.022 {
            category = .forceful
        } else if presence <= 55 && jitter < 0.020 {
            category = .weak
        } else {
            category = .balanced
        }

        return VocalEfficiencyResult(
            efficiencyScore: score,
            presencePerJitter: presencePerJitter,
            warmthPerEffort: warmthPerEffort,
            category: category,
            trend: nil
        )
    }
}
