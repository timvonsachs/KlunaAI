import Foundation

enum PopulationBaseline {
    static func values(for voiceType: VoiceType) -> [String: (mean: Double, stddev: Double)] {
        switch voiceType {
        case .deep:
            return deepVoiceBaseline
        case .mid:
            return midVoiceBaseline
        case .high:
            return highVoiceBaseline
        }
    }

    private static func makeBaseline(f0Mean: Double) -> [String: (mean: Double, stddev: Double)] {
        [
            FeatureKeys.loudnessRMSOriginal: (mean: 0.004, stddev: 0.0015),
            FeatureKeys.loudnessStdDevOriginal: (mean: 0.003, stddev: 0.001),
            FeatureKeys.loudnessDynamicRangeOriginal: (mean: 17.0, stddev: 4.5),
            FeatureKeys.gainFactor: (mean: 15.0, stddev: 3.5),
            FeatureKeys.loudnessRMS: (mean: 0.055, stddev: 0.018),
            FeatureKeys.loudness: (mean: 0.055, stddev: 0.018),
            FeatureKeys.loudnessStdDev: (mean: 0.040, stddev: 0.015),

            FeatureKeys.f0Mean: (mean: f0Mean, stddev: 12.0),
            FeatureKeys.f0Range: (mean: 6.5, stddev: 1.5),
            FeatureKeys.f0RangeST: (mean: 6.5, stddev: 1.5),
            FeatureKeys.f0StdDev: (mean: 12.5, stddev: 2.5),
            FeatureKeys.f0Variability: (mean: 12.5, stddev: 2.5),

            FeatureKeys.jitter: (mean: 0.030, stddev: 0.012),
            FeatureKeys.shimmer: (mean: 0.185, stddev: 0.035),
            FeatureKeys.hnr: (mean: 3.0, stddev: 0.6),

            FeatureKeys.speechRate: (mean: 4.2, stddev: 0.5),
            FeatureKeys.pauseRate: (mean: 20.0, stddev: 7.0),
            FeatureKeys.pauseDistribution: (mean: 20.0, stddev: 7.0),
            FeatureKeys.meanPauseDuration: (mean: 0.40, stddev: 0.15),
            FeatureKeys.pauseDuration: (mean: 0.40, stddev: 0.15),
            FeatureKeys.articulationRate: (mean: 6.5, stddev: 0.8),

            FeatureKeys.formantDispersion: (mean: 800.0, stddev: 250.0),
            FeatureKeys.f1: (mean: 500.0, stddev: 250.0),
            FeatureKeys.f2: (mean: 2200.0, stddev: 600.0),
            FeatureKeys.f3: (mean: 3600.0, stddev: 800.0),
            FeatureKeys.f1Bandwidth: (mean: 3500.0, stddev: 500.0),
        ]
    }

    private static let deepVoiceBaseline = makeBaseline(f0Mean: 100.0)
    private static let midVoiceBaseline = makeBaseline(f0Mean: 125.0)
    private static let highVoiceBaseline = makeBaseline(f0Mean: 185.0)
}
