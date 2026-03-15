import XCTest
@testable import KlunaAI

final class PromptBuilderTests: XCTestCase {
    func testQuickPromptGermanContainsCoachAndName() {
        let user = makeUser(language: "de", goal: .pitches)
        let prompt = PromptBuilder.buildQuickFeedbackPrompt(
            user: user,
            scores: makeScores(overall: 72),
            pitchType: "Elevator Pitch",
            recentSessions: [],
            heatmapSummary: "No data"
        )

        XCTAssertTrue(prompt.contains("Coach"))
        XCTAssertTrue(prompt.contains("Tim"))
        XCTAssertTrue(prompt.contains("2-4"))
    }

    func testQuickPromptEnglishContainsLanguageRule() {
        let user = makeUser(language: "en", goal: .content)
        let prompt = PromptBuilder.buildQuickFeedbackPrompt(
            user: user,
            scores: makeScores(overall: 70),
            pitchType: "Podcast Intro",
            recentSessions: [],
            heatmapSummary: "No data"
        )

        XCTAssertTrue(prompt.contains("ALWAYS respond in English"))
        XCTAssertTrue(prompt.contains("listener retention"))
    }

    func testDifferentGoalsProduceDifferentPrompts() {
        let scores = makeScores(overall: 68)
        let pitches = PromptBuilder.buildQuickFeedbackPrompt(
            user: makeUser(language: "de", goal: .pitches),
            scores: scores,
            pitchType: "Investor Pitch",
            recentSessions: [],
            heatmapSummary: "No data"
        )
        let interviews = PromptBuilder.buildQuickFeedbackPrompt(
            user: makeUser(language: "de", goal: .interviews),
            scores: scores,
            pitchType: "Why us?",
            recentSessions: [],
            heatmapSummary: "No data"
        )
        XCTAssertNotEqual(pitches, interviews)
    }

    func testDeepPromptContainsDeepCoachingMode() {
        let prompt = PromptBuilder.buildDeepCoachingPrompt(
            user: makeUser(language: "de", goal: .confidence),
            scores: makeScores(overall: 66),
            pitchType: "Free Practice",
            recentSessions: [],
            heatmapSummary: "No data"
        )
        XCTAssertTrue(prompt.contains("Deep Coaching") || prompt.contains("MODUS: Deep Coaching"))
        XCTAssertTrue(prompt.contains("Confidence"))
        XCTAssertTrue(prompt.contains("Charisma"))
    }

    func testWeeklyReportPromptContainsDeltaWhenPreviousExists() {
        let prompt = PromptBuilder.weeklyReportPrompt(
            sessions: [],
            user: makeUser(language: "en", goal: .pitches),
            currentAverage: makeScores(overall: 70),
            previousWeekAverage: makeScores(overall: 65)
        )
        XCTAssertTrue(prompt.contains("Delta overall"))
    }

    private func makeUser(language: String, goal: UserGoal) -> KlunaUser {
        KlunaUser(
            name: "Tim",
            language: language,
            firstSessionDate: Date().addingTimeInterval(-86400 * 10),
            totalSessions: 5,
            weeklyGoal: 3,
            currentStreak: 1,
            strengths: ["Tempo"],
            weaknesses: ["Stability"],
            longTermProfile: nil,
            teamCode: nil,
            role: .consumer,
            voiceType: .mid,
            goal: goal
        )
    }

    private func makeScores(overall: Double) -> DimensionScores {
        DimensionScores(
            confidence: overall + 5,
            energy: overall - 3,
            tempo: overall,
            clarity: overall + 2,
            stability: overall - 5,
            charisma: overall + 1
        )
    }
}
