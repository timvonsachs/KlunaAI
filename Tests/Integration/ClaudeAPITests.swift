import XCTest
@testable import KlunaAI

final class ClaudeAPITests: XCTestCase {
    func testInsightsRequestReturnsText() async throws {
        guard ProcessInfo.processInfo.environment["RUN_LIVE_CLAUDE_TESTS"] == "true" else {
            throw XCTSkip("Live Claude smoke tests are disabled. Set RUN_LIVE_CLAUDE_TESTS=true for manual run.")
        }
        guard !Config.claudeAPIKey.isEmpty else {
            throw XCTSkip("No API key configured")
        }

        let feedback = try await CoachAPIManager.requestInsights(
            payload: "Give one concise coaching sentence for a confident pitch.",
            systemPrompt: "You are a concise speaking coach. Reply in one sentence.",
            maxTokens: 80,
            apiKey: Config.claudeAPIKey
        )

        XCTAssertFalse(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertLessThan(feedback.count, 1000)
    }
}
