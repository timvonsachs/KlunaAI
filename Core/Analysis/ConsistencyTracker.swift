import Foundation

struct ConsistencySnapshot: Codable {
    let date: Date
    let overallScore: Double
    let dimensionScores: [String: Double]
}

struct ConsistencyResult {
    let overallConsistency: Double
    let dimensionConsistency: [String: DimensionConsistency]
    let masteryLevel: MasteryLevel
    let currentStreak: Int
    let longestStreak: Int
    let totalSessions: Int
    let mostConsistent: String?
    let leastConsistent: String?
    let consistencyTrend: Double
}

struct DimensionConsistency {
    let mean: Double
    let stdDev: Double
    let coefficientOfVariation: Double
    let consistencyScore: Double
    let trend: Double
    let lastValue: Double
}

enum MasteryLevel: Int, Codable, CaseIterable {
    case beginner = 1
    case developing = 2
    case competent = 3
    case proficient = 4
    case expert = 5

    var title: String {
        switch self {
        case .beginner: return "Einsteiger"
        case .developing: return "Aufsteiger"
        case .competent: return "Fortgeschritten"
        case .proficient: return "Profi"
        case .expert: return "Meister"
        }
    }

    var icon: String {
        switch self {
        case .beginner: return "🌱"
        case .developing: return "🌿"
        case .competent: return "🌳"
        case .proficient: return "⭐"
        case .expert: return "👑"
        }
    }

    var colorHex: String {
        switch self {
        case .beginner: return "#88CC44"
        case .developing: return "#44BB88"
        case .competent: return "#4488CC"
        case .proficient: return "#7744CC"
        case .expert: return "#CC44BB"
        }
    }

    var description: String {
        switch self {
        case .beginner: return "Du baust gerade deine Baseline auf. Jede Session zählt."
        case .developing: return "Deine Stimme wird stabiler. Weiter so."
        case .competent: return "Du zeigst echte Konsistenz. Dein Stil formt sich."
        case .proficient: return "Deine Stimme ist verlässlich gut. Zeit für Feinschliff."
        case .expert: return "Stimmliche Meisterschaft. Konsistent auf hohem Niveau."
        }
    }

    var nextLevelSessions: Int {
        switch self {
        case .beginner: return 10
        case .developing: return 25
        case .competent: return 50
        case .proficient: return 100
        case .expert: return Int.max
        }
    }
}

final class ConsistencyTracker {
    private let storageKey = "consistencySnapshots"
    private(set) var snapshots: [ConsistencySnapshot] = []

    init() {
        loadSnapshots()
    }

    func recordSession(overallScore: Double, dimensionScores: [String: Double], date: Date = Date()) {
        let snapshot = ConsistencySnapshot(
            date: date,
            overallScore: overallScore,
            dimensionScores: dimensionScores
        )
        snapshots.append(snapshot)
        saveSnapshots()
    }

    func analyze() -> ConsistencyResult {
        let total = snapshots.count
        guard total >= 3 else {
            return ConsistencyResult(
                overallConsistency: 0,
                dimensionConsistency: [:],
                masteryLevel: .beginner,
                currentStreak: calculateCurrentStreak(),
                longestStreak: calculateLongestStreak(),
                totalSessions: total,
                mostConsistent: nil,
                leastConsistent: nil,
                consistencyTrend: 0
            )
        }

        let overallScores = snapshots.map(\.overallScore)
        let overallConsistency = calculateConsistencyScore(values: overallScores)

        let dimensionNames = ["confidence", "energy", "tempo", "stability", "charisma"]
        var dimConsistency: [String: DimensionConsistency] = [:]

        for dim in dimensionNames {
            let values = snapshots.compactMap { $0.dimensionScores[dim] }
            guard values.count >= 3 else { continue }

            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
            let stdDev = sqrt(variance)
            let cv = mean > 0 ? stdDev / mean : 1.0
            let consistency = calculateConsistencyScore(values: values)
            let trend = linearSlope(Array(values.suffix(10)))

            dimConsistency[dim] = DimensionConsistency(
                mean: mean,
                stdDev: stdDev,
                coefficientOfVariation: cv,
                consistencyScore: consistency,
                trend: trend,
                lastValue: values.last ?? 0
            )
        }

        let sorted = dimConsistency.sorted { $0.value.consistencyScore > $1.value.consistencyScore }
        let mostConsistent = sorted.first?.key
        let leastConsistent = sorted.last?.key
        let meanScore = overallScores.reduce(0, +) / Double(overallScores.count)
        let masteryLevel = determineMasteryLevel(sessions: total, consistency: overallConsistency, meanScore: meanScore)

        return ConsistencyResult(
            overallConsistency: overallConsistency,
            dimensionConsistency: dimConsistency,
            masteryLevel: masteryLevel,
            currentStreak: calculateCurrentStreak(),
            longestStreak: calculateLongestStreak(),
            totalSessions: total,
            mostConsistent: mostConsistent,
            leastConsistent: leastConsistent,
            consistencyTrend: calculateConsistencyTrend()
        )
    }

