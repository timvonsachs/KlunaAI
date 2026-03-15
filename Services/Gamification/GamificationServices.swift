import Foundation
import CoreData

// MARK: - Streak Manager

/// Tracks weekly session goals and consecutive streak weeks.
final class StreakManager: ObservableObject {
    @Published var currentStreak: Streak

    private let memoryManager: MemoryManager
    private let calendar: Calendar

    private enum Keys {
        static let weeklyGoal = "streak.weeklyGoal"
        static let currentStreak = "streak.currentStreak"
        static let lastCheckedWeekStart = "streak.lastCheckedWeekStart"
        static let freezesUsedMonth = "streak.freezesUsedThisMonth"
    }

    init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        self.calendar = cal

        let weeklyGoal = UserDefaults.standard.integer(forKey: Keys.weeklyGoal)
        let goal = [3, 5, 7].contains(weeklyGoal) ? weeklyGoal : 3
        let streak = UserDefaults.standard.integer(forKey: Keys.currentStreak)
        let used = UserDefaults.standard.integer(forKey: Keys.freezesUsedMonth)
        let initialFreezes = SubscriptionManager.shared.tier == .free ? max(0, 1 - used) : Int.max
        self.currentStreak = Streak(
            currentWeeks: streak,
            weeklyGoal: goal,
            sessionsThisWeek: memoryManager.sessionsThisWeek(),
            freezesRemaining: initialFreezes
        )
    }

    func recordSession() {
        refreshState()
    }

    @discardableResult
    func useFreeze() -> Bool {
        guard freezesRemaining(for: Date()) > 0 else { return false }
        let used = UserDefaults.standard.integer(forKey: Keys.freezesUsedMonth)
        UserDefaults.standard.set(used + 1, forKey: Keys.freezesUsedMonth)
        refreshState()
        return true
    }

    func setWeeklyGoal(_ goal: Int) {
        guard [3, 5, 7].contains(goal) else { return }
        UserDefaults.standard.set(goal, forKey: Keys.weeklyGoal)
        var user = memoryManager.loadUser()
        user = KlunaUser(
            name: user.name,
            language: user.language,
            firstSessionDate: user.firstSessionDate,
            totalSessions: user.totalSessions,
            weeklyGoal: goal,
            currentStreak: user.currentStreak,
            strengths: user.strengths,
            weaknesses: user.weaknesses,
            longTermProfile: user.longTermProfile,
            teamCode: user.teamCode,
            role: user.role,
            voiceType: user.voiceType,
            goal: user.goal
        )
        memoryManager.saveUser(user)
        refreshState()
    }

    func checkWeekRollover() {
        let now = Date()
        let currentWeekStart = startOfWeek(for: now)
        let storedWeekStart = UserDefaults.standard.object(forKey: Keys.lastCheckedWeekStart) as? Date
        guard let lastChecked = storedWeekStart else {
            UserDefaults.standard.set(currentWeekStart, forKey: Keys.lastCheckedWeekStart)
            refreshState()
            return
        }

        guard currentWeekStart > lastChecked else {
            refreshState()
            return
        }

        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) ?? lastChecked
        let lastWeekEnd = calendar.date(byAdding: .second, value: -1, to: currentWeekStart) ?? now
        let lastWeekSessions = countSessions(from: lastWeekStart, to: lastWeekEnd)
        let goal = weeklyGoal()
        var streak = UserDefaults.standard.integer(forKey: Keys.currentStreak)

        if lastWeekSessions >= goal {
            streak += 1
        } else {
            if !useFreeze() {
                streak = 0
            }
        }

        UserDefaults.standard.set(streak, forKey: Keys.currentStreak)
        UserDefaults.standard.set(currentWeekStart, forKey: Keys.lastCheckedWeekStart)
        refreshState()
    }

    private func refreshState() {
        let next = Streak(
            currentWeeks: UserDefaults.standard.integer(forKey: Keys.currentStreak),
            weeklyGoal: weeklyGoal(),
            sessionsThisWeek: memoryManager.sessionsThisWeek(),
            freezesRemaining: freezesRemaining(for: Date())
        )
        if Thread.isMainThread {
            currentStreak = next
        } else {
            DispatchQueue.main.async {
                self.currentStreak = next
            }
        }
    }

    private func weeklyGoal() -> Int {
        let stored = UserDefaults.standard.integer(forKey: Keys.weeklyGoal)
        return [3, 5, 7].contains(stored) ? stored : 3
    }

    private func startOfWeek(for date: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func countSessions(from: Date, to: Date) -> Int {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", from as NSDate, to as NSDate)
        return (try? context.count(for: request)) ?? 0
    }

    private func freezesRemaining(for date: Date) -> Int {
        if SubscriptionManager.shared.tier != .free { return Int.max }
        let used = UserDefaults.standard.integer(forKey: Keys.freezesUsedMonth)
        return max(0, 1 - used)
    }
}

