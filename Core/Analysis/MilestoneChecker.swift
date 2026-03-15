import Foundation

struct Milestone {
    let id: String
    let title: String
    let description: String
    let icon: String
}

final class MilestoneChecker {
    private let achievedKey = "achievedMilestones"

    func checkMilestones(consistency: ConsistencyResult, latestScore: Double) -> [Milestone] {
        var achieved = UserDefaults.standard.stringArray(forKey: achievedKey) ?? []
        var newMilestones: [Milestone] = []

        let checks: [(id: String, condition: Bool, milestone: Milestone)] = [
            ("sessions_5", consistency.totalSessions >= 5, .init(id: "sessions_5", title: "Erste Schritte", description: "5 Sessions abgeschlossen", icon: "🎯")),
            ("sessions_10", consistency.totalSessions >= 10, .init(id: "sessions_10", title: "Drangeblieben", description: "10 Sessions - deine Baseline steht", icon: "📊")),
            ("sessions_25", consistency.totalSessions >= 25, .init(id: "sessions_25", title: "Gewohnheit", description: "25 Sessions - das ist jetzt Routine", icon: "🔄")),
            ("sessions_50", consistency.totalSessions >= 50, .init(id: "sessions_50", title: "Hingabe", description: "50 Sessions - echtes Commitment", icon: "💪")),
            ("sessions_100", consistency.totalSessions >= 100, .init(id: "sessions_100", title: "Centurion", description: "100 Sessions - du bist unter den Top 1%", icon: "🏅")),
            ("streak_7", consistency.currentStreak >= 7, .init(id: "streak_7", title: "Wochenstreak", description: "7 Tage in Folge geübt", icon: "🔥")),
            ("streak_30", consistency.currentStreak >= 30, .init(id: "streak_30", title: "Monatsstreak", description: "30 Tage ohne Pause", icon: "🔥🔥")),
            ("score_70", latestScore >= 70, .init(id: "score_70", title: "Überzeugend", description: "Erstmals 70+ Punkte erreicht", icon: "⭐")),
            ("score_80", latestScore >= 80, .init(id: "score_80", title: "Stark", description: "Erstmals 80+ Punkte erreicht", icon: "🌟")),
            ("score_90", latestScore >= 90, .init(id: "score_90", title: "Außergewöhnlich", description: "Erstmals 90+ Punkte erreicht", icon: "✨")),
            ("consistency_60", consistency.overallConsistency >= 60, .init(id: "consistency_60", title: "Verlässlich", description: "Konsistenz-Score über 60", icon: "🎯")),
            ("consistency_80", consistency.overallConsistency >= 80, .init(id: "consistency_80", title: "Berechenbar gut", description: "Konsistenz-Score über 80", icon: "💎")),
            ("mastery_developing", consistency.masteryLevel.rawValue >= 2, .init(id: "mastery_developing", title: "Level Up: Aufsteiger", description: "Mastery-Level 2 erreicht", icon: "🌿")),
            ("mastery_competent", consistency.masteryLevel.rawValue >= 3, .init(id: "mastery_competent", title: "Level Up: Fortgeschritten", description: "Mastery-Level 3 erreicht", icon: "🌳")),
            ("mastery_proficient", consistency.masteryLevel.rawValue >= 4, .init(id: "mastery_proficient", title: "Level Up: Profi", description: "Mastery-Level 4 erreicht", icon: "⭐")),
            ("mastery_expert", consistency.masteryLevel.rawValue >= 5, .init(id: "mastery_expert", title: "Level Up: Meister", description: "Höchstes Mastery-Level erreicht", icon: "👑")),
        ]

        for check in checks where check.condition && !achieved.contains(check.id) {
            newMilestones.append(check.milestone)
            achieved.append(check.id)
        }

        UserDefaults.standard.set(achieved, forKey: achievedKey)
        return newMilestones
    }
}