    private func calculateConsistencyScore(values: [Double]) -> Double {
        guard values.count >= 3 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        guard mean > 0 else { return 0 }
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean
        let score = 100 * exp(-cv * cv * 10)
        let sessionBonus = min(10, Double(values.count) / 5.0)
        return min(100, score + sessionBonus)
    }

    private func determineMasteryLevel(sessions: Int, consistency: Double, meanScore: Double) -> MasteryLevel {
        if sessions >= 100 && consistency >= 70 && meanScore >= 65 { return .expert }
        if sessions >= 50 && consistency >= 55 && meanScore >= 55 { return .proficient }
        if sessions >= 25 && consistency >= 40 { return .competent }
        if sessions >= 10 { return .developing }
        return .beginner
    }

    private func calculateConsistencyTrend() -> Double {
        guard snapshots.count >= 10 else { return 0 }
        let scores = snapshots.map(\.overallScore)
        let windowSize = 5
        var rollingCVs: [Double] = []

        for i in windowSize..<scores.count {
            let window = Array(scores[(i - windowSize)..<i])
            let mean = window.reduce(0, +) / Double(windowSize)
            guard mean > 0 else { continue }
            let variance = window.map { pow($0 - mean, 2) }.reduce(0, +) / Double(windowSize)
            rollingCVs.append(sqrt(variance) / mean)
        }

        guard rollingCVs.count >= 3 else { return 0 }
        return -linearSlope(rollingCVs) * 100
    }

    private func calculateCurrentStreak() -> Int {
        guard !snapshots.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 1
        var currentDate = calendar.startOfDay(for: Date())

        let todayHasSession = snapshots.contains { calendar.isDate($0.date, inSameDayAs: currentDate) }
        if !todayHasSession {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            let yesterdayHasSession = snapshots.contains { calendar.isDate($0.date, inSameDayAs: currentDate) }
            if !yesterdayHasSession { return 0 }
        }

        while true {
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            let hasSession = snapshots.contains { calendar.isDate($0.date, inSameDayAs: previousDate) }
            if hasSession {
                streak += 1
                currentDate = previousDate
            } else {
                break
            }
        }
        return streak
    }

    private func calculateLongestStreak() -> Int {
        guard !snapshots.isEmpty else { return 0 }
        let calendar = Calendar.current
        let uniqueDays = Set(snapshots.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !uniqueDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1
        for i in 1..<uniqueDays.count {
            let diff = calendar.dateComponents([.day], from: uniqueDays[i - 1], to: uniqueDays[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private func linearSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0 }
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for (index, value) in values.enumerated() {
            let x = Double(index)
            sumX += x
            sumY += value
            sumXY += x * value
            sumX2 += x * x
        }

        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / denom
    }

    private func loadSnapshots() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([ConsistencySnapshot].self, from: data)
        else {
            snapshots = []
            return
        }
        snapshots = decoded
    }

    private func saveSnapshots() {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
