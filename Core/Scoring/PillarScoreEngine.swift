import Foundation

struct PillarScores {
    let voiceQuality: Double
    let clarity: Double
    let dynamics: Double
    let rhythm: Double
    let qualityGate: Double
    let clarityGate: Double
    let overall: Double
    let voiceDNA: VoiceDNAProfile
}

enum PillarScoreEngine {
    static func calculatePillarScores(features: [String: Double], spectral: SpectralBandResult) -> PillarScores {
        let zJitter = zScore(value(features, keys: [FeatureKeys.jitter], fallback: 0.030), mean: 0.030, std: 0.012)
        let zShimmer = zScore(value(features, keys: [FeatureKeys.shimmer], fallback: 0.185), mean: 0.185, std: 0.035)
        let zHNR = zScore(value(features, keys: [FeatureKeys.hnr], fallback: 3.0), mean: 3.0, std: 0.6)

        let zLoudOrig = zScore(
            value(features, keys: [FeatureKeys.loudnessRMSOriginal, FeatureKeys.loudnessRMS, FeatureKeys.loudness], fallback: 0.004),
            mean: 0.004,
            std: 0.0015
        )
        let zDynOrig = zScore(
            value(features, keys: [FeatureKeys.loudnessDynamicRangeOriginal, FeatureKeys.loudnessDynamicRange], fallback: 17.0),
            mean: 17.0,
            std: 4.5
        )
        let zF0Range = zScore(value(features, keys: [FeatureKeys.f0RangeST, FeatureKeys.f0Range], fallback: 6.5), mean: 6.5, std: 1.5)
        let zF0StdDev = zScore(value(features, keys: [FeatureKeys.f0StdDev], fallback: 12.5), mean: 12.5, std: 2.5)

        let speechRate = value(features, keys: [FeatureKeys.speechRate], fallback: 4.2)
        let pauseDur = value(features, keys: [FeatureKeys.meanPauseDuration, FeatureKeys.pauseDuration], fallback: 0.4)
        let zPauseRate = zScore(value(features, keys: [FeatureKeys.pauseRate], fallback: 20.0), mean: 20.0, std: 7.0)
        let zArticulation = zScore(value(features, keys: [FeatureKeys.articulationRate], fallback: 6.5), mean: 6.5, std: 0.8)

        let sJitter = floored(sigmoidInv(zJitter))
        let sShimmer = floored(sigmoidInv(zShimmer))
        let sHNR = floored(sigmoid(zHNR))
        let voiceQuality = sJitter * 0.35 + sShimmer * 0.25 + sHNR * 0.40

        let sPresence = floored(Double(spectral.presenceScore))
        let sAir = floored(Double(spectral.airScore))
        let sBalance = floored(Double(spectral.spectralBalance))
        let sWarmth = floored(Double(spectral.warmthScore))
        let clarity = sPresence * 0.45 + sAir * 0.15 + sBalance * 0.15 + sWarmth * 0.25

        let sLoudOrig = floored(sigmoid(zLoudOrig))
        let sDynOrig = floored(sigmoid(zDynOrig))
        let sF0Range = floored(sigmoid(zF0Range))
        let sF0StdDev = floored(sigmoid(zF0StdDev))
        let dynamics = sLoudOrig * 0.35 + sDynOrig * 0.35 + sF0Range * 0.15 + sF0StdDev * 0.15
        let sLoudnessVariation = (sDynOrig * 0.6) + (sLoudOrig * 0.4)

        let sSpeechRate = floored(optimalRange(speechRate, low: 3.3, high: 4.8, dropoff: 1.2))
        let sPauseDur = floored(optimalRange(pauseDur, low: 0.3, high: 0.8, dropoff: 0.25))
        let sPauseRate = floored(sigmoid(zPauseRate))
        let sArticulation = floored(sigmoid(zArticulation))
        let rhythm = sSpeechRate * 0.30 + sPauseDur * 0.30 + sPauseRate * 0.20 + sArticulation * 0.20

        let qualityGate = min(1.0, voiceQuality / 40.0)
        let clarityGate = min(1.0, clarity / 25.0)
        let rawMean = voiceQuality * 0.25 + clarity * 0.25 + dynamics * 0.25 + rhythm * 0.25
        let overall = clamp(max(10.0, rawMean * qualityGate * clarityGate))
        let voiceDNA = VoiceDNA.calculateProfile(
            jitterScore: Float(sJitter),
            shimmerScore: Float(sShimmer),
            hnrScore: Float(sHNR),
            presenceScore: Float(sPresence),
            airScore: Float(sAir),
            bodyScore: Float(Double(spectral.bodyScore)),
            warmthScore: Float(sWarmth),
            loudnessScore: Float(sLoudOrig),
            dynamicRangeScore: Float(sDynOrig),
            f0RangeScore: Float(sF0Range),
            loudnessVariationScore: Float(sLoudnessVariation),
            speechRateScore: Float(sSpeechRate),
            pauseDurScore: Float(sPauseDur),
            pauseRateScore: Float(sPauseRate),
            articulationScore: Float(sArticulation),
            qualityGate: Float(qualityGate)
        )

        #if DEBUG
        print("🏛️ ═══ PILLAR SCORES ═══")
        print("🏛️ Voice Quality: \(Int(voiceQuality))  (J:\(Int(sJitter)) Sh:\(Int(sShimmer)) HNR:\(Int(sHNR)))")
        print("🏛️ Clarity:       \(Int(clarity))  (P:\(Int(sPresence)) A:\(Int(sAir)) B:\(Int(sBalance)) W:\(Int(sWarmth)))")
        print("🏛️ Dynamics:      \(Int(dynamics))  (L:\(Int(sLoudOrig)) D:\(Int(sDynOrig)) R:\(Int(sF0Range)) V:\(Int(sF0StdDev)))")
        print("🏛️ Rhythm:        \(Int(rhythm))  (SR:\(Int(sSpeechRate)) PD:\(Int(sPauseDur)) PR:\(Int(sPauseRate)) AR:\(Int(sArticulation)))")
        print("🏛️ ───────────────────────")
        print("🏛️ Raw Mean:      \(Int(rawMean))")
        print("🏛️ Quality Gate:  \(String(format: "%.2f", qualityGate))")
        print("🏛️ Clarity Gate:  \(String(format: "%.2f", clarityGate))")
        print("🏛️ ★ OVERALL:     \(Int(overall))")
        print("🏛️ ═══════════════════════")
        print("🧬 === VOICE DNA ===")
        print("🧬 Authority:  \(Int(voiceDNA.authority))")
        print("🧬 Charisma:   \(Int(voiceDNA.charisma))")
        print("🧬 Warmth:     \(Int(voiceDNA.warmth))")
        print("🧬 Composure:  \(Int(voiceDNA.composure))")
        print("🧬 Dominant:   \(voiceDNA.dominantQuadrant)")
        print("🧬 Growth:     \(voiceDNA.growthQuadrant)")
        print("🧬 ================")
        #endif

        return PillarScores(
            voiceQuality: voiceQuality,
            clarity: clarity,
            dynamics: dynamics,
            rhythm: rhythm,
            qualityGate: qualityGate,
            clarityGate: clarityGate,
            overall: overall,
            voiceDNA: voiceDNA
        )
    }

