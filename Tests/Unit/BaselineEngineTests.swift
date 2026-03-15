import CoreData
import XCTest
@testable import KlunaAI

final class BaselineEngineTests: XCTestCase {
    private var engine: BaselineEngine!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        engine = BaselineEngine()
    }

    func testFirstUpdateChangesBaselineStatus() {
        XCTAssertEqual(engine.baselineStatus(context: context).sessionCount, 0)
        engine.updateBaseline(with: makeVoiceFeatures(f0Mean: 150), context: context)
        XCTAssertEqual(engine.baselineStatus(context: context).sessionCount, 1)
    }

    func testEWMAConvergesForRepeatedValue() {
        for _ in 0..<30 {
            engine.updateBaseline(with: makeVoiceFeatures(f0Mean: 170), context: context)
        }
        let z = engine.calculateAllZScores(
            for: [FeatureKeys.f0Mean: 170],
            voiceType: .mid,
            context: context
        )[FeatureKeys.f0Mean]
        XCTAssertNotNil(z)
        XCTAssertEqual(z ?? 99, 0, accuracy: 0.5)
    }

    func testPopulationFallbackUsedBeforePersonalBaselineEstablished() {
        engine.updateBaseline(with: makeVoiceFeatures(f0Mean: 165), context: context)
        let zScores = engine.calculateAllZScores(
            for: [FeatureKeys.f0Mean: 165],
            voiceType: .mid,
            context: context
        )
        XCTAssertNotNil(zScores[FeatureKeys.f0Mean])
    }

    func testPersonalBaselineUsedAfterEnoughSamples() {
        for _ in 0..<25 {
            engine.updateBaseline(with: makeVoiceFeatures(f0Mean: 150), context: context)
        }
        let zScores = engine.calculateAllZScores(
            for: [FeatureKeys.f0Mean: 160],
            voiceType: .mid,
            context: context
        )
        XCTAssertGreaterThan(zScores[FeatureKeys.f0Mean] ?? 0, 0)
    }

    func testBaselineEstablishedAfterTwentyOneSessions() {
        XCTAssertFalse(engine.isBaselineEstablished(context: context))
        for _ in 0..<21 {
            engine.updateBaseline(with: makeVoiceFeatures(), context: context)
        }
        XCTAssertTrue(engine.isBaselineEstablished(context: context))
    }

    func testUnknownFeatureReturnsNoZScore() {
        let zScores = engine.calculateAllZScores(
            for: ["unknownFeature123": 42],
            voiceType: .mid,
            context: context
        )
        XCTAssertNil(zScores["unknownFeature123"])
    }

    private func makeVoiceFeatures(f0Mean: Double = 165) -> VoiceFeatures {
        VoiceFeatures(
            f0Mean: f0Mean,
            f0Variability: 1.0,
            f0Range: 5.0,
            jitter: 0.00045,
            shimmer: 0.00035,
            speechRate: 4.0,
            energy: 0.5,
            hnr: 20.0,
            f1: 500.0,
            f2: 1500.0,
            f3: 2500.0,
            f4: 3500.0,
            pauseDuration: 0.15,
            pauseDistribution: 0.5
        )
    }
}
