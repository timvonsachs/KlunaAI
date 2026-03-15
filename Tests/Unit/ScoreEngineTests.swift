import Foundation
import XCTest
@testable import KlunaAI

private struct TestFeatureSet {
    let jitter: Double
    let shimmer: Double
    let hnr: Double
    let loudnessRMSOriginal: Double
    let loudnessDynamicRangeOriginal: Double
    let f0RangeST: Double
    let f0StdDev: Double
    let speechRate: Double
    let pauseRate: Double
    let meanPauseDuration: Double
    let articulationRate: Double
    let presenceScore: Double
    let warmthScore: Double
    let bodyScore: Double
    let airScore: Double
    let spectralBalance: Double
}

private let genuschelt = TestFeatureSet(
    jitter: 0.031, shimmer: 0.173, hnr: 2.83,
    loudnessRMSOriginal: 0.0025, loudnessDynamicRangeOriginal: 15.4,
    f0RangeST: 7.3, f0StdDev: 10.7,
    speechRate: 4.45, pauseRate: 22.0, meanPauseDuration: 0.35, articulationRate: 7.0,
    presenceScore: 20, warmthScore: 35, bodyScore: 30, airScore: 8, spectralBalance: 20
)

private let normal = TestFeatureSet(
    jitter: 0.031, shimmer: 0.172, hnr: 3.57,
    loudnessRMSOriginal: 0.0042, loudnessDynamicRangeOriginal: 20.6,
    f0RangeST: 6.2, f0StdDev: 14.4,
    speechRate: 3.94, pauseRate: 24.9, meanPauseDuration: 0.45, articulationRate: 7.0,
    presenceScore: 45, warmthScore: 55, bodyScore: 50, airScore: 20, spectralBalance: 45
)

private let monoton = TestFeatureSet(
    jitter: 0.033, shimmer: 0.188, hnr: 2.95,
    loudnessRMSOriginal: 0.0031, loudnessDynamicRangeOriginal: 13.2,
    f0RangeST: 5.6, f0StdDev: 11.0,
    speechRate: 4.15, pauseRate: 21.0, meanPauseDuration: 0.40, articulationRate: 6.7,
    presenceScore: 30, warmthScore: 42, bodyScore: 38, airScore: 12, spectralBalance: 30
)

private let energetisch = TestFeatureSet(
    jitter: 0.026, shimmer: 0.177, hnr: 3.79,
    loudnessRMSOriginal: 0.0053, loudnessDynamicRangeOriginal: 23.3,
    f0RangeST: 5.9, f0StdDev: 13.1,
    speechRate: 3.82, pauseRate: 27.1, meanPauseDuration: 0.45, articulationRate: 6.9,
    presenceScore: 55, warmthScore: 55, bodyScore: 55, airScore: 25, spectralBalance: 50
)

private let fluesternd = TestFeatureSet(
    jitter: 0.060, shimmer: 0.295, hnr: 1.42,
    loudnessRMSOriginal: 0.0014, loudnessDynamicRangeOriginal: 10.1,
    f0RangeST: 6.4, f0StdDev: 14.0,
    speechRate: 5.67, pauseRate: 0.0, meanPauseDuration: 0.0, articulationRate: 5.85,
    presenceScore: 26, warmthScore: 10, bodyScore: 35, airScore: 8, spectralBalance: 15
)

private let charismatisch = TestFeatureSet(
    jitter: 0.024, shimmer: 0.165, hnr: 3.9,
    loudnessRMSOriginal: 0.0060, loudnessDynamicRangeOriginal: 24.0,
    f0RangeST: 6.4, f0StdDev: 14.5,
    speechRate: 3.95, pauseRate: 25.0, meanPauseDuration: 0.52, articulationRate: 6.8,
    presenceScore: 62, warmthScore: 60, bodyScore: 58, airScore: 28, spectralBalance: 57
)

private let lautSchlecht = TestFeatureSet(
    jitter: 0.043, shimmer: 0.235, hnr: 2.2,
    loudnessRMSOriginal: 0.0068, loudnessDynamicRangeOriginal: 12.0,
    f0RangeST: 6.1, f0StdDev: 15.2,
    speechRate: 5.8, pauseRate: 8.0, meanPauseDuration: 0.18, articulationRate: 8.1,
    presenceScore: 48, warmthScore: 28, bodyScore: 26, airScore: 40, spectralBalance: 25
)

