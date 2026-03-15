import Foundation
import CoreData

final class DimensionScorer {
    private let baselineEngine: BaselineEngine
    
    init(baselineEngine: BaselineEngine) {
        self.baselineEngine = baselineEngine
    }
    
    func score(features: VoiceFeatures, voiceType: VoiceType, context: NSManagedObjectContext) -> DimensionScores {
        score(features: features.asDictionary, voiceType: voiceType, context: context)
    }

    func score(features: [String: Double], voiceType: VoiceType, context: NSManagedObjectContext) -> DimensionScores {
        let rawFeatures = FeatureKeyMapper.normalize(features)
        let zScores = baselineEngine.calculateAllZScores(for: rawFeatures, voiceType: voiceType, context: context)
        return score(rawFeatures: rawFeatures, zScores: zScores, segmentFeatures: nil, spectral: nil, vocalState: nil, efficiency: nil)
    }

    func score(rawFeatures: [String: Double], zScores: [String: Double]) -> DimensionScores {
        score(rawFeatures: rawFeatures, zScores: zScores, segmentFeatures: nil, spectral: nil, vocalState: nil, efficiency: nil)
    }

    func score(rawFeatures: [String: Double], zScores: [String: Double], segmentFeatures: [[String: Double]]?) -> DimensionScores {
        score(rawFeatures: rawFeatures, zScores: zScores, segmentFeatures: segmentFeatures, spectral: nil, vocalState: nil, efficiency: nil)
    }

    func score(
        rawFeatures: [String: Double],
        zScores: [String: Double],
        segmentFeatures: [[String: Double]]?,
        spectral: SpectralBandResult?,
        vocalState: VocalStateResult? = nil,
        efficiency: VocalEfficiencyResult? = nil
    ) -> DimensionScores {
        let normalizedRaw = FeatureKeyMapper.normalize(rawFeatures)
        let _ = zScores
        let _ = segmentFeatures
        let _ = vocalState
        let _ = efficiency

        let spectralResult = spectral ?? .zero
        let pillars = PillarScoreEngine.calculatePillarScores(features: normalizedRaw, spectral: spectralResult)
        return PillarScoreEngine.calculateDimensions(pillars: pillars)
    }

    func score(zScores: [String: Double]) -> DimensionScores {
        let neutralRaw = synthesizedRawFromZ(zScores)
        return score(rawFeatures: neutralRaw, zScores: zScores)
    }

    func heatmap(segments: [VoiceFeatures], voiceType: VoiceType, context: NSManagedObjectContext) -> HeatmapData {
        guard !segments.isEmpty else { return HeatmapData(segments: []) }
        let count = segments.count
        let segmentDictionaries = segments.map { FeatureKeyMapper.normalize($0.asDictionary) }
        let scored: [HeatmapSegment] = segments.enumerated().map { index, segment in
            let start = Double(index) / Double(count)
            let end = Double(index + 1) / Double(count)
            let raw = FeatureKeyMapper.normalize(segment.asDictionary)
            let z = baselineEngine.calculateAllZScores(for: raw, voiceType: voiceType, context: context)
            let scores = score(rawFeatures: raw, zScores: z, segmentFeatures: segmentDictionaries)
            return HeatmapSegment(startTime: start, endTime: end, scores: scores)
        }
        return HeatmapData(segments: scored)
    }

    func heatmapScores(segments: [[String: Double]], voiceType: VoiceType, context: NSManagedObjectContext) -> HeatmapData {
        guard !segments.isEmpty else { return HeatmapData(segments: []) }
        let normalizedSegments = segments.map { FeatureKeyMapper.normalize($0) }
        let count = segments.count
        let scored: [HeatmapSegment] = segments.enumerated().map { index, segment in
            let start = Double(index) / Double(count)
            let end = Double(index + 1) / Double(count)
            let raw = FeatureKeyMapper.normalize(segment)
            let z = baselineEngine.calculateAllZScores(for: raw, voiceType: voiceType, context: context)
            let scores = score(rawFeatures: raw, zScores: z, segmentFeatures: normalizedSegments)
            return HeatmapSegment(startTime: start, endTime: end, scores: scores)
        }
        return HeatmapData(segments: scored)
    }