// MARK: - Challenge Manager

/// Manages weekly and monthly challenges with auto-rotation.
final class ChallengeManager: ObservableObject {
    @Published var activeChallenges: [Challenge] = []

    private let memoryManager: MemoryManager
    private let context: NSManagedObjectContext

    private let weeklyTemplates: [(titleDe: String, titleEn: String, type: ChallengeType, target: Double)] = [
        ("Score Boost", "Score Boost", .improveScore, 5),
        ("Vielseitigkeit", "Versatility", .pitchVariety, 3),
        ("Energie-Kick", "Energy Kick", .improveScore, 80),
        ("Konstanz", "Consistency", .sessionCount, 5),
        ("Schwaeche knacken", "Crush Weakness", .improveWeakest, 10),
    ]

    init(memoryManager: MemoryManager) {
        self.memoryManager = memoryManager
        self.context = PersistenceController.shared.container.viewContext
    }

    func loadOrGenerateChallenges() {
        let request: NSFetchRequest<CDChallenge> = CDChallenge.fetchRequest()
        let entities = (try? context.fetch(request)) ?? []
        let loaded = entities.map { $0.toChallenge() }.filter { $0.expiresAt > Date() }
        setActiveChallenges(loaded)
        if loaded.isEmpty {
            let generated = generateChallenges()
            setActiveChallenges(generated)
            persist(challenges: generated)
        }
    }

    func updateProgress(scores: DimensionScores, pitchType: String, previousWeakest: PerformanceDimension?) {
        var updated = activeChallenges
        for idx in updated.indices {
            switch updated[idx].type {
            case .sessionCount, .streakWeek:
                updated[idx].progress += 1
            case .pitchVariety:
                updated[idx].progress = Double(Set(memoryManager.recentSessions(count: 30).map(\.pitchType)).count)
            case .improveScore:
                updated[idx].progress = max(updated[idx].progress, scores.confidence)
            case .improveWeakest:
                if previousWeakest == .confidence {
                    updated[idx].progress = max(updated[idx].progress, scores.confidence)
                } else {
                    updated[idx].progress += 1
                }
            default:
                break
            }
        }
        setActiveChallenges(updated)
        persist(challenges: updated)
    }

    func checkExpiry() {
        let now = Date()
        var updated = activeChallenges.filter { $0.expiresAt > now }
        if updated.count < 3 {
            updated.append(contentsOf: generateChallenges(count: 3 - updated.count))
        }
        setActiveChallenges(updated)
        persist(challenges: updated)
    }

    private func generateChallenges(count: Int = 3) -> [Challenge] {
        let language = memoryManager.loadUser().language
        let weekly = weeklyTemplates.shuffled().prefix(max(1, min(2, count)))
        var result: [Challenge] = weekly.map { template in
            Challenge(
                id: UUID(),
                title: language == "de" ? template.titleDe : template.titleEn,
                description: language == "de" ? "Wochen-Challenge" : "Weekly challenge",
                type: template.type,
                target: template.target,
                progress: 0,
                expiresAt: endOfCurrentWeek()
            )
        }
        if result.count < count {
            result.append(
                Challenge(
                    id: UUID(),
                    title: language == "de" ? "Monats-Momentum" : "Monthly Momentum",
                    description: language == "de" ? "30 Sessions im Monat" : "30 sessions this month",
                    type: .sessionCount,
                    target: 30,
                    progress: Double(memoryManager.totalSessionCount() % 30),
                    expiresAt: endOfCurrentMonth()
                )
            )
        }
        return result
    }