private func calculateTestScores(_ f: TestFeatureSet) -> (pillars: PillarScores, dimensions: DimensionScores) {
    let features: [String: Double] = [
        FeatureKeys.jitter: f.jitter,
        FeatureKeys.shimmer: f.shimmer,
        FeatureKeys.hnr: f.hnr,
        FeatureKeys.loudnessRMSOriginal: f.loudnessRMSOriginal,
        FeatureKeys.loudnessDynamicRangeOriginal: f.loudnessDynamicRangeOriginal,
        FeatureKeys.f0RangeST: f.f0RangeST,
        FeatureKeys.f0StdDev: f.f0StdDev,
        FeatureKeys.speechRate: f.speechRate,
        FeatureKeys.pauseRate: f.pauseRate,
        FeatureKeys.meanPauseDuration: f.meanPauseDuration,
        FeatureKeys.articulationRate: f.articulationRate,
    ]

    let spectral = SpectralBandResult(
        warmthEnergy: 0,
        bodyEnergy: 0,
        presenceEnergy: 0,
        airEnergy: 0,
        warmthToPresenceRatio: 0,
        bodyToTotalRatio: 0,
        presenceToTotalRatio: 0,
        spectralBalance: Float(f.spectralBalance),
        warmthScore: Float(f.warmthScore),
        bodyScore: Float(f.bodyScore),
        presenceScore: Float(f.presenceScore),
        airScore: Float(f.airScore),
        overallTimbreScore: 0
    )

    let pillars = PillarScoreEngine.calculatePillarScores(features: features, spectral: spectral)
    let dimensions = PillarScoreEngine.calculateDimensions(pillars: pillars)
    return (pillars, dimensions)
}

final class ScoreEngineTests: XCTestCase {
    private struct Snapshot {
        let voiceQuality: Double
        let clarity: Double
        let dynamics: Double
        let rhythm: Double
        let qualityGate: Double
        let clarityGate: Double
        let overall: Double
        let confidence: Double
        let energy: Double
        let tempo: Double
        let stability: Double
        let charisma: Double
    }

    private func assertApprox(_ actual: Double, _ expected: Double, tolerance: Double, _ message: String) {
        XCTAssertEqual(actual, expected, accuracy: tolerance, message)
    }

