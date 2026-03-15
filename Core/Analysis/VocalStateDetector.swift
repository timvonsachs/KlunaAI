import Foundation

enum VocalState: String, Codable, CaseIterable {
    case energized = "energetisch"
    case focused = "fokussiert"
    case tense = "angespannt"
    case tired = "muede"
    case relaxed = "entspannt"

    var icon: String {
        switch self {
        case .energized: return "⚡"
        case .focused: return "🎯"
        case .tense: return "😤"
        case .tired: return "😴"
        case .relaxed: return "😌"
        }
    }

    var coachingHint: String {
        switch self {
        case .energized: return "Guter Zustand fuer Praesentationen und Pitches."
        case .focused: return "Ideal fuer sachliche Gespraeche und Verhandlungen."
        case .tense: return "Atme tief durch. Sprich langsamer und tiefer."
        case .tired: return "Nicht der beste Zeitpunkt fuer wichtige Gespraeche. Aufwaermen hilft."
        case .relaxed: return "Gute Basis. Etwas mehr Dynamik wuerde Charisma steigern."
        }
    }
}

struct VocalStateResult {
    let primaryState: VocalState
    let confidence: Double
    let secondaryState: VocalState?
    let distances: [VocalState: Double]
}

final class VocalStateDetector {
    private struct StateCentroid {
        let state: VocalState
        let features: [Double]
    }

    private let centroids: [StateCentroid] = [
        StateCentroid(state: .energized, features: [0.08, 0.12, 0.25, 0.020, 0.5, 1.0, 1.0, 0.8, -0.5, 70.0]),
        StateCentroid(state: .focused, features: [0.07, 0.15, 0.30, 0.016, 0.0, 0.3, 0.3, 0.0, 0.3, 60.0]),
        StateCentroid(state: .tense, features: [0.10, 0.06, 0.15, 0.028, 1.0, 0.5, 0.5, 0.5, -0.8, 30.0]),
        StateCentroid(state: .tired, features: [0.04, 0.10, 0.30, 0.025, -0.5, -0.8, -0.8, -0.7, 0.5, 20.0]),
        StateCentroid(state: .relaxed, features: [0.06, 0.18, 0.35, 0.018, -0.3, 0.2, 0.0, -0.2, 0.2, 45.0])
    ]

    func detect(
        spectral: SpectralBandResult,
        bridgeFeatures: [String: Double],
        zScores: [String: Double],
        melodic: MelodicContourAnalysis?
    ) -> VocalStateResult {
        let vector: [Double] = [
            Double(spectral.presenceToTotalRatio),
            Double(spectral.bodyToTotalRatio),
            Double(spectral.warmthToPresenceRatio) / 20.0,
            bridgeFeatures[FeatureKeys.jitter] ?? bridgeFeatures["Jitter"] ?? 0.022,
            zScores[FeatureKeys.f0Mean] ?? zScores["F0Mean"] ?? 0,
            zScores[FeatureKeys.f0RangeST] ?? zScores[FeatureKeys.f0Range] ?? 0,
            zScores[FeatureKeys.loudnessStdDev] ?? 0,
            zScores[FeatureKeys.speechRate] ?? 0,
            zScores[FeatureKeys.meanPauseDuration] ?? zScores[FeatureKeys.pauseDuration] ?? 0,
            melodic?.hatPatternScore ?? 40.0
        ]

        var distances: [VocalState: Double] = [:]
        for centroid in centroids {
            var sum = 0.0
            for i in 0..<min(vector.count, centroid.features.count) {
                let diff = vector[i] - centroid.features[i]
                let weight: Double
                switch i {
                case 0, 1, 2: weight = 2.0
                case 3: weight = 2.0
                case 4, 9: weight = 1.5
                default: weight = 1.0
                }
                sum += diff * diff * weight
            }
            distances[centroid.state] = sqrt(sum)
        }

        let sorted = distances.sorted { $0.value < $1.value }
        guard let first = sorted.first else {
            return VocalStateResult(primaryState: .focused, confidence: 0, secondaryState: nil, distances: distances)
        }
        let second = sorted.count > 1 ? sorted[1] : nil

        let confidence: Double
        if let second, first.value > 0 {
            let ratio = second.value / first.value
            confidence = min(1.0, max(0.0, (ratio - 1.0) * 2.0))
        } else {
            confidence = 1.0
        }

        return VocalStateResult(
            primaryState: first.key,
            confidence: confidence,
            secondaryState: confidence < 0.4 ? second?.key : nil,
            distances: distances
        )
    }
}
