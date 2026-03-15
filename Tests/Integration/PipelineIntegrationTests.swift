import CoreData
import XCTest
@testable import KlunaAI

final class PipelineIntegrationTests: XCTestCase {
    var memoryManager: MemoryManager!
    var baselineEngine: BaselineEngine!
    var dimensionScorer: DimensionScorer!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        memoryManager = MemoryManager(context: context)
        baselineEngine = BaselineEngine()
        dimensionScorer = DimensionScorer(baselineEngine: baselineEngine)
    }

    func testFullPipeline_SyntheticFeatures_ProducesValidScores() {
        let features = syntheticFeatureDictionary()
        let voice = toVoiceFeatures(features)
        for _ in 0..<25 {
            baselineEngine.updateBaseline(with: voice, context: context)
        }

        let scores = dimensionScorer.score(features: features, voiceType: .mid, context: context)

        XCTAssertTrue((0...100).contains(scores.overall))
        XCTAssertTrue((0...100).contains(scores.confidence))
        XCTAssertTrue((0...100).contains(scores.energy))
        XCTAssertTrue((0...100).contains(scores.tempo))
        XCTAssertTrue((0...100).contains(scores.clarity))
        XCTAssertTrue((0...100).contains(scores.stability))
        XCTAssertTrue((0...100).contains(scores.charisma))
        XCTAssertTrue(scores.overall > 35 && scores.overall < 65)
    }

    func testScoreChanges_WhenFeaturesDeviate() {
        let baseline = syntheticFeatureDictionary()
        let baselineVoice = toVoiceFeatures(baseline)
        for _ in 0..<25 {
            baselineEngine.updateBaseline(with: baselineVoice, context: context)
        }

        var deviated = baseline
        deviated["Loudness_sma3_amean"] = 0.85
        deviated["VoicedSegmentsPerSec"] = 5.5

        let scores = dimensionScorer.score(features: deviated, voiceType: .mid, context: context)
        XCTAssertTrue(scores.energy > 50, "Energy \(scores.energy) should be above 50 for louder voice")
        XCTAssertTrue(scores.tempo < 50, "Tempo \(scores.tempo) should be below 50 for too-fast speech")
    }

    func testSessionSaveAndLoad() {
        let scores = DimensionScores(
            confidence: 74, energy: 68, tempo: 55,
            clarity: 72, stability: 61, charisma: 66
        )
        let session = CompletedSession(
            id: UUID(),
            date: Date(),
            pitchType: "Elevator Pitch",
            duration: 45.0,
            scores: scores,
            featureZScores: ["F0": 0.5, "Jitter": -0.3],
            transcription: "Test transcription",
            quickFeedback: "Good energy, work on tempo.",
            deepCoaching: nil,
            heatmapData: HeatmapData(segments: [])
        )

        memoryManager.saveSession(session)
        let loaded = memoryManager.recentSessions(count: 1)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.pitchType, "Elevator Pitch")
        XCTAssertEqual(loaded.first?.overallScore ?? -1, scores.overall, accuracy: 0.1)
    }

    func testBaselineProgression() {
        let features = syntheticFeatureDictionary()
        XCTAssertFalse(baselineEngine.isBaselineEstablished(context: context))
        let voice = toVoiceFeatures(features)
        for _ in 0..<21 {
            baselineEngine.updateBaseline(with: voice, context: context)
        }
        XCTAssertTrue(baselineEngine.isBaselineEstablished(context: context))
        let status = baselineEngine.baselineStatus(context: context)
        XCTAssertEqual(status.sessionCount, 21)
        XCTAssertTrue(status.isEstablished)
    }

    func testHeatmapScoring() {
        let baseline = syntheticFeatureDictionary()
        let baselineVoice = toVoiceFeatures(baseline)
        for _ in 0..<25 {
            baselineEngine.updateBaseline(with: baselineVoice, context: context)
        }

        let seg1 = baseline
        var seg2 = baseline
        seg2["Loudness_sma3_amean"] = 0.45
        var seg3 = baseline
        seg3["Loudness_sma3_amean"] = 0.3
        seg3["jitterLocal_sma3nz_amean"] = 0.04

        let heatmap = dimensionScorer.heatmapScores(segments: [seg1, seg2, seg3], voiceType: .mid, context: context)
        XCTAssertEqual(heatmap.segments.count, 3)
        if heatmap.segments.count == 3 {
            XCTAssertTrue(heatmap.segments[0].scores.energy >= heatmap.segments[2].scores.energy)
        }
    }

    func testPromptBuilderOutput() {
        let user = KlunaUser(
            name: "Tim",
            language: "de",
            firstSessionDate: Date().addingTimeInterval(-86400 * 14),
            totalSessions: 15,
            weeklyGoal: 5,
            currentStreak: 2,
            strengths: ["Starker Einstieg"],
            weaknesses: ["Tempo zu schnell bei Pricing"],
            longTermProfile: nil,
            teamCode: nil,
            role: .consumer,
            voiceType: .mid,
            goal: .pitches
        )
        let scores = DimensionScores(
            confidence: 74, energy: 68, tempo: 55,
            clarity: 72, stability: 61, charisma: 66
        )

        let prompt = PromptBuilder.buildQuickFeedbackPrompt(
            user: user,
            scores: scores,
            pitchType: "Elevator Pitch",
            recentSessions: [],
            heatmapSummary: "Keine Daten"
        )

        XCTAssertTrue(prompt.contains("Tim"))
        XCTAssertTrue(prompt.contains("Deutsch"))
        XCTAssertTrue(prompt.contains("74") || prompt.contains("Confidence"))
        XCTAssertTrue(prompt.contains("2-4"))
        XCTAssertTrue(prompt.contains("Starker Einstieg"))
        XCTAssertTrue(prompt.contains("Tempo"))
    }

    func testGamificationAfterSession() {
        memoryManager.seedDefaultPitchTypes()
        let scores = DimensionScores(
            confidence: 74, energy: 68, tempo: 55,
            clarity: 72, stability: 61, charisma: 66
        )
        let session = CompletedSession(
            id: UUID(),
            date: Date(),
            pitchType: "Elevator Pitch",
            duration: 45,
            scores: scores,
            featureZScores: [:],
            transcription: "Test",
            quickFeedback: "Good.",
            deepCoaching: nil,
            heatmapData: HeatmapData(segments: [])
        )

        memoryManager.saveSession(session)
        XCTAssertEqual(memoryManager.sessionsThisWeek(), 1)
        XCTAssertEqual(memoryManager.totalSessionCount(), 1)
        XCTAssertEqual(memoryManager.scoreHistory(lastDays: 7).count, 1)
    }

    func testAverageScores() {
        let scores1 = DimensionScores(confidence: 60, energy: 70, tempo: 50, clarity: 65, stability: 55, charisma: 60)
        let scores2 = DimensionScores(confidence: 80, energy: 70, tempo: 70, clarity: 75, stability: 65, charisma: 80)

        memoryManager.saveSession(CompletedSession(id: UUID(), date: Date(), pitchType: "Test", duration: 30, scores: scores1, featureZScores: [:], transcription: "", quickFeedback: "", deepCoaching: nil, heatmapData: HeatmapData(segments: [])))
        memoryManager.saveSession(CompletedSession(id: UUID(), date: Date(), pitchType: "Test", duration: 30, scores: scores2, featureZScores: [:], transcription: "", quickFeedback: "", deepCoaching: nil, heatmapData: HeatmapData(segments: [])))

        let avg = memoryManager.averageScores(lastDays: 7)
        XCTAssertNotNil(avg)
        XCTAssertEqual(avg?.confidence ?? -1, 70.0, accuracy: 0.1)
        XCTAssertEqual(avg?.energy ?? -1, 70.0, accuracy: 0.1)
    }

    private func syntheticFeatureDictionary() -> [String: Double] {
        [
            "F0semitoneFrom27.5Hz_sma3nz_amean": 220.0,
            "F0semitoneFrom27.5Hz_sma3nz_stddevNorm": 0.15,
            "F0semitoneFrom27.5Hz_sma3nz_percentile99.0": 280.0,
            "F0semitoneFrom27.5Hz_sma3nz_percentile1.0": 180.0,
            "jitterLocal_sma3nz_amean": 0.015,
            "shimmerLocaldB_sma3nz_amean": 0.35,
            "Loudness_sma3_amean": 0.65,
            "HNRdBACF_sma3nz_amean": 15.0,
            "F1frequency_sma3nz_amean": 500.0,
            "F2frequency_sma3nz_amean": 1500.0,
            "F3frequency_sma3nz_amean": 2500.0,
            "F1bandwidth_sma3nz_amean": 80.0,
            "VoicedSegmentsPerSec": 4.0,
            "MeanUnvoicedSegmentLength": 0.15,
        ]
    }

    private func toVoiceFeatures(_ raw: [String: Double]) -> VoiceFeatures {
        let m = FeatureKeyMapper.normalize(raw)
        return VoiceFeatures(
            f0Mean: m[FeatureKeys.f0Mean] ?? 0,
            f0Variability: m[FeatureKeys.f0Variability] ?? 0,
            f0Range: m[FeatureKeys.f0Range] ?? 0,
            jitter: m[FeatureKeys.jitter] ?? 0,
            shimmer: m[FeatureKeys.shimmer] ?? 0,
            speechRate: m[FeatureKeys.speechRate] ?? 0,
            energy: m[FeatureKeys.energy] ?? 0,
            hnr: m[FeatureKeys.hnr] ?? 0,
            f1: m[FeatureKeys.f1] ?? 0,
            f2: m[FeatureKeys.f2] ?? 0,
            f3: m[FeatureKeys.f3] ?? 0,
            f4: m[FeatureKeys.f1Bandwidth] ?? 0,
            pauseDuration: m[FeatureKeys.pauseDuration] ?? 0,
            pauseDistribution: m[FeatureKeys.pauseDistribution] ?? 0
        )
    }
}
