import XCTest
import SwiftUI
@testable import KlunaAI

@MainActor
final class DeepVoiceIntelligenceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MentionTracker.shared.reset()
    }

    override func tearDown() {
        MentionTracker.shared.reset()
        super.tearDown()
    }

    func testLinguisticAnalysisDetectsHedging() {
        let text = "Eigentlich geht es mir vielleicht ganz gut irgendwie"
        let analysis = LinguisticAnalysis.analyze(transcript: text)
        XCTAssertGreaterThan(analysis.hedging, 0.3)
    }

    func testLinguisticAnalysisDetectsDistancing() {
        let text = "Man macht das halt so und dann ist es eben wie es ist"
        let analysis = LinguisticAnalysis.analyze(transcript: text)
        XCTAssertGreaterThan(analysis.distancing, 0.2)
    }

    func testLinguisticAnalysisDetectsSelfReference() {
        let text = "Ich bin heute gut drauf und ich habe mir vorgenommen mich mehr zu bewegen"
        let analysis = LinguisticAnalysis.analyze(transcript: text)
        XCTAssertGreaterThan(analysis.selfReference, 0.3)
    }

    func testLinguisticAnalysisNeutralTextLowScores() {
        let text = "Das Wetter ist heute schoen und die Sonne scheint."
        let analysis = LinguisticAnalysis.analyze(transcript: text)
        XCTAssertLessThan(analysis.hedging, 0.1)
        XCTAssertLessThan(analysis.distancing, 0.1)
        XCTAssertLessThan(analysis.negation, 0.1)
    }

    func testMentionTrackerCollectsAndReturnsReaction() {
        let dimsA = EngineVoiceDimensions(energy: 0.6, tension: 0.4, fatigue: 0.3, warmth: 0.7, expressiveness: 0.5, tempo: 0.55)
        let dimsB = EngineVoiceDimensions(energy: 0.5, tension: 0.5, fatigue: 0.35, warmth: 0.75, expressiveness: 0.45, tempo: 0.5)
        MentionTracker.shared.trackMention(word: "Lisa", segmentDimensions: dimsA)
        MentionTracker.shared.trackMention(word: "Lisa", segmentDimensions: dimsB)

        let reaction = MentionTracker.shared.reactionFor("Lisa")
        XCTAssertNotNil(reaction)
        XCTAssertEqual(reaction?.occurrences, 2)
        XCTAssertEqual(reaction?.mentionType, .person)
    }

    func testAbsenceDetectorFindsDisappearedTheme() {
        let now = Date()
        let older = [
            mockEntry(date: Calendar.current.date(byAdding: .day, value: -12, to: now)!, themes: ["arbeit"]),
            mockEntry(date: Calendar.current.date(byAdding: .day, value: -10, to: now)!, themes: ["arbeit", "app"]),
            mockEntry(date: Calendar.current.date(byAdding: .day, value: -9, to: now)!, themes: ["arbeit"]),
        ]
        let recent = [
            mockEntry(date: Calendar.current.date(byAdding: .day, value: -4, to: now)!, themes: ["app"]),
            mockEntry(date: Calendar.current.date(byAdding: .day, value: -2, to: now)!, themes: ["familie"]),
        ]

        let absences = AbsenceDetector.detectAbsences(recentEntries: recent, olderEntries: older)
        XCTAssertTrue(absences.contains(where: { $0.theme == "arbeit" }))
    }

    private func mockEntry(date: Date, themes: [String]) -> JournalEntry {
        JournalEntry(
            id: UUID(),
            date: date,
            duration: 60,
            transcript: "Testeintrag",
            audioRelativePath: nil,
            prompt: nil,
            mood: "ruhig",
            arousal: 45,
            acousticValence: 55,
            quadrant: .zufrieden,
            moodLabel: "Ruhig",
            coachText: nil,
            themes: themes,
            pillarVQ: 50,
            pillarClarity: 50,
            pillarDynamics: 50,
            pillarRhythm: 50,
            overallScore: 50,
            deltaArousal: 0,
            deltaValence: 0,
            rawFeatures: [:],
            f0Mean: 130,
            f0Range: 5,
            jitter: 0.025,
            shimmer: 0.16,
            hnr: 3.5,
            speechRate: 4.0,
            pauseRate: 20,
            loudnessMean: 0.04,
            loudnessRange: 25,
            flags: [],
            warmth: 0.5,
            stability: 0.5,
            energy: 0.5,
            tempo: 0.5,
            openness: 0.5
        )
    }
}