    // MARK: - Absolute Quality

    private func calculateAbsoluteScores(
        features: [String: Double],
        segmentFeatures: [[String: Double]]?,
        spectral: SpectralBandResult?
    ) -> RawDimensionValues {
        RawDimensionValues(
            confidence: calculateConfidence(features: features, spectral: spectral),
            energy: calculateEnergy(features: features),
            tempo: calculateTempo(features: features),
            clarity: calculateClarity(features: features, spectral: spectral),
            stability: calculateStability(features: features, segmentFeatures: segmentFeatures),
            charisma: calculateCharisma(features: features, spectral: spectral)
        )
    }

    // MARK: - Personal Progress

    private func calculateProgressScores(zScores: [String: Double]) -> RawDimensionValues {
        let f0VarZ = zScores[FeatureKeys.f0Variability] ?? 0
        let f0RangeZ = zScores[FeatureKeys.f0RangeST] ?? zScores[FeatureKeys.f0Range] ?? 0
        let jitterZ = zScores[FeatureKeys.jitter] ?? 0
        let shimmerZ = zScores[FeatureKeys.shimmer] ?? 0
        let loudnessZ = zScores[FeatureKeys.loudnessRMS] ?? zScores[FeatureKeys.loudness] ?? 0
        let hnrZ = zScores[FeatureKeys.hnr] ?? 0
        let speechRateZ = zScores[FeatureKeys.speechRate] ?? 0
        let pauseZ = zScores[FeatureKeys.meanPauseDuration] ?? zScores[FeatureKeys.pauseDuration] ?? 0

        let confidence = normalize(hnrZ * 0.25 + (-jitterZ) * 0.2 + (-shimmerZ) * 0.2 + uCurveZ(f0VarZ) * 0.2 + loudnessZ * 0.15)
        let energy = normalize(loudnessZ * 0.35 + f0RangeZ * 0.3 + uCurveZ(speechRateZ) * 0.15 + uCurveZ(pauseZ) * 0.2)
        let tempo = normalize(uCurveZ(speechRateZ) * 0.6 + uCurveZ(pauseZ) * 0.4)
        let clarity = normalize(uCurveZ(speechRateZ) * 0.5 + uCurveZ(pauseZ) * 0.5)
        let stability = normalize((-jitterZ) * 0.3 + (-shimmerZ) * 0.25 + (-abs(f0VarZ)) * 0.2 + loudnessZ * 0.25)
        let charisma = normalize(f0RangeZ * 0.3 + loudnessZ * 0.2 + uCurveZ(pauseZ) * 0.2 + hnrZ * 0.1 + uCurveZ(speechRateZ) * 0.2)

        return RawDimensionValues(
            confidence: confidence,
            energy: energy,
            tempo: tempo,
            clarity: clarity,
            stability: stability,
            charisma: charisma
        )
    }

    // MARK: - New Dimension Logic

    private func calculateConfidence(features: [String: Double], spectral: SpectralBandResult?) -> Double {
        let f0Mean = value(features, keys: [FeatureKeys.f0Mean], default: 110)
        let jitter = value(features, keys: [FeatureKeys.jitter], default: 0.023)
        let loud = value(features, keys: [FeatureKeys.loudnessRMS, FeatureKeys.loudness], default: 0.05)
        let hnr = value(features, keys: [FeatureKeys.hnr], default: 3.2)
        let warmth = Double(spectral?.warmthScore ?? 50)
        let body = Double(spectral?.bodyScore ?? 50)

        let score = featureScore(key: FeatureKeys.f0Mean, value: f0Mean) * 0.25
            + featureScore(key: FeatureKeys.jitter, value: jitter) * 0.25
            + featureScore(key: FeatureKeys.loudnessRMS, value: loud) * 0.25
            + featureScore(key: FeatureKeys.hnr, value: hnr) * 0.15
            + warmth * 0.05
            + body * 0.05

        return clamp(score)
    }