    private func persist(challenges: [Challenge]) {
        context.performAndWait {
            let request: NSFetchRequest<CDChallenge> = CDChallenge.fetchRequest()
            let existing = (try? context.fetch(request)) ?? []
            existing.forEach { context.delete($0) }
            challenges.forEach { _ = CDChallenge.from($0, context: context) }
            try? context.save()
        }
    }

    private func setActiveChallenges(_ value: [Challenge]) {
        if Thread.isMainThread {
            activeChallenges = value
        } else {
            DispatchQueue.main.async {
                self.activeChallenges = value
            }
        }
    }

    private func endOfCurrentWeek() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return cal.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) ?? Date()
    }

    private func endOfCurrentMonth() -> Date {
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .month, for: Date())
        return interval?.end.addingTimeInterval(-1) ?? Date()
    }
}

// MARK: - Leaderboard Manager

/// Manages global and team leaderboards.
/// MVP: Local-only. Later: backend sync.
final class LeaderboardManager: ObservableObject {
    @Published var globalTopScore: [LeaderboardEntry] = []
    @Published var globalTopImprovement: [LeaderboardEntry] = []
    @Published var teamTopScore: [LeaderboardEntry] = []
    @Published var teamTopImprovement: [LeaderboardEntry] = []

    func fetchGlobalLeaderboard(tab: LeaderboardTab) async {
        let names = ["SpeakPro_DE", "PitchKing", "VoiceMaster", "SalesGuru", "AlphaCloser", "NoraPitch", "QuietVoice", "ColdCallAce", "DealMaker", "PowerTalk", "RhetoricFox", "StrongTone", "GrowthSpeaker", "BrightPitch", "CloserMax"]
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "Du"
        let myScore = (PersistenceController.shared.container.viewContext.performAndWait { () -> Double in
            let mm = MemoryManager(context: PersistenceController.shared.container.viewContext)
            return mm.averageScores(last: 7)?.overall ?? 74
        })
        var entries = names.enumerated().map { idx, name in
            LeaderboardEntry(id: UUID().uuidString, username: name, score: max(40, 92 - Double(idx * 2)), rank: idx + 1, isCurrentUser: false)
        }
        entries.append(LeaderboardEntry(id: "currentUser", username: userName, score: myScore, rank: 0, isCurrentUser: true))
        entries.sort(by: { $0.score > $1.score })
        let ranked = entries.enumerated().map { i, e in
            LeaderboardEntry(id: e.id, username: e.username, score: e.score, rank: i + 1, isCurrentUser: e.isCurrentUser)
        }
        if tab == .topScore {
            setGlobalTopScore(ranked)
        } else {
            let mapped = ranked.map {
                LeaderboardEntry(id: $0.id, username: $0.username, score: max(1, ($0.score - 50) / 5), rank: $0.rank, isCurrentUser: $0.isCurrentUser)
            }
            setGlobalTopImprovement(mapped)
        }
    }

    func fetchTeamLeaderboard(teamCode: String, tab: LeaderboardTab) async {
        await fetchGlobalLeaderboard(tab: tab)
        if tab == .topScore {
            setTeamTopScore(Array(globalTopScore.prefix(10)))
        } else {
            setTeamTopImprovement(Array(globalTopImprovement.prefix(10)))
        }
    }

    func submitScore(username: String, averageScore: Double, improvement: Double) async {
        // Local MVP: no-op
    }

    private func setGlobalTopScore(_ value: [LeaderboardEntry]) {
        if Thread.isMainThread {
            globalTopScore = value
        } else {
            DispatchQueue.main.async {
                self.globalTopScore = value
            }
        }
    }

    private func setGlobalTopImprovement(_ value: [LeaderboardEntry]) {
        if Thread.isMainThread {
            globalTopImprovement = value
        } else {
            DispatchQueue.main.async {
                self.globalTopImprovement = value
            }
        }
    }

    private func setTeamTopScore(_ value: [LeaderboardEntry]) {
        if Thread.isMainThread {
            teamTopScore = value
        } else {
            DispatchQueue.main.async {
                self.teamTopScore = value
            }
        }
    }

    private func setTeamTopImprovement(_ value: [LeaderboardEntry]) {
        if Thread.isMainThread {
            teamTopImprovement = value
        } else {
            DispatchQueue.main.async {
                self.teamTopImprovement = value
            }
        }
    }
}