    func testCalibrationSnapshot_V5() {
        let expected: [String: Snapshot] = [
            "fluesternd": .init(voiceQuality: 8, clarity: 17, dynamics: 25, rhythm: 24, qualityGate: 0.20, clarityGate: 0.71, overall: 10, confidence: 10, energy: 14, tempo: 23, stability: 10, charisma: 10),
            "genuschelt": .init(voiceQuality: 48, clarity: 21, dynamics: 36, rhythm: 73, qualityGate: 1.00, clarityGate: 0.88, overall: 39, confidence: 41, energy: 35, tempo: 60, stability: 46, charisma: 36),
            "monoton": .init(voiceQuality: 45, clarity: 30, dynamics: 30, rhythm: 75, qualityGate: 1.00, clarityGate: 1.00, overall: 45, confidence: 42, energy: 39, tempo: 62, stability: 46, charisma: 42),
            "normal": .init(voiceQuality: 62, clarity: 43, dynamics: 61, rhythm: 82, qualityGate: 1.00, clarityGate: 1.00, overall: 62, confidence: 59, energy: 60, tempo: 73, stability: 62, charisma: 60),
            "energetisch": .init(voiceQuality: 68, clarity: 49, dynamics: 69, rhythm: 81, qualityGate: 1.00, clarityGate: 1.00, overall: 67, confidence: 65, energy: 66, tempo: 75, stability: 67, charisma: 65),
            "charismatisch": .init(voiceQuality: 73, clarity: 55, dynamics: 77, rhythm: 83, qualityGate: 1.00, clarityGate: 1.00, overall: 72, confidence: 70, energy: 72, tempo: 78, stability: 72, charisma: 71),
            "laut-schlecht": .init(voiceQuality: 18, clarity: 38, dynamics: 57, rhythm: 47, qualityGate: 0.45, clarityGate: 1.00, overall: 18, confidence: 16, energy: 45, tempo: 47, stability: 15, charisma: 18),
        ]

        let actual: [String: (pillars: PillarScores, dimensions: DimensionScores)] = [
            "fluesternd": calculateTestScores(fluesternd),
            "genuschelt": calculateTestScores(genuschelt),
            "monoton": calculateTestScores(monoton),
            "normal": calculateTestScores(normal),
            "energetisch": calculateTestScores(energetisch),
            "charismatisch": calculateTestScores(charismatisch),
            "laut-schlecht": calculateTestScores(lautSchlecht),
        ]

        for (key, exp) in expected {
            guard let value = actual[key] else {
                XCTFail("Snapshot missing actual entry for \(key)")
                continue
            }
            let p = value.pillars
            let d = value.dimensions

            assertApprox(p.voiceQuality, exp.voiceQuality, tolerance: 1.0, "\(key) voiceQuality drift")
            assertApprox(p.clarity, exp.clarity, tolerance: 1.0, "\(key) clarity drift")
            assertApprox(p.dynamics, exp.dynamics, tolerance: 1.0, "\(key) dynamics drift")
            assertApprox(p.rhythm, exp.rhythm, tolerance: 1.0, "\(key) rhythm drift")
            assertApprox(p.qualityGate, exp.qualityGate, tolerance: 0.02, "\(key) qualityGate drift")
            assertApprox(p.clarityGate, exp.clarityGate, tolerance: 0.02, "\(key) clarityGate drift")
            assertApprox(p.overall, exp.overall, tolerance: 1.0, "\(key) overall drift")

            assertApprox(d.confidence, exp.confidence, tolerance: 1.0, "\(key) confidence drift")
            assertApprox(d.energy, exp.energy, tolerance: 1.0, "\(key) energy drift")
            assertApprox(d.tempo, exp.tempo, tolerance: 1.0, "\(key) tempo drift")
            assertApprox(d.stability, exp.stability, tolerance: 1.0, "\(key) stability drift")
            assertApprox(d.charisma, exp.charisma, tolerance: 1.0, "\(key) charisma drift")
        }
    }

    func testOrdering_CompleteChain() {
        let chain = [
            ("fluesternd", calculateTestScores(fluesternd).pillars.overall),
            ("genuschelt", calculateTestScores(genuschelt).pillars.overall),
            ("monoton", calculateTestScores(monoton).pillars.overall),
            ("normal", calculateTestScores(normal).pillars.overall),
            ("energetisch", calculateTestScores(energetisch).pillars.overall),
            ("charismatisch", calculateTestScores(charismatisch).pillars.overall),
        ]
        for i in 0..<(chain.count - 1) {
            XCTAssertLessThan(chain[i].1, chain[i + 1].1, "\(chain[i].0) muss unter \(chain[i + 1].0) liegen")
        }
    }

    func testOrdering_FullChain() {
        let sG = calculateTestScores(genuschelt).pillars.overall
        let sN = calculateTestScores(normal).pillars.overall
        let sE = calculateTestScores(energetisch).pillars.overall
        XCTAssertLessThan(sG, sN)
        XCTAssertLessThan(sN, sE)
        XCTAssertGreaterThanOrEqual(sN - sG, 8)
        XCTAssertGreaterThanOrEqual(sE - sN, 4.5)
    }

    func testGap_FluesterndZuEnergetisch_Mindestens35() {
        let gap = calculateTestScores(energetisch).pillars.overall - calculateTestScores(fluesternd).pillars.overall
        XCTAssertGreaterThanOrEqual(gap, 35)
    }

    func testGap_NormalZuEnergetisch_Mindestens4() {
        let gap = calculateTestScores(energetisch).pillars.overall - calculateTestScores(normal).pillars.overall
        XCTAssertGreaterThanOrEqual(gap, 4.0)
    }