    private func calculateEnergy(features: [String: Double]) -> Double {
        let loud = value(features, keys: [FeatureKeys.loudnessRMS, FeatureKeys.loudness], default: 0.05)
        let loudStd = value(features, keys: [FeatureKeys.loudnessStdDev], default: 0.035)
        let f0Range = value(features, keys: [FeatureKeys.f0RangeST, FeatureKeys.f0Range], default: 6.5)
        let speechRate = value(features, keys: [FeatureKeys.speechRate], default: 3.8)
        let artic = value(features, keys: [FeatureKeys.articulationRate], default: 6.2)

        let score = featureScore(key: FeatureKeys.loudnessRMS, value: loud) * 0.30
            + featureScore(key: FeatureKeys.loudnessStdDev, value: loudStd) * 0.25
            + featureScore(key: FeatureKeys.f0Range, value: f0Range) * 0.20
            + featureScore(key: FeatureKeys.speechRate, value: speechRate) * 0.15
            + featureScore(key: FeatureKeys.articulationRate, value: artic) * 0.10

        return clamp(score)
    }

    private func calculateTempo(features: [String: Double]) -> Double {
        let speechRate = value(features, keys: [FeatureKeys.speechRate], default: 4.0)
        let pauseRate = value(features, keys: [FeatureKeys.pauseRate], default: 22.0)
        let meanPauseDuration = value(features, keys: [FeatureKeys.meanPauseDuration, FeatureKeys.pauseDuration], default: 0.5)
        let articulationRate = value(features, keys: [FeatureKeys.articulationRate], default: 6.2)

        let score = featureScore(key: FeatureKeys.speechRate, value: speechRate) * 0.35
            + featureScore(key: FeatureKeys.pauseRate, value: pauseRate) * 0.30
            + featureScore(key: FeatureKeys.meanPauseDuration, value: meanPauseDuration) * 0.25
            + featureScore(key: FeatureKeys.articulationRate, value: articulationRate) * 0.10

        return clamp(score)
    }

    private func calculateClarity(features: [String: Double], spectral: SpectralBandResult?) -> Double {
        let articulation = value(features, keys: [FeatureKeys.articulationRate], default: 6.2)
        let speechRate = value(features, keys: [FeatureKeys.speechRate], default: 3.9)
        let presence = Double(spectral?.presenceScore ?? 50)
        let warmth = Double(spectral?.warmthScore ?? 50)
        let air = Double(spectral?.airScore ?? 50)

        let score = presence * 0.40
            + warmth * 0.15
            + featureScore(key: FeatureKeys.articulationRate, value: articulation) * 0.20
            + featureScore(key: FeatureKeys.speechRate, value: speechRate) * 0.15
            + air * 0.10

        return clamp(score)
    }

    private func calculateStability(features: [String: Double], segmentFeatures: [[String: Double]]?) -> Double {
        let jitter = value(features, keys: [FeatureKeys.jitter], default: 0.03)
        let shimmer = value(features, keys: [FeatureKeys.shimmer], default: 0.05)
        let loudness = value(features, keys: [FeatureKeys.loudnessRMS, FeatureKeys.loudness], default: 0.3)
        _ = segmentFeatures // reserved for future temporal stability tuning

        let jitterScore = featureScore(key: FeatureKeys.jitter, value: jitter)
        let shimmerScore = featureScore(key: FeatureKeys.shimmer, value: shimmer)
        let microStabilityScore = (jitterScore + shimmerScore) / 2
        let energyGate = featureScore(key: FeatureKeys.loudnessRMS, value: loudness)

        let energyPenalty: Double
        if loudness < 0.02 {
            energyPenalty = 0.45
        } else if loudness < 0.035 {
            energyPenalty = 0.75
        } else {
            energyPenalty = 1.0
        }

        let rawStability = jitterScore * 0.40
            + featureScore(key: FeatureKeys.hnr, value: value(features, keys: [FeatureKeys.hnr], default: 3.2)) * 0.25
            + energyGate * 0.20
            + shimmerScore * 0.15

        return clamp(rawStability * energyPenalty)
    }

