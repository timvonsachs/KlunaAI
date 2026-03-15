import Foundation

struct LevelInfo {
    let level: Int
    let title: String
    let tierName: String
    let currentXP: Int
    let xpForNextLevel: Int
    let progress: Double
    let totalXP: Int
}

struct XPGain {
    let baseXP: Int
    let streakMultiplier: Double
    let predictionBonus: Int
    let exerciseBonus: Int
    let milestoneBonus: Int
    let totalXP: Int
    let breakdown: [(label: String, amount: Int)]
}

final class LevelEngine {
    static let shared = LevelEngine()
    private let xpKey = "totalXP"

    private let tiers: [(range: ClosedRange<Int>, name: String)] = [
        (1...5, "Stimm-Entdecker"),
        (6...10, "Stimm-Gestalter"),
        (11...15, "Stimm-Athlet"),
        (16...20, "Stimm-Künstler"),
        (21...25, "Stimm-Meister"),
        (26...99, "Stimm-Legende")
    ]

    private let levelTitles: [Int: String] = [
        1: "Erste Schritte", 2: "Neugierig", 3: "Drangeblieben", 4: "Routine", 5: "Entdecker",
        6: "Formgebend", 7: "Im Flow", 8: "Rhythmisch", 9: "Ausdrucksstark", 10: "Gestaltend",
        11: "Diszipliniert", 12: "Dynamisch", 13: "Fokussiert", 14: "Kraftvoll", 15: "Athlet",
        16: "Nuanciert", 17: "Melodisch", 18: "Resonant", 19: "Virtuos", 20: "Künstler",
        21: "Souverän", 22: "Beständig", 23: "Unerschütterlich", 24: "Brillant", 25: "Meister"
    ]

    func calculateXPGain(
        sessionScore: Double,
        streakDays: Int,
        predictionDelta: Double?,
        completedExercise: Bool,
        newMilestones: Int
    ) -> XPGain {
        let baseXP = Int(30 + (sessionScore / 100) * 40)
        let streakMultiplier: Double
        switch streakDays {
        case 0...1: streakMultiplier = 1.0
        case 2...3: streakMultiplier = 1.2
        case 4...6: streakMultiplier = 1.5
        case 7...13: streakMultiplier = 2.0
        case 14...29: streakMultiplier = 2.5
        default: streakMultiplier = 3.0
        }

        let predictionBonus: Int = {
            guard let predictionDelta, predictionDelta > 3 else { return 0 }
            return Int(predictionDelta * 3.0)
        }()
        let exerciseBonus = completedExercise ? 25 : 0
        let milestoneBonus = newMilestones * 50
        let subtotal = baseXP + predictionBonus + exerciseBonus + milestoneBonus
        let totalXP = Int(Double(subtotal) * streakMultiplier)

        var breakdown: [(String, Int)] = [("Session", baseXP)]
        if streakMultiplier > 1.0 {
            breakdown.append(("Streak ×\(String(format: "%.1f", streakMultiplier))", Int(Double(baseXP) * (streakMultiplier - 1.0))))
        }
        if predictionBonus > 0 { breakdown.append(("Überraschung", predictionBonus)) }
        if exerciseBonus > 0 { breakdown.append(("Übung", exerciseBonus)) }
        if milestoneBonus > 0 { breakdown.append(("Meilenstein", milestoneBonus)) }

        return XPGain(
            baseXP: baseXP,
            streakMultiplier: streakMultiplier,
            predictionBonus: predictionBonus,
            exerciseBonus: exerciseBonus,
            milestoneBonus: milestoneBonus,
            totalXP: totalXP,
            breakdown: breakdown
        )
    }

    func addXP(_ amount: Int) -> (newLevel: LevelInfo, leveledUp: Bool) {
        let currentTotal = UserDefaults.standard.integer(forKey: xpKey)
        let newTotal = currentTotal + amount
        UserDefaults.standard.set(newTotal, forKey: xpKey)
        let oldLevel = levelForXP(currentTotal)
        let newLevel = levelForXP(newTotal)
        return (newLevel, newLevel.level > oldLevel.level)
    }

    func levelForXP(_ totalXP: Int) -> LevelInfo {
        var xpRemaining = totalXP
        var level = 1

        while true {
            let xpNeeded = xpForLevel(level)
            if xpRemaining < xpNeeded {
                let tierName = tiers.first(where: { $0.range.contains(level) })?.name ?? "Stimm-Legende"
                let title = levelTitles[level] ?? "Level \(level)"
                return LevelInfo(
                    level: level,
                    title: title,
                    tierName: tierName,
                    currentXP: xpRemaining,
                    xpForNextLevel: xpNeeded,
                    progress: Double(xpRemaining) / Double(max(1, xpNeeded)),
                    totalXP: totalXP
                )
            }
            xpRemaining -= xpNeeded
            level += 1
        }
    }

    func getCurrentLevel() -> LevelInfo {
        levelForXP(UserDefaults.standard.integer(forKey: xpKey))
    }

    private func xpForLevel(_ level: Int) -> Int {
        100 + (level - 1) * 50
    }
}
