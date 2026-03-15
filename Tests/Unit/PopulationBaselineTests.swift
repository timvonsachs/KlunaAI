import XCTest
@testable import KlunaAI

final class PopulationBaselineTests: XCTestCase {
    func testDeepVoiceHasLowerF0ThanHigh() {
        let deep = PopulationBaseline.values(for: .deep)
        let high = PopulationBaseline.values(for: .high)
        XCTAssertLessThan(deep[FeatureKeys.f0Mean]?.mean ?? 0, high[FeatureKeys.f0Mean]?.mean ?? 0)
    }

    func testMidVoiceF0IsBetweenDeepAndHigh() {
        let deep = PopulationBaseline.values(for: .deep)
        let mid = PopulationBaseline.values(for: .mid)
        let high = PopulationBaseline.values(for: .high)

        let deepF0 = deep[FeatureKeys.f0Mean]?.mean ?? 0
        let midF0 = mid[FeatureKeys.f0Mean]?.mean ?? 0
        let highF0 = high[FeatureKeys.f0Mean]?.mean ?? 0

        XCTAssertGreaterThan(midF0, deepF0)
        XCTAssertLessThan(midF0, highF0)
    }

    func testAllVoiceTypesHaveAllKeys() {
        let required: Set<String> = [
            FeatureKeys.f0Mean,
            FeatureKeys.f0Variability,
            FeatureKeys.f0Range,
            FeatureKeys.jitter,
            FeatureKeys.shimmer,
            FeatureKeys.loudness,
            FeatureKeys.hnr,
            FeatureKeys.speechRate,
            FeatureKeys.f1,
            FeatureKeys.f2,
            FeatureKeys.f3,
            FeatureKeys.f1Bandwidth,
            FeatureKeys.pauseDuration,
            FeatureKeys.pauseDistribution,
        ]
        for voiceType in VoiceType.allCases {
            let keys = Set(PopulationBaseline.values(for: voiceType).keys)
            XCTAssertTrue(required.isSubset(of: keys), "Missing keys for \(voiceType.rawValue)")
        }
    }

    func testAllStddevsArePositive() {
        for voiceType in VoiceType.allCases {
            for (key, value) in PopulationBaseline.values(for: voiceType) {
                XCTAssertGreaterThan(value.stddev, 0, "\(voiceType.rawValue).\(key) stddev must be > 0")
            }
        }
    }

    func testZScoreCalculationWithPopulationMath() {
        guard let f0 = PopulationBaseline.values(for: .mid)[FeatureKeys.f0Mean] else {
            XCTFail("Missing F0 baseline")
            return
        }
        let zAtMean = (f0.mean - f0.mean) / f0.stddev
        let zOneSd = ((f0.mean + f0.stddev) - f0.mean) / f0.stddev

        XCTAssertEqual(zAtMean, 0, accuracy: 0.001)
        XCTAssertEqual(zOneSd, 1, accuracy: 0.001)
    }
}
