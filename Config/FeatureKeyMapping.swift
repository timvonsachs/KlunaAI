import Foundation

/// Canonical feature keys used across extraction, baseline and scoring.
enum FeatureKeys {
    // Legacy canonical keys
    static let f0Mean = "F0Mean"
    static let f0Variability = "F0Var"
    static let f0Range = "F0Range"
    static let jitter = "Jitter"
    static let shimmer = "Shimmer"
    static let energy = "Energy"
    static let loudness = energy
    static let hnr = "HNR"
    static let speechRate = "SpeechRate"
    static let f1 = "F1"
    static let f2 = "F2"
    static let f3 = "F3"
    static let f1Bandwidth = "F4"
    static let pauseDuration = "PauseDur"
    static let pauseDistribution = "PauseDist"

    // New benchmark-oriented keys
    static let f0RangeST = "f0RangeST"
    static let f0StdDev = "f0StdDev"
    static let loudnessRMS = "loudnessRMS"
    static let loudnessStdDev = "loudnessStdDev"
    static let loudnessDynamicRange = "loudnessDynamicRange"
    static let loudnessRMSOriginal = "loudnessRMSOriginal"
    static let loudnessStdDevOriginal = "loudnessStdDevOriginal"
    static let loudnessDynamicRangeOriginal = "loudnessDynamicRangeOriginal"
    static let gainFactor = "gainFactor"
    static let pauseRate = "pauseRate"
    static let meanPauseDuration = "meanPauseDuration"
    static let formantDispersion = "formantDispersion"
    static let articulationRate = "articulationRate"

    static let canonical: Set<String> = [
        f0Mean, f0Variability, f0Range, jitter, shimmer, energy, hnr, speechRate,
        f1, f2, f3, f1Bandwidth, pauseDuration, pauseDistribution,
        f0RangeST, f0StdDev, loudnessRMS, loudnessStdDev, loudnessDynamicRange,
        loudnessRMSOriginal, loudnessStdDevOriginal, loudnessDynamicRangeOriginal, gainFactor,
        pauseRate, meanPauseDuration, formantDispersion, articulationRate,
    ]

    /// Maps alternative/raw extractor keys to canonical keys.
    static let aliases: [String: String] = [
        "F0semitoneFrom27.5Hz_sma3nz_amean": f0Mean,
        "F0semitoneFrom27.5Hz_sma3nz_stddevNorm": f0Variability,
        "F0semitoneFrom27.5Hz_sma3nz_stddev": f0StdDev,
        "F0semitoneFrom27.5Hz_sma3nz_percentile99.0": "F0P99",
        "F0semitoneFrom27.5Hz_sma3nz_percentile1.0": "F0P01",
        "jitterLocal_sma3nz_amean": jitter,
        "shimmerLocaldB_sma3nz_amean": shimmer,
        "Loudness_sma3_amean": energy,
        "Loudness_sma3_stddevNorm": loudnessStdDev,
        "HNRdBACF_sma3nz_amean": hnr,
        "F1frequency_sma3nz_amean": f1,
        "F2frequency_sma3nz_amean": f2,
        "F3frequency_sma3nz_amean": f3,
        "F1bandwidth_sma3nz_amean": f1Bandwidth,
        "VoicedSegmentsPerSec": speechRate,
        "MeanUnvoicedSegmentLength": pauseDuration,
        "loudness": loudnessRMS,
        "energy": loudnessRMS,
        "loudnessRMSOriginal": loudnessRMSOriginal,
        "loudnessStdDevOriginal": loudnessStdDevOriginal,
        "loudnessDynamicRangeOriginal": loudnessDynamicRangeOriginal,
        "gainFactor": gainFactor,
        "meanPauseDuration": meanPauseDuration,
        "pauseRate": pauseRate,
        "formantDispersion": formantDispersion,
        "articulationRate": articulationRate,
    ]
}

enum FeatureKeyMapper {
    /// Normalizes incoming feature dictionaries to canonical keys.
    static func normalize(_ input: [String: Double]) -> [String: Double] {
        var normalized: [String: Double] = [:]
        var p99: Double?
        var p01: Double?

        for (key, value) in input {
            let mapped = FeatureKeys.aliases[key] ?? key
            if mapped == "F0P99" {
                p99 = value
                continue
            }
            if mapped == "F0P01" {
                p01 = value
                continue
            }
            normalized[mapped] = value
        }

        if normalized[FeatureKeys.f0Range] == nil, let p99, let p01 {
            normalized[FeatureKeys.f0Range] = p99 - p01
        }
        if normalized[FeatureKeys.f0RangeST] == nil {
            normalized[FeatureKeys.f0RangeST] = normalized[FeatureKeys.f0Range]
        }
        if normalized[FeatureKeys.loudnessRMS] == nil {
            normalized[FeatureKeys.loudnessRMS] = normalized[FeatureKeys.loudness]
        }
        if normalized[FeatureKeys.meanPauseDuration] == nil {
            normalized[FeatureKeys.meanPauseDuration] = normalized[FeatureKeys.pauseDuration]
        }
        if normalized[FeatureKeys.f0StdDev] == nil, let f0Var = normalized[FeatureKeys.f0Variability] {
            // F0Var in unserer Bridge ist bereits die Standardabweichung in Hz.
            normalized[FeatureKeys.f0StdDev] = max(0, f0Var)
        }
        if normalized[FeatureKeys.formantDispersion] == nil,
           let f1 = normalized[FeatureKeys.f1],
           let f4 = normalized[FeatureKeys.f1Bandwidth] {
            normalized[FeatureKeys.formantDispersion] = max(0, (f4 - f1) / 3.0)
        }
        if normalized[FeatureKeys.pauseRate] == nil, let pauseDist = normalized[FeatureKeys.pauseDistribution] {
            // Bridge writes PauseDist already as pauses/min.
            normalized[FeatureKeys.pauseRate] = max(0, pauseDist)
        }
        if normalized[FeatureKeys.articulationRate] == nil,
           let speechRate = normalized[FeatureKeys.speechRate],
           let pauseDur = normalized[FeatureKeys.meanPauseDuration] {
            let penalty = min(0.45, max(0.0, pauseDur * 0.2))
            normalized[FeatureKeys.articulationRate] = max(0, speechRate * (1.0 - penalty))
        }

        return normalized
    }
}
