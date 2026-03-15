import XCTest
@testable import KlunaAI

@MainActor
final class ViewModelTests: XCTestCase {
    private var viewModel: SessionViewModel!

    override func setUp() {
        super.setUp()
        viewModel = SessionViewModel()
    }

    func testInitialState() {
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.showScoreScreen)
        XCTAssertTrue(viewModel.quickFeedback.isEmpty)
        XCTAssertTrue(viewModel.transcription.isEmpty)
        XCTAssertNil(viewModel.currentScores)
    }

    func testResetClearsSessionState() {
        viewModel.quickFeedback = "Old feedback"
        viewModel.transcription = "Old transcription"
        viewModel.isNewHighScore = true
        viewModel.currentScores = DimensionScores(confidence: 70, energy: 70, tempo: 70, clarity: 70, stability: 70, charisma: 70)
        viewModel.deepCoaching = "Old deep coaching"
        viewModel.isLoadingDeepCoaching = true

        viewModel.resetForNewSession()

        XCTAssertTrue(viewModel.quickFeedback.isEmpty)
        XCTAssertTrue(viewModel.transcription.isEmpty)
        XCTAssertFalse(viewModel.isNewHighScore)
        XCTAssertNil(viewModel.currentScores)
        XCTAssertNil(viewModel.deepCoaching)
        XCTAssertFalse(viewModel.isLoadingDeepCoaching)
    }

    func testSelectedPitchTypeIsPreservedAfterReset() {
        let originalName = viewModel.selectedPitchType.name
        viewModel.resetForNewSession()
        XCTAssertEqual(viewModel.selectedPitchType.name, originalName)
    }

    func testRequestDeepCoachingWithoutScoresDoesNothing() async {
        viewModel.currentScores = nil
        await viewModel.requestDeepCoaching(transcription: "test")
        XCTAssertNil(viewModel.deepCoaching)
        XCTAssertFalse(viewModel.isLoadingDeepCoaching)
    }
}
