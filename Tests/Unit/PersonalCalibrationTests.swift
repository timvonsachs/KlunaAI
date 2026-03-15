import XCTest
@testable import KlunaAI

@MainActor
final class PersonalCalibrationTests: XCTestCase {
    private var calibration: PersonalCalibration!

    override func setUp() {
        super.setUp()
        calibration = PersonalCalibration()
        calibration.reset()
    }

    override func tearDown() {
        calibration.reset()
        super.tearDown()
    }

    func testFirstEntryInitializesBaseline() {
        let result = calibration.processEntry(features: TestFeatureFactory.calibrationFeatures())
        XCTAssertEqual(result.phase, .initial)
        XCTAssertTrue(result.zScores.isEmpty)
        XCTAssertTrue(calibration.isCalibrated)
        XCTAssertEqual(calibration.entryCount, 1)
    }

    func testSecondEntryProducesZScoresAndLearningPhase() {
        _ = calibration.processEntry(features: TestFeatureFactory.calibrationFeatures())
        let second = calibration.processEntry(features: TestFeatureFactory.calibrationFeatures(speechRate: 4.6, hnr: 4.0))
        XCTAssertEqual(second.phase, .learning)
        XCTAssertFalse(second.zScores.isEmpty)
    }

    func testStablePhaseAfterTenEntries() {
        let features = TestFeatureFactory.calibrationFeatures()
        for _ in 0..<10 { _ = calibration.processEntry(features: features) }
        let result = calibration.processEntry(features: features)
        XCTAssertEqual(result.phase, .stable)
        XCTAssertEqual(calibration.entryCount, 11)
    }

    func testDetectsJitterFlagAgainstPersonalBaseline() {
        let normal = TestFeatureFactory.calibrationFeatures(jitter: 0.025)
        for _ in 0..<4 { _ = calibration.processEntry(features: normal) }
        let stressed = calibration.processEntry(features: TestFeatureFactory.calibrationFeatures(jitter: 0.045))
        let jitterFlag = stressed.flags.first(where: { $0.feature == FeatureKeys.jitter })
        XCTAssertNotNil(jitterFlag)
        XCTAssertGreaterThan(jitterFlag?.zScore ?? 0, 0)
    }

    func testDifferentVoicesCanMapToSimilarPersonalLevels() {
        let woman = PersonalCalibration()
        woman.reset()
        _ = woman.processEntry(features: TestFeatureFactory.calibrationFeatures(f0: 210, speechRate: 5.4, hnr: 5.0, jitter: 0.015))
        let womanDims = woman.personalizedDimensions(features: TestFeatureFactory.calibrationFeatures(f0: 210, speechRate: 5.4, hnr: 5.0, jitter: 0.015))

        let man = PersonalCalibration()
        man.reset()
        _ = man.processEntry(features: TestFeatureFactory.calibrationFeatures(f0: 110, speechRate: 3.4, hnr: 3.0, jitter: 0.03))
        let manDims = man.personalizedDimensions(features: TestFeatureFactory.calibrationFeatures(f0: 110, speechRate: 3.4, hnr: 3.0, jitter: 0.03))

        XCTAssertEqual(womanDims.energy, manDims.energy, accuracy: 0.20)
        XCTAssertEqual(womanDims.warmth, manDims.warmth, accuracy: 0.20)
    }

    func testResetClearsCalibrationState() {
        _ = calibration.processEntry(features: TestFeatureFactory.calibrationFeatures())
        calibration.reset()
        XCTAssertFalse(calibration.isCalibrated)
        XCTAssertEqual(calibration.entryCount, 0)
    }

    func testSaveAndLoadPreservesEntryCount() {
        _ = calibration.processEntry(features: TestFeatureFactory.calibrationFeatures())
        _ = calibration.processEntry(features: TestFeatureFactory.calibrationFeatures(speechRate: 4.3))
        calibration.save()

        let loaded = PersonalCalibration()
        loaded.load()
        XCTAssertEqual(loaded.entryCount, 2)
        XCTAssertTrue(loaded.isCalibrated)
        loaded.reset()
    }

}

@MainActor
final class VoiceDimensionsTests: XCTestCase {
    private var calibration: PersonalCalibration!

    override func setUp() {
        super.setUp()
        calibration = PersonalCalibration()
        calibration.reset()
        for _ in 0..<5 { _ = calibration.processEntry(features: TestFeatureFactory.calibrationFeatures()) }
    }

    override func tearDown() {
        calibration.reset()
        super.tearDown()
    }

    func testAllDimensionsAreClampedBetweenZeroAndOne() {
        let dims = calibration.personalizedDimensions(features: TestFeatureFactory.calibrationFeatures())
        for value in [dims.energy, dims.tension, dims.fatigue, dims.warmth, dims.expressiveness, dims.tempo] {
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThanOrEqual(value, 1)
        }
    }

    func testEnergeticProfileHasHigherEnergyThanFatigue() {
        let energetic = TestFeatureFactory.calibrationFeatures().merging([
            FeatureKeys.speechRate: 6.0,
            FeatureKeys.articulationRate: 8.4,
            FeatureKeys.f0StdDev: 16.0,
            FeatureKeys.loudnessDynamicRangeOriginal: 38.0,
            FeatureKeys.f0RangeST: 9.0,
        ]) { _, new in new }
        _ = calibration.processEntry(features: energetic)
        let dims = calibration.personalizedDimensions(features: energetic)
        XCTAssertGreaterThan(dims.energy, dims.fatigue)
        XCTAssertGreaterThan(dims.expressiveness, 0.5)
    }

    func testFatiguedProfileHasHigherFatigueThanEnergy() {
        let tired = TestFeatureFactory.calibrationFeatures().merging([
            FeatureKeys.speechRate: 2.8,
            FeatureKeys.articulationRate: 5.0,
            FeatureKeys.f0RangeST: 2.5,
            FeatureKeys.f0StdDev: 5.0,
            FeatureKeys.pauseDuration: 0.9,
            FeatureKeys.shimmer: 0.22,
            FeatureKeys.loudnessDynamicRangeOriginal: 18.0,
        ]) { _, new in new }
        _ = calibration.processEntry(features: tired)
        let dims = calibration.personalizedDimensions(features: tired)
        XCTAssertGreaterThan(dims.fatigue, dims.energy)
    }

    func testTenseProfileIncreasesTension() {
        let tense = TestFeatureFactory.calibrationFeatures().merging([
            FeatureKeys.jitter: 0.042,
            FeatureKeys.shimmer: 0.21,
            FeatureKeys.hnr: 2.2,
            FeatureKeys.speechRate: 5.5,
            FeatureKeys.pauseDuration: 0.15,
        ]) { _, new in new }
        _ = calibration.processEntry(features: tense)
        let dims = calibration.personalizedDimensions(features: tense)
        XCTAssertGreaterThan(dims.tension, 0.5)
    }

    func testEnergyNotDominatedByRMSLoudness() {
        let quiet = TestFeatureFactory.calibrationFeatures().merging([
            FeatureKeys.loudnessRMSOriginal: 0.01,
        ]) { _, new in new }
        let loud = TestFeatureFactory.calibrationFeatures().merging([
            FeatureKeys.loudnessRMSOriginal: 0.08,
        ]) { _, new in new }

        _ = calibration.processEntry(features: quiet)
        let quietDims = calibration.personalizedDimensions(features: quiet)
        _ = calibration.processEntry(features: loud)
        let loudDims = calibration.personalizedDimensions(features: loud)
        XCTAssertEqual(quietDims.energy, loudDims.energy, accuracy: 0.15)
    }

}
