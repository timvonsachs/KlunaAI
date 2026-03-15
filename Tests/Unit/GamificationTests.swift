import XCTest
import CoreData
@testable import KlunaAI

final class GamificationTests: XCTestCase {
    private var memoryManager: MemoryManager!
    private var streakManager: StreakManager!
    private var challengeManager: ChallengeManager!

    override func setUp() {
        super.setUp()
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext

        UserDefaults.standard.removeObject(forKey: "streak.weeklyGoal")
        UserDefaults.standard.removeObject(forKey: "streak.currentStreak")
        UserDefaults.standard.removeObject(forKey: "streak.lastCheckedWeekStart")
        UserDefaults.standard.removeObject(forKey: "streak.freezesUsedThisMonth")

        memoryManager = MemoryManager(context: context)
        streakManager = StreakManager(memoryManager: memoryManager)
        challengeManager = ChallengeManager(memoryManager: memoryManager)
    }

    func testDefaultWeeklyGoalIsThree() {
        XCTAssertEqual(streakManager.currentStreak.weeklyGoal, 3)
    }

    func testRecordSessionReflectsSessionsThisWeek() {
        memoryManager.saveSession(makeSession())
        streakManager.recordSession()
        XCTAssertGreaterThanOrEqual(streakManager.currentStreak.sessionsThisWeek, 1)
    }

    func testSetWeeklyGoal() {
        streakManager.setWeeklyGoal(3)
        XCTAssertEqual(streakManager.currentStreak.weeklyGoal, 3)
    }

    func testWeeklyProgressCalculation() {
        memoryManager.saveSession(makeSession())
        memoryManager.saveSession(makeSession())
        streakManager.setWeeklyGoal(5)
        streakManager.recordSession()
        let progress = Double(streakManager.currentStreak.sessionsThisWeek) / Double(streakManager.currentStreak.weeklyGoal)
        XCTAssertEqual(progress, 0.4, accuracy: 0.01)
    }

    func testCheckWeekRolloverDoesNotCrash() {
        streakManager.checkWeekRollover()
        XCTAssertGreaterThanOrEqual(streakManager.currentStreak.currentWeeks, 0)
    }

    func testChallengeGenerationAndExpiryCheck() {
        challengeManager.loadOrGenerateChallenges()
        XCTAssertFalse(challengeManager.activeChallenges.isEmpty)
        challengeManager.checkExpiry()
        XCTAssertFalse(challengeManager.activeChallenges.isEmpty)
    }

    private func makeSession() -> CompletedSession {
        CompletedSession(
            id: UUID(),
            date: Date(),
            pitchType: "Free Practice",
            duration: 30,
            scores: DimensionScores(confidence: 70, energy: 70, tempo: 70, clarity: 70, stability: 70, charisma: 70),
            featureZScores: [:],
            transcription: "",
            quickFeedback: "",
            deepCoaching: nil,
            heatmapData: HeatmapData(segments: [])
        )
    }
}