    private func calculateCharisma(features: [String: Double], spectral: SpectralBandResult?) -> Double {
        let f0Range = value(features, keys: [FeatureKeys.f0RangeST, FeatureKeys.f0Range], default: 6.5)
        let f0StdDev = value(features, keys: [FeatureKeys.f0StdDev], default: 13)
        let loudnessStdDev = value(features, keys: [FeatureKeys.loudnessStdDev], default: 0.035)
        let pauseRate = value(features, keys: [FeatureKeys.pauseRate], default: 22)
        let pauseDur = value(features, keys: [FeatureKeys.meanPauseDuration, FeatureKeys.pauseDuration], default: 0.6)
        let f0Mean = value(features, keys: [FeatureKeys.f0Mean], default: 110)
        let loudness = value(features, keys: [FeatureKeys.loudnessRMS, FeatureKeys.loudness], default: 0.05)

        let timbre = Double(spectral?.overallTimbreScore ?? 50)

        let raw = featureScore(key: FeatureKeys.f0Range, value: f0Range) * 0.22
            + featureScore(key: FeatureKeys.loudnessStdDev, value: loudnessStdDev) * 0.18
            + featureScore(key: FeatureKeys.f0StdDev, value: f0StdDev) * 0.13
            + featureScore(key: FeatureKeys.pauseRate, value: pauseRate) * 0.12
            + featureScore(key: FeatureKeys.meanPauseDuration, value: pauseDur) * 0.10
            + featureScore(key: FeatureKeys.f0Mean, value: f0Mean) * 0.08
            + featureScore(key: FeatureKeys.loudnessRMS, value: loudness) * 0.05
            + timbre * 0.12

        let monotonyPenalty: Double
        if f0Range < 5.0 && loudnessStdDev < 0.020 {
            monotonyPenalty = 0.35
        } else if f0Range < 6.0 && loudnessStdDev < 0.025 {
            monotonyPenalty = 0.60
        } else {
            monotonyPenalty = 1.0
        }
        return clamp(raw * monotonyPenalty)
    }

    private func calculateOverall(
        confidence: Double,
        energy: Double,
        tempo: Double,
        stability: Double,
        charisma: Double
    ) -> Double {
        let weighted = confidence * 0.22
            + energy * 0.18
            + tempo * 0.15
            + stability * 0.18
            + charisma * 0.27

        return clamp(weighted)
    }

    private func normalize(_ compositeZ: Double) -> Double {
        clamp(50 + compositeZ * 16)
    }

    private func zScoreToSubscore(_ z: Double, inverted: Bool = false) -> Double {
        let effectiveZ = inverted ? -z : z
        let score = 100.0 / (1.0 + exp(-1.2 * effectiveZ))
        return clamp(score)
    }

    private func optimalRangeSubscore(
        value: Double,
        optimalLow: Double,
        optimalHigh: Double,
        dropoff: Double
    ) -> Double {
        if value >= optimalLow && value <= optimalHigh {
            let center = (optimalLow + optimalHigh) / 2
            let halfRange = max(0.0001, (optimalHigh - optimalLow) / 2)
            let distFromCenter = abs(value - center) / halfRange
            return clamp(100 - distFromCenter * 30)
        }

        let distFromOptimal: Double
        if value < optimalLow {
            distFromOptimal = (optimalLow - value) / max(0.0001, dropoff)
        } else {
            distFromOptimal = (value - optimalHigh) / max(0.0001, dropoff)
        }
        return clamp(max(5, 70 * exp(-distFromOptimal * distFromOptimal)))
    }

    private func uCurveZ(_ z: Double) -> Double {
        -min(abs(z), 3.0)
    }

    private func blend(absolute: Double, progress: Double, wa: Double, wp: Double) -> Double {
        absolute * wa + progress * wp
    }

    private func featureScore(key: String, value: Double) -> Double {
        guard let range = Self.scoringRanges[key] else { return 50 }
        return clamp(range.score(value))
    }

