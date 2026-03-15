import Foundation
@testable import KlunaAI

enum TestFeatureFactory {
    static func calibrationFeatures(
        f0: Double = 130,
        speechRate: Double = 4.0,
        hnr: Double = 3.5,
        jitter: Double = 0.025,
        shimmer: Double = 0.16,
        f0Range: Double = 5.5,
        f0Var: Double = 10.0,
        pauseRate: Double = 25.0,
        pauseDur: Double = 0.4,
        articulationRate: Double = 7.0,
        loudnessRMS: Double = 0.06,
        dynamicRange: Double = 30.0,
        loudnessStdDev: Double = 0.01,
        formantDispersion: Double = 950.0,
        spectralWarmth: Double = 0.5,
        spectralPresence: Double = 0.006
    ) -> [String: Double] {
        [
            FeatureKeys.f0Mean: f0,
            FeatureKeys.f0RangeST: f0Range,
            FeatureKeys.f0StdDev: f0Var,
            FeatureKeys.jitter: jitter,
            FeatureKeys.shimmer: shimmer,
            FeatureKeys.hnr: hnr,
            FeatureKeys.speechRate: speechRate,
            FeatureKeys.articulationRate: articulationRate,
            FeatureKeys.pauseRate: pauseRate,
            FeatureKeys.pauseDuration: pauseDur,
            FeatureKeys.loudnessRMSOriginal: loudnessRMS,
            FeatureKeys.loudnessDynamicRangeOriginal: dynamicRange,
            FeatureKeys.loudnessStdDevOriginal: loudnessStdDev,
            FeatureKeys.formantDispersion: formantDispersion,
            "spectralWarmthRatio": spectralWarmth,
            "spectralPresenceRatio": spectralPresence,
        ]
    }
}
