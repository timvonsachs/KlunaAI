import Foundation

struct ProgressiveChallenge: Identifiable, Codable {
    let id: String
    let level: Int
    let titleDe: String
    let titleEn: String
    let descriptionDe: String
    let descriptionEn: String
    let instructionDe: String
    let instructionEn: String
    let timeLimit: Int
    let successCriteria: ChallengeCriteria
    let xpReward: Int

    func title(language: String) -> String { language == "de" ? titleDe : titleEn }
    func description(language: String) -> String { language == "de" ? descriptionDe : descriptionEn }
    func instruction(language: String) -> String { language == "de" ? instructionDe : instructionEn }
}

struct ChallengeCriteria: Codable {
    let dimension: String?
    let minScore: Double
    let specialRule: SpecialRule?
}

enum SpecialRule: String, Codable {
    case noConfidenceDrop
    case pauseCount3
    case energyEndHigherThanStart
    case stableAllSegments
    case allDimensionsAbove50
    case charismaAbove70
}

struct ChallengeResult {
    let passed: Bool
    let challenge: ProgressiveChallenge
    let achievedScore: Double
    let requiredScore: Double
    let specialRulePassed: Bool
}

final class ProgressiveChallengeProvider {
    static let shared = ProgressiveChallengeProvider()
    private init() {}

    func currentLevel() -> Int {
        let raw = UserDefaults.standard.integer(forKey: "progressiveLevel")
        return max(1, min(levels.count, raw == 0 ? 1 : raw))
    }

    func currentChallenge() -> ProgressiveChallenge {
        levels[currentLevel() - 1]
    }

    func completeCurrentLevel() {
        let current = currentLevel()
        if current < levels.count {
            UserDefaults.standard.set(current + 1, forKey: "progressiveLevel")
        }
    }

    func evaluateSession(scores: DimensionScores, heatmapSegments: [DimensionScores]?) -> ChallengeResult {
        let challenge = currentChallenge()
        let criteria = challenge.successCriteria

        let relevantScore: Double
        if let dim = criteria.dimension, let perfDim = PerformanceDimension(rawValue: dim) {
            relevantScore = scores.value(for: perfDim)
        } else {
            relevantScore = scores.overall
        }

        let basePass = relevantScore >= criteria.minScore
        let specialPass = criteria.specialRule.map { evaluateSpecialRule($0, scores: scores, heatmap: heatmapSegments) } ?? true
        return ChallengeResult(
            passed: basePass && specialPass,
            challenge: challenge,
            achievedScore: relevantScore,
            requiredScore: criteria.minScore,
            specialRulePassed: specialPass
        )
    }

    private func evaluateSpecialRule(_ rule: SpecialRule, scores: DimensionScores, heatmap: [DimensionScores]?) -> Bool {
        switch rule {
        case .noConfidenceDrop:
            return scores.confidence >= 45
        case .pauseCount3:
            return true
        case .energyEndHigherThanStart:
            guard let segments = heatmap, let first = segments.first, let last = segments.last else { return false }
            return last.energy > first.energy
        case .stableAllSegments:
            guard let segments = heatmap, segments.count >= 3 else { return false }
            let all = segments.map(\.overall)
            guard let minScore = all.min(), let maxScore = all.max() else { return false }
            return maxScore - minScore <= 10
        case .allDimensionsAbove50:
            return scores.confidence >= 50 &&
                scores.energy >= 50 &&
                scores.tempo >= 50 &&
                scores.stability >= 50 &&
                scores.charisma >= 50
        case .charismaAbove70:
            return scores.charisma >= 70
        }
    }

