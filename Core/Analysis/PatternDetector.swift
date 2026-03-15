import Foundation

struct DetectedPattern {
    let id: String
    let description: String
    let confidence: Double
    let occurrences: Int
    let recommendation: String
    let category: PatternCategory
}

enum PatternCategory: String, Codable {
    case warning = "warnung"
    case positive = "positiv"
    case insight = "erkenntnis"
}

enum PatternDetector {
    static let minSessions = 15

    static func detect(logs: [SessionFeatureLog]) -> [DetectedPattern] {
        guard logs.count >= minSessions else { return [] }
        var patterns: [DetectedPattern] = []
        if let p = detectConsecutiveDrop(logs: logs) { patterns.append(p) }
        if let p = detectSpectralStressPattern(logs: logs) { patterns.append(p) }
        if let p = detectWarmUpEffect(logs: logs) { patterns.append(p) }
        if let p = detectStreakEffect(logs: logs) { patterns.append(p) }
        if let p = detectTimeOfDayEffect(logs: logs) { patterns.append(p) }
        return patterns.filter { $0.confidence >= 0.6 }
    }

    private static func detectConsecutiveDrop(logs: [SessionFeatureLog]) -> DetectedPattern? {
        let scores = logs.compactMap(\.scoreOverall)
        guard scores.count >= 10 else { return nil }
        var dropFollowedByBad = 0
        var dropTotal = 0

        for i in 2..<scores.count {
            if scores[i - 1] < scores[i - 2], scores[i - 2] - scores[i - 1] > 3 {
                dropTotal += 1
                if scores[i] < scores[i - 1] { dropFollowedByBad += 1 }
            }
        }

        guard dropTotal >= 3 else { return nil }
        let ratio = Double(dropFollowedByBad) / Double(dropTotal)
        guard ratio > 0.5 else { return nil }
        return DetectedPattern(
            id: "consecutive_drop",
            description: "Wenn dein Score 2x in Folge faellt, folgt oft ein weiterer Rueckgang.",
            confidence: ratio,
            occurrences: dropTotal,
            recommendation: "Nach zwei schwaecheren Sessions: Mach eine Aufwaerm-Uebung bevor du die naechste Session startest.",
            category: .warning
        )
    }

    private static func detectSpectralStressPattern(logs: [SessionFeatureLog]) -> DetectedPattern? {
        let presence = logs.compactMap(\.presenceScore)
        let body = logs.compactMap(\.bodyScore)
        let overall = logs.compactMap(\.scoreOverall)
        guard presence.count >= 10, presence.count == body.count, body.count == overall.count else { return nil }
        var stressBeforeBad = 0
        var stressTotal = 0
        for i in 1..<(presence.count - 1) {
            let presenceUp = presence[i] > presence[i - 1] + 5
            let bodyDown = body[i] < body[i - 1] - 5
            if presenceUp && bodyDown {
                stressTotal += 1
                if overall[i + 1] < overall[i] - 3 {
                    stressBeforeBad += 1
                }
            }
        }
        guard stressTotal >= 3 else { return nil }
        let ratio = Double(stressBeforeBad) / Double(stressTotal)
        guard ratio > 0.5 else { return nil }
        return DetectedPattern(
            id: "spectral_stress",
            description: "Deine Stimme verschiebt sich nach oben wenn du gestresst bist - weniger Brustton, mehr Anspannung.",
            confidence: ratio,
            occurrences: stressTotal,
            recommendation: "Wenn Kluna angespannt erkennt: 3 tiefe Atemzuege und bewusst tiefer sprechen.",
            category: .warning
        )
    }