    private func monotonyPenalty(features: [String: Double]) -> Double {
        let f0StdDev = value(features, keys: [FeatureKeys.f0StdDev], default: 18)
        let speechRate = value(features, keys: [FeatureKeys.speechRate], default: 4.0)
        let pauseRate = value(features, keys: [FeatureKeys.pauseRate], default: 20)
        let hnr = value(features, keys: [FeatureKeys.hnr], default: 3.2)
        let jitter = value(features, keys: [FeatureKeys.jitter], default: 0.07)

        let lowPitchVariance = f0StdDev < 18.0
        let slowDelivery = speechRate < 3.7
        let tooManyPauses = pauseRate > 22.0
        let weakVoiceQuality = hnr < 3.25
        let unstablePhonation = jitter > 0.08

        var penalty = 1.0
        if lowPitchVariance { penalty *= 0.78 }
        if slowDelivery { penalty *= 0.85 }
        if tooManyPauses { penalty *= 0.90 }
        if weakVoiceQuality { penalty *= 0.90 }
        if unstablePhonation { penalty *= 0.90 }
        if lowPitchVariance && slowDelivery { penalty *= 0.82 }
        if slowDelivery && tooManyPauses { penalty *= 0.82 }

        return max(0.40, min(1.0, penalty))
    }

    private func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private func value(_ features: [String: Double], keys: [String], default fallback: Double) -> Double {
        for key in keys {
            if let value = features[key], value.isFinite {
                return value
            }
        }
        return fallback
    }

    private func optimalRangeScore(
        value: Double,
        optimalLow: Double,
        optimalHigh: Double,
        poorLow: Double,
        poorHigh: Double?
    ) -> Double {
        if value >= optimalLow && value <= optimalHigh {
            let rangeWidth = max(0.0001, optimalHigh - optimalLow)
            let center = optimalLow + rangeWidth / 2
            let distanceFromCenter = abs(value - center) / max(0.0001, rangeWidth / 2)
            return clamp(100 - (distanceFromCenter * 30))
        }

        if value < optimalLow {
            let range = optimalLow - poorLow
            if range <= 0 { return 0 }
            let ratio = max(0, min(1, (value - poorLow) / range))
            return clamp(ratio * 70)
        }

        if let poorHigh, value > optimalHigh {
            let range = poorHigh - optimalHigh
            if range <= 0 { return 0 }
            let ratio = max(0, min(1, 1 - (value - optimalHigh) / range))
            return clamp(ratio * 70)
        }

        return clamp(max(0, 70 - (value - optimalHigh) * 2))
    }

    private struct FeatureScoringRange {
        let poorLow: Double
        let optimalLow: Double
        let optimalHigh: Double
        let poorHigh: Double
        let inverted: Bool

        func score(_ value: Double) -> Double {
            if inverted {
                if value <= optimalLow { return 100 }
                if value >= poorHigh { return 0 }
                if value <= optimalHigh {
                    let ratio = (value - optimalLow) / max(1e-6, (optimalHigh - optimalLow))
                    return 100 - ratio * 20
                }
                let ratio = (value - optimalHigh) / max(1e-6, (poorHigh - optimalHigh))
                return 80 * (1 - ratio)
            }

            if value >= optimalLow && value <= optimalHigh { return 100 }
            if value < poorLow || value > poorHigh { return 0 }
            if value < optimalLow {
                let ratio = (value - poorLow) / max(1e-6, (optimalLow - poorLow))
                return ratio * 100
            }
            let ratio = (value - optimalHigh) / max(1e-6, (poorHigh - optimalHigh))
            return 100 * (1 - ratio)
        }
    }

