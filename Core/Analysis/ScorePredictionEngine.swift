import Foundation

struct ScorePrediction {
    let expectedScore: Double
    let confidence: Double
    let trend: PredictionTrend
    let basedOnSessions: Int

    func predictionError(actualScore: Double) -> PredictionError {
        let delta = actualScore - expectedScore
        let category: PredictionErrorCategory
        if delta > 8 {
            category = .strongPositive
        } else if delta > 3 {
            category = .positive
        } else if delta >= -3 {
            category = .neutral
        } else if delta >= -8 {
            category = .negative
        } else {
            category = .strongNegative
        }
        return PredictionError(expected: expectedScore, actual: actualScore, delta: delta, category: category)
    }
}

enum PredictionTrend: String, Codable {
    case rising = "aufwaerts"
    case stable = "stabil"
    case falling = "abwaerts"

    var icon: String {
        switch self {
        case .rising: return "↗️"
        case .stable: return "→"
        case .falling: return "↘️"
        }
    }
}

struct PredictionError {
    let expected: Double
    let actual: Double
    let delta: Double
    let category: PredictionErrorCategory

    var deltaString: String {
        if delta >= 0 { return "+\(Int(round(delta)))" }
        return "\(Int(round(delta)))"
    }

    var message: String {
        switch category {
        case .strongPositive:
            return "Deutlich ueber Erwartung! Dein bestes Ergebnis seit langem."
        case .positive:
            return "Ueber Erwartung! Du verbesserst dich."
        case .neutral:
            return "Im erwarteten Bereich. Solide Leistung."
        case .negative:
            return "Etwas unter Erwartung. Morgen wird besser."
        case .strongNegative:
            return "Nicht dein Tag - aber jeder hat solche Tage. Bleib dran."
        }
    }
}

enum PredictionErrorCategory {
    case strongPositive
    case positive
    case neutral
    case negative
    case strongNegative
}

final class ScorePredictionEngine {
    static let minimumSessions = 3

    static func predict(from recentScores: [Double]) -> ScorePrediction? {
        guard recentScores.count >= minimumSessions else { return nil }
        let scores = Array(recentScores.suffix(10))
        let n = scores.count

        var weightedSum = 0.0
        var totalWeight = 0.0
        for i in 0..<n {
            let weight = Double(i + 1)
            weightedSum += scores[i] * weight
            totalWeight += weight
        }

        let weightedMean = weightedSum / max(1, totalWeight)
        let slope = linearSlope(scores)
        let trend: PredictionTrend
        if slope > 1.5 { trend = .rising }
        else if slope < -1.5 { trend = .falling }
        else { trend = .stable }

        var predicted = weightedMean
        if trend == .rising {
            predicted += slope * 0.5
        } else if trend == .falling {
            predicted += slope * 0.3
        }
        predicted = max(10, min(95, predicted))

        let variance = scores.map { pow($0 - weightedMean, 2) }.reduce(0, +) / Double(n)
        let stdDev = sqrt(variance)
        let varianceConfidence = max(0, 1 - stdDev / 30)
        let countConfidence = min(1, Double(n) / 8.0)
        let confidence = varianceConfidence * 0.7 + countConfidence * 0.3

        return ScorePrediction(
            expectedScore: round(predicted),
            confidence: confidence,
            trend: trend,
            basedOnSessions: n
        )
    }

    private static func linearSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0 }
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0
        for i in 0..<values.count {
            let x = Double(i)
            let y = values[i]
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / denom
    }
}
