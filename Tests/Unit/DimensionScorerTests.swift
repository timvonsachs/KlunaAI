import CoreData
import XCTest
@testable import KlunaAI

final class DimensionScorerTests: XCTestCase {
    private var scorer: DimensionScorer!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        scorer = DimensionScorer(baselineEngine: BaselineEngine())
    }

    func testPopulationMeanFeaturesYieldApproximatelyFifty() {
        let base = baselineFeatureDictionary()
        let scores = scorer.score(features: base, voiceType: .mid, context: context)
        XCTAssertTrue((45...75).contains(scores.overall), "Population-mean input should be in plausible mid range, got \(scores.overall)")
    }

    func testHighFeatureValuesIncreaseEnergy() {
        var features = baselineFeatureDictionary()
        let baseline = PopulationBaseline.values(for: .mid)
        features[FeatureKeys.loudness] = (baseline[FeatureKeys.loudness]?.mean ?? 0) + 2 * (baseline[FeatureKeys.loudness]?.stddev ?? 1)
        features[FeatureKeys.f0Range] = (baseline[FeatureKeys.f0Range]?.mean ?? 0) + 2 * (baseline[FeatureKeys.f0Range]?.stddev ?? 1)

        let scores = scorer.score(features: features, voiceType: .mid, context: context)
        XCTAssertGreaterThan(scores.energy, 60)
    }

    func testTempoIsBidirectional() {
        let neutral = scorer.score(features: baselineFeatureDictionary(), voiceType: .mid, context: context).tempo

        var fast = baselineFeatureDictionary()
        let b = PopulationBaseline.values(for: .mid)
        fast[FeatureKeys.speechRate] = (b[FeatureKeys.speechRate]?.mean ?? 4) + 3 * (b[FeatureKeys.speechRate]?.stddev ?? 1)
        let fastScore = scorer.score(features: fast, voiceType: .mid, context: context).tempo

        var slow = baselineFeatureDictionary()
        slow[FeatureKeys.speechRate] = (b[FeatureKeys.speechRate]?.mean ?? 4) - 3 * (b[FeatureKeys.speechRate]?.stddev ?? 1)
        let slowScore = scorer.score(features: slow, voiceType: .mid, context: context).tempo

        XCTAssertGreaterThan(neutral, fastScore)
        XCTAssertGreaterThan(neutral, slowScore)
    }

    func testScoresAreClampedToRange() {
        var extremeHigh = baselineFeatureDictionary()
        for (key, value) in PopulationBaseline.values(for: .mid) {
            extremeHigh[key] = value.mean + value.stddev * 200
        }
        let highScores = scorer.score(features: extremeHigh, voiceType: .mid, context: context)
        XCTAssertLessThanOrEqual(highScores.overall, 100)
        XCTAssertGreaterThanOrEqual(highScores.overall, 0)

        var extremeLow = baselineFeatureDictionary()
        for (key, value) in PopulationBaseline.values(for: .mid) {
            extremeLow[key] = value.mean - value.stddev * 200
        }
        let lowScores = scorer.score(features: extremeLow, voiceType: .mid, context: context)
        XCTAssertLessThanOrEqual(lowScores.overall, 100)
        XCTAssertGreaterThanOrEqual(lowScores.overall, 0)
    }

    func testHeatmapWithThreeSegments() {
        let segment1 = baselineFeatureDictionary()
        var segment2 = baselineFeatureDictionary()
        segment2[FeatureKeys.loudness] = (segment2[FeatureKeys.loudness] ?? 0.5) + 0.3
        let segment3 = baselineFeatureDictionary()

        let heatmap = scorer.heatmapScores(segments: [segment1, segment2, segment3], voiceType: .mid, context: context)
        XCTAssertEqual(heatmap.segments.count, 3)
        XCTAssertGreaterThan(heatmap.segments[1].scores.energy, heatmap.segments[0].scores.energy)
    }

    func testEnergeticVsQuietPitch() {
        let quietFeatures: [String: Double] = [
            FeatureKeys.loudness: 0.2,
            FeatureKeys.f0Range: 4.0,
            FeatureKeys.f0Variability: 0.7,
            FeatureKeys.hnr: 10.0,
            FeatureKeys.jitter: 0.0010,
            FeatureKeys.shimmer: 0.0009,
            FeatureKeys.speechRate: 2.5,
            FeatureKeys.pauseDuration: 0.25,
            FeatureKeys.pauseDistribution: 0.5,
            FeatureKeys.f0Mean: 165.0,
            FeatureKeys.f1: 500.0,
            FeatureKeys.f2: 1500.0,
            FeatureKeys.f3: 2500.0,
            FeatureKeys.f1Bandwidth: 3900.0,
        ]

        let energeticFeatures: [String: Double] = [
            FeatureKeys.loudness: 0.65,
            FeatureKeys.f0Range: 18.0,
            FeatureKeys.f0Variability: 1.1,
            FeatureKeys.hnr: 20.0,
            FeatureKeys.jitter: 0.00035,
            FeatureKeys.shimmer: 0.0003,
            FeatureKeys.speechRate: 4.5,
            FeatureKeys.pauseDuration: 0.10,
            FeatureKeys.pauseDistribution: 0.5,
            FeatureKeys.f0Mean: 165.0,
            FeatureKeys.f1: 500.0,
            FeatureKeys.f2: 1500.0,
            FeatureKeys.f3: 2500.0,
            FeatureKeys.f1Bandwidth: 3400.0,
        ]

        let neutralZ = Dictionary(uniqueKeysWithValues: FeatureKeys.canonical.map { ($0, 0.0) })

        let quietScores = scorer.score(rawFeatures: quietFeatures, zScores: neutralZ)
        let energeticScores = scorer.score(rawFeatures: energeticFeatures, zScores: neutralZ)

        XCTAssertGreaterThan(energeticScores.overall, quietScores.overall + 15)
        XCTAssertGreaterThan(energeticScores.energy, quietScores.energy + 20)
        XCTAssertGreaterThan(energeticScores.confidence, quietScores.confidence + 10)
    }

    private func baselineFeatureDictionary() -> [String: Double] {
        let base = PopulationBaseline.values(for: .mid)
        return Dictionary(uniqueKeysWithValues: base.map { ($0.key, $0.value.mean) })
    }
}
