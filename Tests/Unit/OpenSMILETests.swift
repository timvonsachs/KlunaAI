import XCTest
@testable import KlunaAI

final class OpenSMILETests: XCTestCase {
    func testExpectedFeatureKeysExistAndAreUnique() {
        let expectedKeys = [
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

        for key in expectedKeys {
            XCTAssertFalse(key.isEmpty, "Feature key should not be empty")
        }
        XCTAssertEqual(Set(expectedKeys).count, expectedKeys.count, "Feature keys must be unique")
    }

    func testExtractorOutputKeysMatchCanonicalSet() {
        XCTAssertEqual(OpenSMILEExtractor.outputKeys, FeatureKeys.canonical)
    }

    func testFeatureKeysMatchPopulationBaseline() {
        let populationKeys = Set(PopulationBaseline.values(for: .mid).keys)
        XCTAssertTrue(FeatureKeys.canonical.isSubset(of: populationKeys))
    }

    func testFeatureKeyConsistencyAcrossScoringPipeline() {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let scorer = DimensionScorer(baselineEngine: BaselineEngine())

        let scores = scorer.score(features: createSyntheticFeatures(), voiceType: .mid, context: context)
        XCTAssertFalse(scores.overall.isNaN)
        XCTAssertTrue((0...100).contains(scores.overall))
    }

    private func createSyntheticFeatures() -> [String: Double] {
        [
            FeatureKeys.f0Mean: 165.0,
            FeatureKeys.f0Variability: 1.0,
            FeatureKeys.f0Range: 5.0,
            FeatureKeys.jitter: 0.00045,
            FeatureKeys.shimmer: 0.00035,
            FeatureKeys.loudness: 0.5,
            FeatureKeys.hnr: 20.0,
            FeatureKeys.speechRate: 4.0,
            FeatureKeys.f1: 500.0,
            FeatureKeys.f2: 1500.0,
            FeatureKeys.f3: 2500.0,
            FeatureKeys.f1Bandwidth: 3500.0,
            FeatureKeys.pauseDuration: 0.15,
            FeatureKeys.pauseDistribution: 0.5,
        ]
    }
}
