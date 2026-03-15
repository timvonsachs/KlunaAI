import CoreData
import Foundation

final class MemoryManager {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func saveSession(_ session: CompletedSession) {
        context.performAndWait {
            _ = CDSession.from(session, context: context)
            saveContext()
        }
    }

    func recentSessions(count: Int = Config.recentSessionsCount) -> [SessionSummary] {
        context.performAndWait {
            let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.fetchLimit = count
            return ((try? context.fetch(request)) ?? []).map { $0.toSessionSummary() }
        }
    }

    func recentOverallScores(limit: Int = 10, oldestFirst: Bool = true) -> [Double] {
        let sessions = recentSessions(count: limit)
        let scores = sessions.map(\.overallScore)
        return oldestFirst ? scores.reversed() : scores
    }

    func allSessions() -> [CompletedSession] {
        context.performAndWait {
            let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            return ((try? context.fetch(request)) ?? []).map { $0.toCompletedSession() }
        }
    }

    func averageScores(last days: Int = 7) -> DimensionScores? {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return nil }
        return averageScores(from: start, to: Date())
    }

    func averageScores(lastDays: Int) -> DimensionScores? {
        averageScores(last: lastDays)
    }

    func allTimeBestScore() -> Double? {
        context.performAndWait {
            let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "overallScore", ascending: false)]
            request.fetchLimit = 1
            return try? context.fetch(request).first?.overallScore
        }
    }

    func personalBestSession() -> SessionSummary? {
        recentSessions(count: 9999).max(by: { $0.overallScore < $1.overallScore })
    }

    func personalBest(for pitchType: String) -> SessionSummary? {
        recentSessions(count: 9999)
            .filter { $0.pitchType == pitchType }
            .max(by: { $0.overallScore < $1.overallScore })
    }

    func personalBestScores() -> DimensionScores? {
        personalBestSession()?.scores
    }

    func initialBaselineScores() -> DimensionScores? {
        let sessions = recentSessions(count: 9999)
        guard sessions.count >= 3 else { return nil }
        let oldest3 = Array(sessions.suffix(3))
        let c = 3.0
        return DimensionScores(
            confidence: oldest3.map { $0.scores.confidence }.reduce(0, +) / c,
            energy: oldest3.map { $0.scores.energy }.reduce(0, +) / c,
            tempo: oldest3.map { $0.scores.tempo }.reduce(0, +) / c,
            clarity: oldest3.map { $0.scores.clarity }.reduce(0, +) / c,
            stability: oldest3.map { $0.scores.stability }.reduce(0, +) / c,
            charisma: oldest3.map { $0.scores.charisma }.reduce(0, +) / c
        )
    }

    func totalSessionCount() -> Int {
        context.performAndWait {
            let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
            return (try? context.count(for: request)) ?? 0
        }
    }

    func sessionsThisWeek() -> Int {
        let now = Date()
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return countSessions(from: start, to: now)
    }

    func sessionsInLast(days: Int) -> Int {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return 0 }
        return countSessions(from: start, to: Date())
    }

    func consecutiveDaysWithSessions() -> Int {
        let summaries = recentSessions(count: 9999)
        let dates = summaries.compactMap(\.dateAsDate)
        guard !dates.isEmpty else { return 0 }

        let calendar = Calendar.current
        let activeDays = Set(dates.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while activeDays.contains(checkDate) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previous
        }

        return streak
    }

    func scoreHistory(lastDays: Int = 90) -> [DailyScoreSummary] {
        guard let start = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date()) else { return [] }
        let sessions = fetchSessions(from: start, to: Date())
        let grouped = Dictionary(grouping: sessions) { Calendar.current.startOfDay(for: $0.date ?? Date()) }
        return grouped.map { date, daySessions in
            let c = Double(daySessions.count)
            return DailyScoreSummary(
                date: date,
                averageOverall: daySessions.map(\.overallScore).reduce(0, +) / c,
                averageConfidence: daySessions.map(\.confidenceScore).reduce(0, +) / c,
                averageEnergy: daySessions.map(\.energyScore).reduce(0, +) / c,
                averageTempo: daySessions.map(\.tempoScore).reduce(0, +) / c,
                averageClarity: daySessions.map(\.clarityScore).reduce(0, +) / c,
                averageStability: daySessions.map(\.stabilityScore).reduce(0, +) / c,
                averageCharisma: daySessions.map(\.charismaScore).reduce(0, +) / c,
                sessionCount: daySessions.count
            )
        }.sorted(by: { $0.date < $1.date })
    }

    func shouldGenerateProfile(for user: KlunaUser) -> Bool {
        totalSessionCount() >= Config.profileTriggerSessions && user.longTermProfile == nil
    }

    func updateStrengths(_ strengths: [String], weaknesses: [String], for user: inout KlunaUser) {
        user.strengths = Array(strengths.prefix(Config.maxStrengths))
        user.weaknesses = Array(weaknesses.prefix(Config.maxWeaknesses))
        saveUser(user)
    }

    func saveLongTermProfile(_ profile: String, for user: inout KlunaUser) {
        user.longTermProfile = profile
        saveUser(user)
    }

    func loadUser() -> KlunaUser {
        context.performAndWait {
            let request: NSFetchRequest<CDUserProfile> = CDUserProfile.fetchRequest()
            if let profile = try? context.fetch(request).first {
                return profile.toKlunaUser(totalSessions: totalSessionCount())
            }
            let newUser = KlunaUser(
                name: UserDefaults.standard.string(forKey: "userName") ?? "User",
                language: UserDefaults.standard.string(forKey: "appLanguage") ?? "en",
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
            saveUser(newUser)
            return newUser
        }
    }

    func saveUser(_ user: KlunaUser) {
        context.performAndWait {
            let request: NSFetchRequest<CDUserProfile> = CDUserProfile.fetchRequest()
            let profile = (try? context.fetch(request).first) ?? CDUserProfile.from(user, context: context)
            profile.apply(user: user)
            saveContext()
        }
    }

    func seedDefaultPitchTypes() {
        context.performAndWait {
            let request: NSFetchRequest<CDPitchType> = CDPitchType.fetchRequest()
            let existing = (try? context.fetch(request)) ?? []
            let existingNames = Set(existing.compactMap(\.name))
            PitchType.defaults
                .filter { !existingNames.contains($0.name) }
                .forEach { _ = CDPitchType.from($0, context: context) }
            saveContext()
        }
    }

    func allPitchTypes() -> [PitchType] {
        context.performAndWait {
            let request: NSFetchRequest<CDPitchType> = CDPitchType.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            return ((try? context.fetch(request)) ?? []).map { $0.toPitchType() }
        }
    }

    func averageScores(weekOffset: Int) -> DimensionScores? {
        let calendar = Calendar.current
        let now = Date()
        guard let targetWeek = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: now),
              let interval = calendar.dateInterval(of: .weekOfYear, for: targetWeek) else {
            return nil
        }
        return averageScores(from: interval.start, to: interval.end)
    }

    private func averageScores(from start: Date, to end: Date) -> DimensionScores? {
        let sessions = fetchSessions(from: start, to: end)
        guard !sessions.isEmpty else { return nil }
        let c = Double(sessions.count)
        return DimensionScores(
            confidence: sessions.map(\.confidenceScore).reduce(0, +) / c,
            energy: sessions.map(\.energyScore).reduce(0, +) / c,
            tempo: sessions.map(\.tempoScore).reduce(0, +) / c,
            clarity: sessions.map(\.clarityScore).reduce(0, +) / c,
            stability: sessions.map(\.stabilityScore).reduce(0, +) / c,
            charisma: sessions.map(\.charismaScore).reduce(0, +) / c
        )
    }

    private func fetchSessions(from start: Date, to end: Date) -> [CDSession] {
        context.performAndWait {
            let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
            request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
            return (try? context.fetch(request)) ?? []
        }
    }

    private func countSessions(from start: Date, to end: Date) -> Int {
        context.performAndWait {
            let request: NSFetchRequest<CDSession> = CDSession.fetchRequest()
            request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
            return (try? context.count(for: request)) ?? 0
        }
    }

    private func saveContext() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
