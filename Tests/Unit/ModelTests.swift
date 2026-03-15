import XCTest
@testable import KlunaAI

final class ModelTests: XCTestCase {
    func testVoiceTypeCodable() throws {
        let original = VoiceType.high
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VoiceType.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testUserGoalCodable() throws {
        let original = UserGoal.content
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UserGoal.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func testDimensionScoresScoreForReturnsCorrectValues() {
        let scores = DimensionScores(
            confidence: 80,
            energy: 70,
            tempo: 60,
            clarity: 75,
            stability: 65,
            charisma: 85
        )
        XCTAssertEqual(scores.score(for: .confidence), 80)
        XCTAssertEqual(scores.score(for: .energy), 70)
        XCTAssertEqual(scores.score(for: .tempo), 60)
        XCTAssertEqual(scores.score(for: .clarity), 75)
        XCTAssertEqual(scores.score(for: .stability), 65)
        XCTAssertEqual(scores.score(for: .charisma), 85)
    }

    func testPerformanceDimensionCount() {
        XCTAssertEqual(PerformanceDimension.allCases.count, 6)
    }

    func testPitchTypeDefaultsAvailable() {
        XCTAssertGreaterThanOrEqual(PitchType.defaults.count, 10)
    }

    func testSessionSummaryIdIsStableFormat() {
        let scores = DimensionScores(confidence: 50, energy: 50, tempo: 50, clarity: 50, stability: 50, charisma: 50)
        let summary = SessionSummary(
            date: "2026-03-01",
            pitchType: "Test",
            overallScore: 72,
            weakestDimension: .tempo,
            scores: scores
        )
        XCTAssertTrue(summary.id.contains("2026-03-01"))
        XCTAssertTrue(summary.id.contains("Test"))
    }
}