    private static func detectWarmUpEffect(logs: [SessionFeatureLog]) -> DetectedPattern? {
        let formatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        var dayGroups: [String: [SessionFeatureLog]] = [:]
        for log in logs {
            guard let date = formatter.date(from: log.timestamp) else { continue }
            let key = calendar.startOfDay(for: date).description
            dayGroups[key, default: []].append(log)
        }
        let days = dayGroups.values.filter { $0.count >= 2 }
        guard days.count >= 5 else { return nil }

        var firstBetter = 0
        var secondBetter = 0
        for day in days {
            let sorted = day.sorted { $0.timestamp < $1.timestamp }
            let first = sorted[0].scoreOverall ?? 0
            let second = sorted[1].scoreOverall ?? 0
            if second > first + 2 { secondBetter += 1 }
            if first > second + 2 { firstBetter += 1 }
        }
        let total = firstBetter + secondBetter
        guard total >= 4 else { return nil }
        let ratio = Double(secondBetter) / Double(total)
        guard ratio > 0.6 else { return nil }

        return DetectedPattern(
            id: "warmup_effect",
            description: "Deine zweite Session am Tag ist meistens besser als die erste.",
            confidence: ratio,
            occurrences: secondBetter,
            recommendation: "Mach vor wichtigen Gespraechen eine kurze Warm-Up Session mit Kluna.",
            category: .insight
        )
    }

    private static func detectStreakEffect(logs: [SessionFeatureLog]) -> DetectedPattern? {
        guard logs.count >= 20 else { return nil }
        let formatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        var streakScores: [Double] = []
        var nonStreakScores: [Double] = []

        for (i, log) in logs.enumerated() {
            guard let score = log.scoreOverall, let currentDate = formatter.date(from: log.timestamp) else { continue }
            var hasYesterday = false
            var hasDayBefore = false
            for j in max(0, i - 5)..<i {
                guard let otherDate = formatter.date(from: logs[j].timestamp) else { continue }
                let dayDiff = calendar.dateComponents([.day], from: otherDate, to: currentDate).day ?? 0
                if dayDiff == 1 { hasYesterday = true }
                if dayDiff == 2 { hasDayBefore = true }
            }
            if hasYesterday && hasDayBefore { streakScores.append(score) } else { nonStreakScores.append(score) }
        }
        guard streakScores.count >= 5, nonStreakScores.count >= 5 else { return nil }
        let streakAvg = streakScores.reduce(0, +) / Double(streakScores.count)
        let nonStreakAvg = nonStreakScores.reduce(0, +) / Double(nonStreakScores.count)
        guard streakAvg > nonStreakAvg + 3 else { return nil }
        return DetectedPattern(
            id: "streak_effect",
            description: "Waehrend Streaks (3+ Tage) ist dein Score im Schnitt \(Int(streakAvg - nonStreakAvg)) Punkte hoeher.",
            confidence: min(1, (streakAvg - nonStreakAvg) / 15),
            occurrences: streakScores.count,
            recommendation: "Taegliches Ueben zahlt sich messbar aus. Halte deinen Streak!",
            category: .positive
        )
    }

    private static func detectTimeOfDayEffect(logs: [SessionFeatureLog]) -> DetectedPattern? {
        let formatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        var morning: [Double] = []
        var afternoon: [Double] = []
        var evening: [Double] = []
        for log in logs {
            guard let score = log.scoreOverall, let date = formatter.date(from: log.timestamp) else { continue }
            let hour = calendar.component(.hour, from: date)
            if (6..<12).contains(hour) { morning.append(score) }
            else if (12..<18).contains(hour) { afternoon.append(score) }
            else if (18..<24).contains(hour) { evening.append(score) }
        }
        let periods: [(String, [Double])] = [
            ("morgens (6-12 Uhr)", morning),
            ("nachmittags (12-18 Uhr)", afternoon),
            ("abends (18-24 Uhr)", evening)
        ].filter { $0.1.count >= 5 }
        guard periods.count >= 2 else { return nil }

        let avgs = periods.map { ($0.0, $0.1.reduce(0, +) / Double($0.1.count)) }
        guard let best = avgs.max(by: { $0.1 < $1.1 }),
              let worst = avgs.min(by: { $0.1 < $1.1 }) else { return nil }
        guard best.1 - worst.1 > 5 else { return nil }

        return DetectedPattern(
            id: "time_of_day",
            description: "Du sprichst am besten \(best.0) - im Schnitt \(Int(best.1 - worst.1)) Punkte mehr als \(worst.0).",
            confidence: min(1, (best.1 - worst.1) / 15),
            occurrences: periods.map { $0.1.count }.reduce(0, +),
            recommendation: "Leg wichtige Gespraeche und Praesentationen auf deinen Peak: \(best.0).",
            category: .insight
        )
    }
}
