import XCTest
@testable import KlunaAI

final class FeatureKeyMappingTests: XCTestCase {
    func testOpenSMILEOutputKeysContainCanonicalSet() {
        XCTAssertEqual(OpenSMILEExtractor.outputKeys, FeatureKeys.canonical)
    }

    func testExpectedRawOpenSMILEAliasesResolveToCanonicalKeys() {
        let rawKeys = [
            "F0semitoneFrom27.5Hz_sma3nz_amean",
            "F0semitoneFrom27.5Hz_sma3nz_stddevNorm",
            "F0semitoneFrom27.5Hz_sma3nz_percentile99.0",
            "F0semitoneFrom27.5Hz_sma3nz_percentile1.0",
            "jitterLocal_sma3nz_amean",
            "shimmerLocaldB_sma3nz_amean",
            "Loudness_sma3_amean",
            "HNRdBACF_sma3nz_amean",
            "F1frequency_sma3nz_amean",
            "F2frequency_sma3nz_amean",
            "F3frequency_sma3nz_amean",
            "F1bandwidth_sma3nz_amean",
            "VoicedSegmentsPerSec",
            "MeanUnvoicedSegmentLength",
        ]

        let normalized = FeatureKeyMapper.normalize(
            Dictionary(uniqueKeysWithValues: rawKeys.enumerated().map { ($1, Double($0 + 1)) })
        )

        XCTAssertTrue(normalized.keys.contains(FeatureKeys.f0Mean))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.f0Variability))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.f0Range))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.jitter))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.shimmer))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.energy))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.hnr))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.f1))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.f2))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.f3))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.f1Bandwidth))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.speechRate))
        XCTAssertTrue(normalized.keys.contains(FeatureKeys.pauseDuration))
    }

    func testDimensionScorerAndBaselineHandleRawKeysWithoutMismatch() {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let baseline = BaselineEngine()
        let scorer = DimensionScorer(baselineEngine: baseline)

        let raw: [String: Double] = [
            "F0semitoneFrom27.5Hz_sma3nz_amean": 220,
            "F0semitoneFrom27.5Hz_sma3nz_stddevNorm": 0.2,
            "F0semitoneFrom27.5Hz_sma3nz_percentile99.0": 270,
            "F0semitoneFrom27.5Hz_sma3nz_percentile1.0": 180,
            "jitterLocal_sma3nz_amean": 0.02,
            "shimmerLocaldB_sma3nz_amean": 0.3,
            "Loudness_sma3_amean": 0.6,
            "HNRdBACF_sma3nz_amean": 14,
            "F1frequency_sma3nz_amean": 500,
            "F2frequency_sma3nz_amean": 1500,
            "F3frequency_sma3nz_amean": 2400,
            "F1bandwidth_sma3nz_amean": 100,
            "VoicedSegmentsPerSec": 4.1,
            "MeanUnvoicedSegmentLength": 0.14,
        ]

        // Store baselines using canonical keys.
        let canonical = FeatureKeyMapper.normalize(raw)
        for _ in 0..<25 {
            let features = VoiceFeatures(
                f0Mean: canonical[FeatureKeys.f0Mean] ?? 0,
                f0Variability: canonical[FeatureKeys.f0Variability] ?? 0,
                f0Range: canonical[FeatureKeys.f0Range] ?? 0,
                jitter: canonical[FeatureKeys.jitter] ?? 0,
                shimmer: canonical[FeatureKeys.shimmer] ?? 0,
                speechRate: canonical[FeatureKeys.speechRate] ?? 0,
                energy: canonical[FeatureKeys.energy] ?? 0,
                hnr: canonical[FeatureKeys.hnr] ?? 0,
                f1: canonical[FeatureKeys.f1] ?? 0,
                f2: canonical[FeatureKeys.f2] ?? 0,
                f3: canonical[FeatureKeys.f3] ?? 0,
                f4: canonical[FeatureKeys.f1Bandwidth] ?? 0,
                pauseDuration: canonical[FeatureKeys.pauseDuration] ?? 0,
                pauseDistribution: canonical[FeatureKeys.pauseDistribution] ?? 0
            )
            baseline.updateBaseline(with: features, context: context)
        }

        let scores = scorer.score(features: raw, voiceType: .mid, context: context)
        XCTAssertTrue((0...100).contains(scores.overall))
    }
}
