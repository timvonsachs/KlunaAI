import Foundation

struct BiomarkerChallenge: Identifiable, Codable {
    let id: String
    let titleDE: String
    let titleEN: String
    let instructionDE: String
    let instructionEN: String
    let timeLimit: Int
    let criteria: BiomarkerCriteria
    let relatedDimension: PerformanceDimension
    let xpReward: Int

    func title(language: String) -> String { language == "de" ? titleDE : titleEN }
    func instruction(language: String) -> String { language == "de" ? instructionDE : instructionEN }
}

struct BiomarkerCriteria: Codable {
    let type: BiomarkerCriteriaType
    let featureKey: String?
    let threshold: Double?
    let comparison: Comparison?
}

enum BiomarkerCriteriaType: String, Codable {
    case pauseCountMin
    case loudnessEndVsStart
    case f0RangeMin
    case speechRateRange
    case jitterBelow
    case hnrAbove
    case segmentConsistency
    case loudnessDynamicRange
    case tempoVariation
}

enum Comparison: String, Codable {
    case greaterThan
    case lessThan
    case between
}

struct BiomarkerResult {
    let passed: Bool
    let achievedValue: Double
    let targetDescription: String
    let challenge: BiomarkerChallenge
}

final class BiomarkerChallengeProvider {
    static let shared = BiomarkerChallengeProvider()
    private init() {}

    func challengeForWeakness(_ dimension: PerformanceDimension) -> BiomarkerChallenge {
        let matching = allChallenges.filter { $0.relatedDimension == dimension }
        return matching.randomElement() ?? allChallenges[0]
    }

    func evaluate(
        challenge: BiomarkerChallenge,
        rawFeatures: [String: Double],
        heatmapSegments: [DimensionScores]?
    ) -> BiomarkerResult {
        let criteria = challenge.criteria
        var passed = false
        var achievedValue: Double = 0
        var targetDescription = ""

        switch criteria.type {
        case .pauseCountMin:
            let pauseCount = rawFeatures["pauseCount"] ?? 0
            let threshold = criteria.threshold ?? 3
            achievedValue = pauseCount
            passed = pauseCount >= threshold
            targetDescription = ">= \(Int(threshold)) pauses"

        case .loudnessEndVsStart:
            guard let segments = heatmapSegments, segments.count >= 2 else { break }
            let startEnergy = segments.first?.energy ?? 0
            let endEnergy = segments.last?.energy ?? 0
            achievedValue = endEnergy - startEnergy
            passed = endEnergy > startEnergy
            targetDescription = "End > Start"

        case .f0RangeMin:
            let f0Range = rawFeatures["f0RangeST"] ?? 0
            let threshold = criteria.threshold ?? 12
            achievedValue = f0Range
            passed = f0Range >= threshold
            targetDescription = ">= \(Int(threshold)) st"

        case .speechRateRange:
            let rate = rawFeatures["speechRate"] ?? 0
            achievedValue = rate
            passed = rate >= 3.5 && rate <= 4.5
            targetDescription = "3.5-4.5 syll/s"

        case .jitterBelow:
            let jitter = rawFeatures["jitter"] ?? 0.05
            let threshold = criteria.threshold ?? 0.02
            achievedValue = jitter
            passed = jitter <= threshold
            targetDescription = "< \(String(format: "%.3f", threshold))"

        case .hnrAbove:
            let hnr = rawFeatures["hnr"] ?? 0
            let threshold = criteria.threshold ?? 15
            achievedValue = hnr
            passed = hnr >= threshold
            targetDescription = "> \(Int(threshold)) dB"

        case .segmentConsistency:
            guard let segments = heatmapSegments, segments.count >= 3 else { break }
            let overalls = segments.map(\.overall)
            let range = (overalls.max() ?? 0) - (overalls.min() ?? 0)
            achievedValue = range
            let threshold = criteria.threshold ?? 10
            passed = range <= threshold
            targetDescription = "Variance < \(Int(threshold))"

        case .loudnessDynamicRange:
            let dynamicRange = rawFeatures["loudnessDynamicRange"] ?? 0
            let threshold = criteria.threshold ?? 15
            achievedValue = dynamicRange
            passed = dynamicRange >= threshold
            targetDescription = ">= \(Int(threshold)) dB"

        case .tempoVariation:
            let tempoVariance = rawFeatures["speechRateVariance"] ?? 0
            let threshold = criteria.threshold ?? 0.5
            achievedValue = tempoVariance
            passed = tempoVariance >= threshold
            targetDescription = "Tempo shift present"
        }

        return BiomarkerResult(
            passed: passed,
            achievedValue: achievedValue,
            targetDescription: targetDescription,
            challenge: challenge
        )
    }

    let allChallenges: [BiomarkerChallenge] = [
        BiomarkerChallenge(
            id: "bio01",
            titleDE: "3 bewusste Pausen",
            titleEN: "3 Intentional Pauses",
            instructionDE: "Sprich 60 Sekunden und setze mindestens 3 Pausen über 1.5 Sekunden.",
            instructionEN: "Speak for 60 seconds with at least 3 pauses over 1.5 seconds.",
            timeLimit: 60,
            criteria: BiomarkerCriteria(type: .pauseCountMin, featureKey: "pauseCount", threshold: 3, comparison: .greaterThan),
            relatedDimension: .tempo,
            xpReward: 75
        ),
        BiomarkerChallenge(
            id: "bio02",
            titleDE: "Starkes Finale",
            titleEN: "Strong Finish",
            instructionDE: "Werde im letzten Drittel lauter als am Anfang.",
            instructionEN: "Be louder in the final third than at the start.",
            timeLimit: 60,
            criteria: BiomarkerCriteria(type: .loudnessEndVsStart, featureKey: nil, threshold: nil, comparison: .greaterThan),
            relatedDimension: .energy,
            xpReward: 100
        ),
        BiomarkerChallenge(
            id: "bio03",
            titleDE: "Volle Bandbreite",
            titleEN: "Full Range",
            instructionDE: "Nutze mindestens 12 Halbtöne Tonhöhenvariation.",
            instructionEN: "Use at least 12 semitones of pitch variation.",
            timeLimit: 60,
            criteria: BiomarkerCriteria(type: .f0RangeMin, featureKey: "f0RangeST", threshold: 12, comparison: .greaterThan),
            relatedDimension: .charisma,
            xpReward: 100
        ),
        BiomarkerChallenge(
            id: "bio04",
            titleDE: "Tempo Sweet Spot",
            titleEN: "Tempo Sweet Spot",
            instructionDE: "Halte dein Tempo zwischen 3.5 und 4.5 Silben pro Sekunde.",
            instructionEN: "Keep your pace between 3.5 and 4.5 syllables per second.",
            timeLimit: 60,
            criteria: BiomarkerCriteria(type: .speechRateRange, featureKey: "speechRate", threshold: nil, comparison: .between),
            relatedDimension: .tempo,
            xpReward: 75
        ),
        BiomarkerChallenge(
            id: "bio05",
            titleDE: "Ruhige Stimme",
            titleEN: "Steady Voice",
            instructionDE: "Halte Jitter unter 0.02 für maximale Kontrolle.",
            instructionEN: "Keep jitter below 0.02 for maximum control.",
            timeLimit: 45,
            criteria: BiomarkerCriteria(type: .jitterBelow, featureKey: "jitter", threshold: 0.02, comparison: .lessThan),
            relatedDimension: .confidence,
            xpReward: 100
        ),
    ]
}
