import XCTest
@testable import KlunaAI

final class ClaudeServiceTests: XCTestCase {
    func testMissingAPIKeyThrowsForInsightsRequest() async {
        do {
            _ = try await CoachAPIManager.requestInsights(
                payload: "Test payload",
                systemPrompt: "Test system",
                maxTokens: 50,
                apiKey: ""
            )
            XCTFail("Expected missing API key error")
        } catch let error as CoachAPIError {
            if case .missingAPIKey = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Unexpected CoachAPIError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testConfigAPIKeyIsAvailableAsString() {
        XCTAssertNotNil(Config.claudeAPIKey)
    }
}
