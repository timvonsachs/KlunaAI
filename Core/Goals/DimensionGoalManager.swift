import Foundation

struct DimensionGoal: Identifiable, Codable {
    let id: UUID
    let dimension: PerformanceDimension
    let targetScore: Double
    let startScore: Double
    let createdAt: Date
    var completedAt: Date?

    var isCompleted: Bool { completedAt != nil }
    var improvementNeeded: Double { targetScore - startScore }
}

struct GoalCompletionResult {
    let goal: DimensionGoal
    let achievedScore: Double
    let overachievement: Double
    let totalGoalsCompleted: Int
}

final class DimensionGoalManager {
    static let shared = DimensionGoalManager()

    private let userDefaults = UserDefaults.standard
    private let goalsKey = "dimensionGoals"

    private init() {}

    func generateGoalIfNeeded(currentScores: DimensionScores) -> DimensionGoal? {
        if let active = activeGoal(), !active.isCompleted {
            return nil
        }

        let weakest = weakestDimension(from: currentScores)
        let currentValue = currentScores.value(for: weakest)
        let target = nextGoalTarget(for: weakest, currentScore: currentValue)

        let goal = DimensionGoal(
            id: UUID(),
            dimension: weakest,
            targetScore: target,
            startScore: currentValue,
            createdAt: Date(),
            completedAt: nil
        )
        saveGoal(goal)
        return goal
    }

    func checkGoalCompletion(currentScores: DimensionScores) -> GoalCompletionResult? {
        guard var goal = activeGoal(), !goal.isCompleted else { return nil }
        let currentValue = currentScores.value(for: goal.dimension)
        guard currentValue >= goal.targetScore else { return nil }

        goal.completedAt = Date()
        updateGoal(goal)

        return GoalCompletionResult(
            goal: goal,
            achievedScore: currentValue,
            overachievement: currentValue - goal.targetScore,
            totalGoalsCompleted: completedGoalsCount()
        )
    }

    func activeGoal() -> DimensionGoal? {
        allGoals().first(where: { !$0.isCompleted })
    }

    func goalProgress(currentScores: DimensionScores) -> Double? {
        guard let goal = activeGoal() else { return nil }
        let currentValue = currentScores.value(for: goal.dimension)
        let totalNeeded = goal.targetScore - goal.startScore
        let achieved = currentValue - goal.startScore
        return totalNeeded > 0 ? achieved / totalNeeded : 1.0
    }

    func nextGoalTarget(for dimension: PerformanceDimension, currentScore: Double) -> Double {
        let completedForDimension = allGoals()
            .filter { $0.dimension == dimension && $0.isCompleted }
            .count

        let increment: Double
        switch completedForDimension {
        case 0...1: increment = 5
        case 2...3: increment = 7
        default: increment = 10
        }

        return min(currentScore + increment, 95)
    }

    func completedGoalsCount() -> Int {
        allGoals().filter { $0.isCompleted }.count
    }

    private func weakestDimension(from scores: DimensionScores) -> PerformanceDimension {
        let all: [(PerformanceDimension, Double)] = [
            (.confidence, scores.confidence),
            (.energy, scores.energy),
            (.tempo, scores.tempo),
            (.stability, scores.stability),
            (.charisma, scores.charisma),
        ]
        return all.min(by: { $0.1 < $1.1 })?.0 ?? .energy
    }

    private func allGoals() -> [DimensionGoal] {
        guard let data = userDefaults.data(forKey: goalsKey),
              let goals = try? JSONDecoder().decode([DimensionGoal].self, from: data) else {
            return []
        }
        return goals
    }

    private func saveGoal(_ goal: DimensionGoal) {
        var goals = allGoals()
        goals.insert(goal, at: 0)
        persist(goals)
    }

    private func updateGoal(_ goal: DimensionGoal) {
        var goals = allGoals()
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
            persist(goals)
        }
    }

    private func persist(_ goals: [DimensionGoal]) {
        if let data = try? JSONEncoder().encode(goals) {
            userDefaults.set(data, forKey: goalsKey)
        }
    }
}