    func testRange_FluesterndUnter25() {
        let score = calculateTestScores(fluesternd).pillars.overall
        XCTAssertLessThan(score, 25)
    }

    func testRange_GenuscheltZwischen20Und45() {
        let score = calculateTestScores(genuschelt).pillars.overall
        XCTAssertGreaterThanOrEqual(score, 20)
        XCTAssertLessThanOrEqual(score, 45)
    }

    func testRange_NormalZwischen50Und70() {
        let score = calculateTestScores(normal).pillars.overall
        XCTAssertGreaterThanOrEqual(score, 50)
        XCTAssertLessThanOrEqual(score, 70)
    }

    func testRange_EnergetischZwischen60Und80() {
        let score = calculateTestScores(energetisch).pillars.overall
        XCTAssertGreaterThanOrEqual(score, 60)
        XCTAssertLessThanOrEqual(score, 80)
    }

    func testGate_LowQualityCapsScore() {
        let s = calculateTestScores(fluesternd)
        XCTAssertLessThan(s.pillars.qualityGate, 1.0)
        XCTAssertLessThan(s.pillars.overall, 35)
    }

    func testGate_LowClarityCapsScore() {
        let lowClarity = TestFeatureSet(
            jitter: 0.031, shimmer: 0.173, hnr: 2.83,
            loudnessRMSOriginal: 0.0025, loudnessDynamicRangeOriginal: 15.4,
            f0RangeST: 7.3, f0StdDev: 10.7,
            speechRate: 4.45, pauseRate: 22.0, meanPauseDuration: 0.35, articulationRate: 7.0,
            presenceScore: 5, warmthScore: 15, bodyScore: 20, airScore: 5, spectralBalance: 10
        )
        let s = calculateTestScores(lowClarity)
        XCTAssertLessThan(s.pillars.clarityGate, 1.0)
        XCTAssertLessThan(s.pillars.overall, 30)
    }

    func testGate_GuteStimmeHatKeineGates() {
        let s = calculateTestScores(energetisch)
        XCTAssertEqual(s.pillars.qualityGate, 1.0, accuracy: 0.001)
        XCTAssertEqual(s.pillars.clarityGate, 1.0, accuracy: 0.001)
    }

    func testNoCompensation_LowClarityTrotzGutemRhythmusBleibtNiedrig() {
        let fakeCompensation = TestFeatureSet(
            jitter: 0.024, shimmer: 0.168, hnr: 3.7,
            loudnessRMSOriginal: 0.0057, loudnessDynamicRangeOriginal: 22.0,
            f0RangeST: 6.6, f0StdDev: 14.2,
            speechRate: 4.1, pauseRate: 24.0, meanPauseDuration: 0.48, articulationRate: 6.9,
            presenceScore: 6, warmthScore: 18, bodyScore: 24, airScore: 6, spectralBalance: 10
        )
        let s = calculateTestScores(fakeCompensation)
        XCTAssertLessThan(s.pillars.clarityGate, 0.5)
        XCTAssertLessThan(s.pillars.overall, 30)
    }

    func testPillar_VoiceQualityDifferenziert() {
        let qG = calculateTestScores(genuschelt).pillars.voiceQuality
        let qN = calculateTestScores(normal).pillars.voiceQuality
        let qE = calculateTestScores(energetisch).pillars.voiceQuality
        XCTAssertLessThan(qG, qN)
        XCTAssertLessThan(qN, qE)
    }

    func testPillar_DynamicsDifferenziert() {
        let dG = calculateTestScores(genuschelt).pillars.dynamics
        let dN = calculateTestScores(normal).pillars.dynamics
        let dE = calculateTestScores(energetisch).pillars.dynamics
        XCTAssertLessThan(dG, dN)
        XCTAssertLessThan(dN, dE)
    }

    func testEdge_LautSchlechtNichtUeberNormal() {
        let sL = calculateTestScores(lautSchlecht).pillars.overall
        let sN = calculateTestScores(normal).pillars.overall
        XCTAssertLessThanOrEqual(sL, sN)
    }

    func testEdge_LautSchlechtTempoNiedrigerAlsNormal() {
        let tL = calculateTestScores(lautSchlecht).dimensions.tempo
        let tN = calculateTestScores(normal).dimensions.tempo
        XCTAssertLessThan(tL, tN)
    }