    let levels: [ProgressiveChallenge] = [
        ProgressiveChallenge(
            id: "L01", level: 1,
            titleDe: "Erste Schritte", titleEn: "First Steps",
            descriptionDe: "Sprich 30 Sekunden ueber ein beliebiges Thema.",
            descriptionEn: "Speak for 30 seconds about any topic.",
            instructionDe: "Erzaehle einfach drauf los. Kein perfekter Pitch noetig - nur deine Stimme.",
            instructionEn: "Just start talking. No perfect pitch needed - just your voice.",
            timeLimit: 30,
            successCriteria: ChallengeCriteria(dimension: nil, minScore: 30, specialRule: nil),
            xpReward: 50
        ),
        ProgressiveChallenge(
            id: "L02", level: 2,
            titleDe: "Lauter!", titleEn: "Louder!",
            descriptionDe: "Sprich mit Energie. Dein Energie-Score muss ueber 45 liegen.",
            descriptionEn: "Speak with energy. Your energy score must be above 45.",
            instructionDe: "Stell dir vor du stehst auf einer Buehne. Projiziere deine Stimme!",
            instructionEn: "Imagine you're on a stage. Project your voice!",
            timeLimit: 45,
            successCriteria: ChallengeCriteria(dimension: "energy", minScore: 45, specialRule: nil),
            xpReward: 75
        ),
        ProgressiveChallenge(
            id: "L03", level: 3,
            titleDe: "Ruhig und klar", titleEn: "Calm and Clear",
            descriptionDe: "Sprich ruhig und gleichmaessig. Gelassenheit ueber 50.",
            descriptionEn: "Speak calmly and steadily. Calmness above 50.",
            instructionDe: "Wie ein Nachrichtensprecher: gleichmaessig, kontrolliert, professionell.",
            instructionEn: "Like a news anchor: steady, controlled, professional.",
            timeLimit: 45,
            successCriteria: ChallengeCriteria(dimension: "stability", minScore: 50, specialRule: nil),
            xpReward: 75
        ),
        ProgressiveChallenge(
            id: "L04", level: 4,
            titleDe: "Der Sweet Spot", titleEn: "The Sweet Spot",
            descriptionDe: "Finde dein optimales Tempo. Tempo-Score ueber 55.",
            descriptionEn: "Find your optimal pace. Tempo score above 55.",
            instructionDe: "Nicht zu schnell, nicht zu langsam. Bewusste Pausen setzen.",
            instructionEn: "Not too fast, not too slow. Set intentional pauses.",
            timeLimit: 60,
            successCriteria: ChallengeCriteria(dimension: "tempo", minScore: 55, specialRule: nil),
            xpReward: 100
        ),
        ProgressiveChallenge(
            id: "L05", level: 5,
            titleDe: "Balanciert", titleEn: "Balanced",
            descriptionDe: "Keine Dimension unter 50. Balance ist der Schluessel.",
            descriptionEn: "No dimension below 50. Balance is key.",
            instructionDe: "Achte auf alles gleichzeitig: Energy, Tempo, Gelassenheit, Charisma.",
            instructionEn: "Pay attention to everything: Energy, Tempo, Calmness, Charisma.",
            timeLimit: 60,
            successCriteria: ChallengeCriteria(dimension: nil, minScore: 50, specialRule: .allDimensionsAbove50),
            xpReward: 150
        ),
        ProgressiveChallenge(
            id: "L06", level: 6,
            titleDe: "Das starke Ende", titleEn: "The Strong Finish",
            descriptionDe: "Deine Energie muss am Ende hoeher sein als am Anfang.",
            descriptionEn: "Your energy must be higher at the end than at the start.",
            instructionDe: "Viele verlieren Energie am Schluss. Tu das Gegenteil. Steigere dich!",
            instructionEn: "Many lose energy at the end. Do the opposite. Build up!",
            timeLimit: 60,
            successCriteria: ChallengeCriteria(dimension: "energy", minScore: 50, specialRule: .energyEndHigherThanStart),
            xpReward: 150
        ),
        ProgressiveChallenge(
            id: "L07", level: 7,
            titleDe: "Gleichmaessig durchhalten", titleEn: "Stay Consistent",
            descriptionDe: "Alle 3 Segmente innerhalb von 10 Punkten.",
            descriptionEn: "All 3 segments within 10 points.",
            instructionDe: "Keine Einbrueche, keine Spitzen. Konstante Qualitaet.",
            instructionEn: "No dips, no spikes. Consistent quality.",
            timeLimit: 90,
            successCriteria: ChallengeCriteria(dimension: nil, minScore: 50, specialRule: .stableAllSegments),
            xpReward: 200
        ),
        ProgressiveChallenge(
            id: "L08", level: 8,
            titleDe: "Unter Druck", titleEn: "Under Pressure",
            descriptionDe: "Sprich ueber etwas Nervoeses - Confidence darf nicht unter 45 fallen.",
            descriptionEn: "Talk about something nerve-wracking - confidence cannot drop below 45.",
            instructionDe: "Sprich ueber eine nervoese Situation. Halte deine Stimme ruhig und klar.",
            instructionEn: "Talk about a nerve-wracking situation. Keep your voice calm and clear.",
            timeLimit: 60,
            successCriteria: ChallengeCriteria(dimension: "confidence", minScore: 55, specialRule: .noConfidenceDrop),
            xpReward: 200
        ),
        ProgressiveChallenge(
            id: "L09", level: 9,
            titleDe: "Overall 60", titleEn: "Overall 60",
            descriptionDe: "Erreiche einen Overall Score von mindestens 60.",
            descriptionEn: "Achieve an overall score of at least 60.",
            instructionDe: "Alles zusammen: Energy, Tempo, Gelassenheit, Confidence, Charisma.",
            instructionEn: "Everything together: Energy, Tempo, Calmness, Confidence, Charisma.",
            timeLimit: 90,
            successCriteria: ChallengeCriteria(dimension: nil, minScore: 60, specialRule: nil),
            xpReward: 250
        ),
        ProgressiveChallenge(
            id: "L10", level: 10,
            titleDe: "Der Charismatiker", titleEn: "The Charismatic",
            descriptionDe: "Charisma ueber 70. Dynamik, Pausen, Energie - alles muss stimmen.",
            descriptionEn: "Charisma above 70. Dynamics, pauses, energy - everything must align.",
            instructionDe: "Erzaehle eine Geschichte die fesselt. Nutze die volle Bandbreite.",
            instructionEn: "Tell a captivating story. Use your full vocal range.",
            timeLimit: 90,
            successCriteria: ChallengeCriteria(dimension: "charisma", minScore: 70, specialRule: .charismaAbove70),
            xpReward: 300
        ),
        ProgressiveChallenge(
            id: "L11", level: 11,
            titleDe: "Overall 70", titleEn: "Overall 70",
            descriptionDe: "Overall 70 - du bist jetzt in den Top 20%.",
            descriptionEn: "Overall 70 - you are now in the top 20%.",
            instructionDe: "Das ist Profi-Niveau. Pitch als waerst du vor Investoren.",
            instructionEn: "This is professional level. Pitch as if in front of investors.",
            timeLimit: 90,
            successCriteria: ChallengeCriteria(dimension: nil, minScore: 70, specialRule: nil),
            xpReward: 400
        ),
        ProgressiveChallenge(
            id: "L12", level: 12,
            titleDe: "Die Achterbahn", titleEn: "The Rollercoaster",
            descriptionDe: "Alle Dimensionen ueber 50 plus Charisma ueber 65.",
            descriptionEn: "All dimensions above 50 plus charisma above 65.",
            instructionDe: "Variiere bewusst, aber bleib in Kontrolle.",
            instructionEn: "Vary deliberately, but stay in control.",
            timeLimit: 90,
            successCriteria: ChallengeCriteria(dimension: "charisma", minScore: 65, specialRule: .allDimensionsAbove50),
            xpReward: 500
        ),
        ProgressiveChallenge(
            id: "L13", level: 13,
            titleDe: "Meister der Gelassenheit", titleEn: "Master of Calmness",
            descriptionDe: "Overall 65 plus stabile Segmente plus Gelassenheit ueber 70.",
            descriptionEn: "Overall 65 plus stable segments plus calmness above 70.",
            instructionDe: "Kein Einbruch. 90 Sekunden perfekte Kontrolle.",
            instructionEn: "No breakdown. 90 seconds of perfect control.",
            timeLimit: 90,
            successCriteria: ChallengeCriteria(dimension: "stability", minScore: 70, specialRule: .stableAllSegments),
            xpReward: 500
        ),
        ProgressiveChallenge(
            id: "L14", level: 14,
            titleDe: "Overall 80", titleEn: "Overall 80",
            descriptionDe: "Overall 80. Weniger als 1% schaffen das auf Anhieb.",
            descriptionEn: "Overall 80. Fewer than 1% achieve this on the first attempt.",
            instructionDe: "Du bist auf Profi-Niveau. Zeig was du kannst.",
            instructionEn: "You are at professional level. Show what you can do.",
            timeLimit: 120,
            successCriteria: ChallengeCriteria(dimension: nil, minScore: 80, specialRule: nil),
            xpReward: 750
        ),
        ProgressiveChallenge(
            id: "L15", level: 15,
            titleDe: "Der beste Sprecher deiner selbst", titleEn: "The Best Speaker of Yourself",
            descriptionDe: "Overall 85 plus keine Dimension unter 60 plus Charisma ueber 75.",
            descriptionEn: "Overall 85 plus no dimension below 60 plus charisma above 75.",
            instructionDe: "Alles was du gelernt hast in einer Rede. Sprich als die Person, die du sein willst.",
            instructionEn: "Everything you've learned in one speech. Speak as the person you want to be.",
            timeLimit: 120,
            successCriteria: ChallengeCriteria(dimension: nil, minScore: 85, specialRule: .allDimensionsAbove50),
            xpReward: 1000
        ),
    ]
}
