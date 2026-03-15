import XCTest
import CoreData
@testable import KlunaAI

final class MemoryManagerTests: XCTestCase {
    private var memoryManager: MemoryManager!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        memoryManager = MemoryManager(context: context)
    }

    func testSaveAndLoadSession() {
        let session = createCompletedSession(overall: 72, pitchType: "Elevator Pitch")
        memoryManager.saveSession(session)
        let loaded = memoryManager.recentSessions(count: 10)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.pitchType, "Elevator Pitch")
        XCTAssertEqual(loaded.first?.overallScore ?? -1, session.scores.overall, accuracy: 0.001)
    }

    func testMultipleSessionsSortedByDateDesc() {
        let older = createCompletedSession(overall: 60, date: Date().addingTimeInterval(-3600))
        let newer = createCompletedSession(overall: 80, date: Date())
        memoryManager.saveSession(older)
        memoryManager.saveSession(newer)

        let loaded = memoryManager.recentSessions(count: 10)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded.first?.overallScore ?? -1, newer.scores.overall, accuracy: 0.001)
    }

    func testAverageScores7Days() {
        memoryManager.saveSession(createCompletedSession(overall: 60))
        memoryManager.saveSession(createCompletedSession(overall: 80))

        let avg = memoryManager.averageScores(lastDays: 7)
        XCTAssertNotNil(avg)
        XCTAssertEqual(avg?.overall ?? -1, 70, accuracy: 1.0)
    }

    func testAverageScoresEmptyReturnsNil() {
        XCTAssertNil(memoryManager.averageScores(lastDays: 7))
    }

    func testTotalSessionCount() {
        XCTAssertEqual(memoryManager.totalSessionCount(), 0)
        memoryManager.saveSession(createCompletedSession())
        memoryManager.saveSession(createCompletedSession())
        XCTAssertEqual(memoryManager.totalSessionCount(), 2)
    }

    func testSessionsThisWeek() {
        memoryManager.saveSession(createCompletedSession(date: Date()))
        memoryManager.saveSession(createCompletedSession(date: Date().addingTimeInterval(-10 * 86400)))
        XCTAssertEqual(memoryManager.sessionsThisWeek(), 1)
    }

    func testSaveAndLoadUser() {
        var user = makeUser()
        user.strengths = ["Confidence", "Energy"]
        memoryManager.saveUser(user)

        let loaded = memoryManager.loadUser()
        XCTAssertEqual(loaded.name, "Tim")
        XCTAssertEqual(loaded.language, "de")
        XCTAssertEqual(loaded.voiceType, .mid)
        XCTAssertEqual(loaded.goal, .pitches)
        XCTAssertEqual(loaded.strengths.count, 2)
    }

    func testUpdateStrengths() {
        var user = makeUser()
        memoryManager.saveUser(user)
        memoryManager.updateStrengths(["Tempo"], weaknesses: ["Stability"], for: &user)

        let loaded = memoryManager.loadUser()
        XCTAssertEqual(loaded.strengths, ["Tempo"])
        XCTAssertEqual(loaded.weaknesses, ["Stability"])
    }

    func testSeedDefaultPitchTypesAndIdempotency() {
        memoryManager.seedDefaultPitchTypes()
        let count1 = memoryManager.allPitchTypes().count
        memoryManager.seedDefaultPitchTypes()
        let count2 = memoryManager.allPitchTypes().count

        XCTAssertGreaterThan(count1, 5)
        XCTAssertEqual(count1, count2)
    }

    func testAllTimeBestScore() {
        let s1 = createCompletedSession(overall: 55)
        let s2 = createCompletedSession(overall: 88)
        let s3 = createCompletedSession(overall: 72)
        memoryManager.saveSession(s1)
        memoryManager.saveSession(s2)
        memoryManager.saveSession(s3)
        XCTAssertEqual(memoryManager.allTimeBestScore() ?? -1, s2.scores.overall, accuracy: 0.001)
    }

    func testScoreHistoryNotEmptyWithSessions() {
        memoryManager.saveSession(createCompletedSession(overall: 60))
        memoryManager.saveSession(createCompletedSession(overall: 80))
        XCTAssertFalse(memoryManager.scoreHistory(lastDays: 7).isEmpty)
    }

    private func createCompletedSession(
        overall: Double = 50,
        pitchType: String = "Free Practice",
        date: Date = Date()
    ) -> CompletedSession {
        let scores = DimensionScores(
            confidence: overall + 5,
            energy: overall - 3,
            tempo: overall,
            clarity: overall + 2,
            stability: overall - 5,
            charisma: overall + 1
        )
        return CompletedSession(
            id: UUID(),
            date: date,
            pitchType: pitchType,
            duration: 30,
            scores: scores,
            featureZScores: [:],
            transcription: "Test transcription",
            quickFeedback: "Test feedback",
            deepCoaching: nil,
            heatmapData: HeatmapData(segments: [])
        )
    }

    private func makeUser() -> KlunaUser {
        KlunaUser(
            name: "Tim",
            language: "de",
            firstSessionDate: Date(),
            totalSessions: 0,
            weeklyGoal: 3,
            currentStreak: 0,
            strengths: [],
            weaknesses: [],
            longTermProfile: nil,
            teamCode: nil,
            role: .consumer,
            voiceType: .mid,
            goal: .pitches
        )
    }
}