    static func calculateDimensions(pillars: PillarScores) -> DimensionScores {
        let confidence =
            pillars.voiceQuality * 0.35
            + pillars.clarity * 0.30
            + pillars.dynamics * 0.20
            + pillars.rhythm * 0.15

        let energy =
            pillars.dynamics * 0.45
            + pillars.clarity * 0.25
            + pillars.rhythm * 0.15
            + pillars.voiceQuality * 0.15

        let tempo =
            pillars.rhythm * 0.70
            + pillars.clarity * 0.15
            + pillars.dynamics * 0.15

        let gelassenheit =
            pillars.voiceQuality * 0.45
            + pillars.clarity * 0.20
            + pillars.rhythm * 0.20
            + pillars.dynamics * 0.15

        let charisma =
            pillars.clarity * 0.30
            + pillars.dynamics * 0.30
            + pillars.voiceQuality * 0.20
            + pillars.rhythm * 0.20

        return DimensionScores(
            confidence: clamp(max(10, confidence * pillars.qualityGate)),
            energy: clamp(max(10, energy * pillars.clarityGate)),
            tempo: clamp(max(10, tempo)),
            clarity: clamp(pillars.clarity),
            stability: clamp(max(10, gelassenheit * pillars.qualityGate)),
            charisma: clamp(max(10, charisma * pillars.qualityGate * pillars.clarityGate))
        )
    }

    private static func zScore(_ value: Double, mean: Double, std: Double) -> Double {
        guard std > 0 else { return 0 }
        return max(-4.0, min(4.0, (value - mean) / std))
    }

    private static func sigmoid(_ z: Double) -> Double {
        clamp(100.0 / (1.0 + exp(-1.2 * z)))
    }

    private static func sigmoidInv(_ z: Double) -> Double {
        sigmoid(-z)
    }

    private static func optimalRange(_ value: Double, low: Double, high: Double, dropoff: Double) -> Double {
        if value >= low && value <= high {
            let center = (low + high) / 2
            let halfRange = max(0.0001, (high - low) / 2)
            let dist = abs(value - center) / halfRange
            return clamp(100 - dist * 30)
        }
        let dist: Double = value < low ? (low - value) / dropoff : (value - high) / dropoff
        return max(5, 70 * exp(-dist * dist))
    }

    private static func floored(_ value: Double, minimum: Double = 8.0) -> Double {
        max(minimum, min(100, value))
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(100, value))
    }

    private static func value(_ features: [String: Double], keys: [String], fallback: Double) -> Double {
        for key in keys {
            if let v = features[key], v.isFinite {
                return v
            }
        }
        return fallback
    }
}
