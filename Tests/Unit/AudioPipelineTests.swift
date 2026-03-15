import XCTest
@testable import KlunaAI

final class AudioPipelineTests: XCTestCase {
    func testPipelineInit() {
        let pipeline = AudioPipelineManager(language: "en")
        XCTAssertNotNil(pipeline)
    }
}
