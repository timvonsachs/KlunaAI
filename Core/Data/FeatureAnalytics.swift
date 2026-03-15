import Foundation

final class FeatureAnalytics {
    static func analyze(logs: [SessionFeatureLog]) -> LogAnalytics {
        guard !logs.isEmpty else { return .empty }

        let overallScores = logs.compactMap(\.scoreOverall)
        let dates = logs.compactMap { ISO8601DateFormatter().date(from: $0.timestamp) }

        let scoreImprovement: Double
        if overallScores.count >= 10 {
            let firstHalf = Array(overallScores.prefix(overallScores.count / 2))
            let secondHalf = Array(overallScores.suffix(overallScores.count / 2))
            let firstAvg = firstHalf.reduce(0, +) / Double(max(1, firstHalf.count))
            let secondAvg = secondHalf.reduce(0, +) / Double(max(1, secondHalf.count))
            scoreImprovement = secondAvg - firstAvg
        } else {
            scoreImprovement = 0
        }

        let typeCounts = Dictionary(grouping: logs, by: { $0.practiceType })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }

        let avgDuration = logs.map(\.durationSeconds).reduce(0, +) / Double(logs.count)

        return LogAnalytics(
            totalSessions: logs.count,
            avgScore: overallScores.reduce(0, +) / Double(max(1, overallScores.count)),
            bestScore: overallScores.max() ?? 0,
            worstScore: overallScores.min() ?? 0,
            scoreImprovement: scoreImprovement,
            avgDuration: avgDuration,
            practiceTypeCounts: typeCounts.map { ($0.key, $0.value) },
            firstSessionDate: dates.min(),
            lastSessionDate: dates.max(),
            topCorrelations: calculateTopCorrelations(logs: logs)
        )
    }

    private static func calculateTopCorrelations(logs: [SessionFeatureLog]) -> [(feature: String, correlation: Double)] {
        guard logs.count >= 10 else { return [] }
        let aligned = logs.compactMap { log -> (SessionFeatureLog, Double)? in
            guard let score = log.scoreOverall else { return nil }
            return (log, score)
        }
        guard aligned.count >= 10 else { return [] }

        let scores = aligned.map(\.1)
        let baseLogs = aligned.map(\.0)
        let featureExtractors: [(String, (SessionFeatureLog) -> Double?)] = [
            ("loudnessRMS", { $0.loudnessRMS }),
            ("loudnessStdDev", { $0.loudnessStdDev }),
            ("f0Mean", { $0.f0Mean }),
            ("f0RangeST", { $0.f0RangeST }),
            ("f0StdDev", { $0.f0StdDev }),
            ("jitter", { $0.jitter }),
            ("shimmer", { $0.shimmer }),
            ("hnr", { $0.hnr }),
            ("speechRate", { $0.speechRate }),
            ("pauseRate", { $0.pauseRate }),
            ("warmthScore", { $0.warmthScore }),
            ("presenceScore", { $0.presenceScore }),
            ("intentionalityScore", { $0.intentionalityScore }),
        ]

        var correlations: [(String, Double)] = []
        for (name, extractor) in featureExtractors {
            let values = baseLogs.compactMap(extractor)
            guard values.count == scores.count else { continue }
            let corr = pearsonCorrelation(x: values, y: scores)
            if !corr.isNaN { correlations.append((name, corr)) }
        }

        return correlations
            .sorted { abs($0.1) > abs($1.1) }
            .map { (feature: $0.0, correlation: $0.1) }
    }

    private static func pearsonCorrelation(x: [Double], y: [Double]) -> Double {
        let n = Double(x.count)
        guard n >= 3 else { return 0 }

        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n
        var num: Double = 0
        var denomX: Double = 0
        var denomY: Double = 0

        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            num += dx * dy
            denomX += dx * dx
            denomY += dy * dy
        }

        let denom = sqrt(denomX * denomY)
        guard denom > 0 else { return 0 }
        return num / denom
    }
}

struct LogAnalytics {
    let totalSessions: Int
    let avgScore: Double
    let bestScore: Double
    let worstScore: Double
    let scoreImprovement: Double
    let avgDuration: Double
    let practiceTypeCounts: [(String, Int)]
    let firstSessionDate: Date?
    let lastSessionDate: Date?
    let topCorrelations: [(feature: String, correlation: Double)]

    static let empty = LogAnalytics(
        totalSessions: 0,
        avgScore: 0,
        bestScore: 0,
        worstScore: 0,
        scoreImprovement: 0,
        avgDuration: 0,
        practiceTypeCounts: [],
        firstSessionDate: nil,
        lastSessionDate: nil,
        topCorrelations: []
    )
}