    func testDimension_CharismaSteigtVonNormalZuCharismatisch() {
        let cN = calculateTestScores(normal).dimensions.charisma
        let cC = calculateTestScores(charismatisch).dimensions.charisma
        XCTAssertLessThan(cN, cC)
    }

    func testDimension_ConfidenceBeiGenuscheltUnterNormal() {
        let cG = calculateTestScores(genuschelt).dimensions.confidence
        let cN = calculateTestScores(normal).dimensions.confidence
        XCTAssertLessThan(cG, cN)
    }

    func testBounds_AlleScoresZwischen0Und100() {
        for set in [genuschelt, monoton, normal, energetisch, fluesternd, charismatisch, lautSchlecht] {
            let result = calculateTestScores(set)
            XCTAssertGreaterThanOrEqual(result.pillars.voiceQuality, 0)
            XCTAssertLessThanOrEqual(result.pillars.voiceQuality, 100)
            XCTAssertGreaterThanOrEqual(result.pillars.clarity, 0)
            XCTAssertLessThanOrEqual(result.pillars.clarity, 100)
            XCTAssertGreaterThanOrEqual(result.pillars.dynamics, 0)
            XCTAssertLessThanOrEqual(result.pillars.dynamics, 100)
            XCTAssertGreaterThanOrEqual(result.pillars.rhythm, 0)
            XCTAssertLessThanOrEqual(result.pillars.rhythm, 100)
            XCTAssertGreaterThanOrEqual(result.pillars.overall, 0)
            XCTAssertLessThanOrEqual(result.pillars.overall, 100)
            XCTAssertGreaterThanOrEqual(result.dimensions.overall, 0)
            XCTAssertLessThanOrEqual(result.dimensions.overall, 100)
            XCTAssertGreaterThanOrEqual(result.dimensions.confidence, 0)
            XCTAssertLessThanOrEqual(result.dimensions.confidence, 100)
            XCTAssertGreaterThanOrEqual(result.dimensions.energy, 0)
            XCTAssertLessThanOrEqual(result.dimensions.energy, 100)
            XCTAssertGreaterThanOrEqual(result.dimensions.tempo, 0)
            XCTAssertLessThanOrEqual(result.dimensions.tempo, 100)
            XCTAssertGreaterThanOrEqual(result.dimensions.stability, 0)
            XCTAssertLessThanOrEqual(result.dimensions.stability, 100)
            XCTAssertGreaterThanOrEqual(result.dimensions.charisma, 0)
            XCTAssertLessThanOrEqual(result.dimensions.charisma, 100)
        }
    }

    func testPrintFullReportV5() {
        let sets: [(String, TestFeatureSet)] = [
            ("fluesternd", fluesternd),
            ("genuschelt", genuschelt),
            ("monoton", monoton),
            ("normal", normal),
            ("energetisch", energetisch),
            ("charismatisch", charismatisch),
            ("laut-schlecht", lautSchlecht),
        ]

        print("")
        print("🏛️ ═══ SCORE ENGINE V5 REPORT ═══")
        print("Style          | VQ | Cl | Dy | Rh | GateQ | GateC | Ov | Cnf | En | Tmp | Gls | Chr")
        for (name, set) in sets {
            let r = calculateTestScores(set)
            let pad = name.padding(toLength: 14, withPad: " ", startingAt: 0)
            print("\(pad) | \(Int(r.pillars.voiceQuality)) | \(Int(r.pillars.clarity)) | \(Int(r.pillars.dynamics)) | \(Int(r.pillars.rhythm)) | \(String(format: "%.2f", r.pillars.qualityGate)) | \(String(format: "%.2f", r.pillars.clarityGate)) | \(Int(r.pillars.overall)) | \(Int(r.dimensions.confidence)) | \(Int(r.dimensions.energy)) | \(Int(r.dimensions.tempo)) | \(Int(r.dimensions.stability)) | \(Int(r.dimensions.charisma))")
        }
        print("🏛️ ═════════════════════════════")
        print("")
    }
}