    private static let scoringRanges: [String: FeatureScoringRange] = [
        FeatureKeys.loudnessRMS: .init(poorLow: 0.015, optimalLow: 0.045, optimalHigh: 0.10, poorHigh: 0.20, inverted: false),
        FeatureKeys.loudnessStdDev: .init(poorLow: 0.005, optimalLow: 0.025, optimalHigh: 0.08, poorHigh: 0.15, inverted: false),
        FeatureKeys.f0Mean: .init(poorLow: 70, optimalLow: 95, optimalHigh: 145, poorHigh: 200, inverted: false),
        FeatureKeys.f0Range: .init(poorLow: 2, optimalLow: 6, optimalHigh: 15, poorHigh: 22, inverted: false),
        FeatureKeys.f0RangeST: .init(poorLow: 2, optimalLow: 6, optimalHigh: 15, poorHigh: 22, inverted: false),
        FeatureKeys.f0StdDev: .init(poorLow: 3, optimalLow: 10, optimalHigh: 35, poorHigh: 55, inverted: false),
        FeatureKeys.jitter: .init(poorLow: 0.0, optimalLow: 0.003, optimalHigh: 0.025, poorHigh: 0.06, inverted: true),
        FeatureKeys.shimmer: .init(poorLow: 0.0, optimalLow: 0.08, optimalHigh: 0.18, poorHigh: 0.28, inverted: true),
        FeatureKeys.hnr: .init(poorLow: 1.5, optimalLow: 2.7, optimalHigh: 4.0, poorHigh: 5.5, inverted: false),
        FeatureKeys.speechRate: .init(poorLow: 2.0, optimalLow: 3.3, optimalHigh: 4.8, poorHigh: 6.5, inverted: false),
        FeatureKeys.pauseRate: .init(poorLow: 5, optimalLow: 12, optimalHigh: 30, poorHigh: 50, inverted: false),
        FeatureKeys.meanPauseDuration: .init(poorLow: 0.1, optimalLow: 0.3, optimalHigh: 1.0, poorHigh: 2.5, inverted: false),
        FeatureKeys.articulationRate: .init(poorLow: 3.0, optimalLow: 4.5, optimalHigh: 7.0, poorHigh: 9.0, inverted: false),
    ]

    private func synthesizedRawFromZ(_ zScores: [String: Double]) -> [String: Double] {
        // Fallback for legacy tests that call score(zScores:).
        let z = FeatureKeyMapper.normalize(zScores)
        return [
            FeatureKeys.f0Mean: 150 + (z[FeatureKeys.f0Mean] ?? 0) * 20,
            FeatureKeys.f0RangeST: 12 + (z[FeatureKeys.f0RangeST] ?? z[FeatureKeys.f0Range] ?? 0) * 4,
            FeatureKeys.f0StdDev: 35 + (z[FeatureKeys.f0StdDev] ?? z[FeatureKeys.f0Variability] ?? 0) * 8,
            FeatureKeys.jitter: 0.015 + (z[FeatureKeys.jitter] ?? 0) * 0.005,
            FeatureKeys.shimmer: 0.045 + (z[FeatureKeys.shimmer] ?? 0) * 0.015,
            FeatureKeys.hnr: 18 + (z[FeatureKeys.hnr] ?? 0) * 3,
            FeatureKeys.loudnessRMS: 0.45 + (z[FeatureKeys.loudnessRMS] ?? z[FeatureKeys.loudness] ?? 0) * 0.1,
            FeatureKeys.loudnessStdDev: 0.12 + (z[FeatureKeys.loudnessStdDev] ?? 0) * 0.04,
            FeatureKeys.speechRate: 4.0 + (z[FeatureKeys.speechRate] ?? 0) * 0.4,
            FeatureKeys.pauseRate: 3.0 + (z[FeatureKeys.pauseRate] ?? 0) * 1.0,
            FeatureKeys.meanPauseDuration: 0.8 + (z[FeatureKeys.meanPauseDuration] ?? z[FeatureKeys.pauseDuration] ?? 0) * 0.3,
            FeatureKeys.articulationRate: 4.7 + (z[FeatureKeys.articulationRate] ?? 0) * 0.5,
        ]
    }
}

private struct RawDimensionValues {
    let confidence: Double
    let energy: Double
    let tempo: Double
    let clarity: Double
    let stability: Double
    let charisma: Double
}
