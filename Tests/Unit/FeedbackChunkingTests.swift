import XCTest
@testable import KlunaAI

final class FeedbackChunkingTests: XCTestCase {
    func testChunkingShowsThreeDimensionsEarly() {
        let scores = makeScores()
        let visible = ScoreView.computeVisibleDimensions(scores: scores, totalSessions: 3, hasDimensionAccess: true)
        XCTAssertEqual(visible.count, 3)
    }

    func testChunkingShowsAllAfterSessionSix() {
        let scores = makeScores()
        let visible = ScoreView.computeVisibleDimensions(scores: scores, totalSessions: 6, hasDimensionAccess: true)
        XCTAssertEqual(visible.count, 6)
    }

    func testFreeUserSeesNoDimensions() {
        let scores = makeScores()
        let visible = ScoreView.computeVisibleDimensions(scores: scores, totalSessions: 10, hasDimensionAccess: false)
        XCTAssertEqual(visible.count, 0)
    }

    func testChunkingShowsWeakestAndStrongest() {
        let scores = DimensionScores(
            confidence: 80,
            energy: 30,
            tempo: 60,
            clarity: 50,
            stability: 25,
            charisma: 70
        )
        let visible = ScoreView.computeVisibleDimensions(scores: scores, totalSessions: 3, hasDimensionAccess: true)
        XCTAssertEqual(visible.count, 3)
        XCTAssertTrue(visible.contains(.energy))
        XCTAssertTrue(visible.contains(.stability))
        XCTAssertTrue(visible.contains(.confidence))
    }

    private func makeScores() -> DimensionScores {
        DimensionScores(
            confidence: 62,
            energy: 66,
            tempo: 51,
            clarity: 55,
            stability: 59,
            charisma: 64
        )
    }
}
