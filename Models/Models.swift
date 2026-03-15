import Foundation

// MARK: - Performance Dimensions

enum PerformanceDimension: String, CaseIterable, Codable {
    case confidence
    case energy
    case tempo
    case clarity
    case stability
    case charisma

    static let activeDimensions: [PerformanceDimension] = [
        .confidence, .energy, .tempo, .stability, .charisma
    ]
    
    var localizedName: String {
        switch self {
        case .confidence:      return L10n.confidence
        case .energy:          return L10n.energy
        case .tempo:           return L10n.tempo
        case .clarity:         return L10n.clarity
        case .stability:       return L10n.stability
        case .charisma:        return L10n.charisma
        }
    }
    
    var weight: Double {
        Config.dimensionWeights[self] ?? 1.0
    }

    var shortName: String {
        switch self {
        case .confidence: return "Conf"
        case .energy: return "Energy"
        case .tempo: return "Tempo"
        case .clarity: return "Klar"
        case .stability: return "Gel"
        case .charisma: return "Charis"
        }
    }

    func shortName(language: String) -> String {
        switch self {
        case .confidence: return language == "de" ? "Confidence" : "Confidence"
        case .energy: return language == "de" ? "Energy" : "Energy"
        case .tempo: return "Tempo"
        case .clarity: return language == "de" ? "Praesenz" : "Presence"
        case .stability: return language == "de" ? "Gelassenheit" : "Gelassenheit"
        case .charisma: return "Charisma"
        }
    }

    var explanation: String {
        switch self {
        case .confidence: return "Wie sicher und überzeugt deine Stimme wirkt."
        case .energy: return "Wie lebendig und präsent deine Sprechweise ist."
        case .tempo: return "Wie passend dein Sprechtempo für Verständlichkeit ist."
        case .clarity: return "Wie deutlich und praesent deine Stimme klanglich wirkt."
        case .stability: return "Wie ruhig und kontrolliert deine Stimme wirkt."
        case .charisma: return "Wie anziehend und wirkungsvoll dein Stimmprofil wirkt."
        }
    }
}

// MARK: - Voice Features (raw OpenSMILE output)

struct VoiceFeatures {
    let f0Mean: Double
    let f0Variability: Double
    let f0Range: Double
    let jitter: Double
    let shimmer: Double
    let speechRate: Double
    let energy: Double
    let hnr: Double
    let f1: Double
    let f2: Double
    let f3: Double
    let f4: Double
    let pauseDuration: Double
    let pauseDistribution: Double
    var extended: [String: Double] = [:]
    
    var asDictionary: [String: Double] {
        var base: [String: Double] = [
            FeatureKeys.f0Mean: f0Mean,
            FeatureKeys.f0Variability: f0Variability,
            FeatureKeys.f0Range: f0Range,
            FeatureKeys.jitter: jitter,
            FeatureKeys.shimmer: shimmer,
            FeatureKeys.speechRate: speechRate,
            FeatureKeys.energy: energy,
            FeatureKeys.hnr: hnr,
            FeatureKeys.f1: f1,
            FeatureKeys.f2: f2,
            FeatureKeys.f3: f3,
            FeatureKeys.f1Bandwidth: f4,
            FeatureKeys.pauseDuration: pauseDuration,
            FeatureKeys.pauseDistribution: pauseDistribution,
        ]
        for (key, value) in extended {
            base[key] = value
        }
        return base
    }
}

// MARK: - Dimension Scores (0-100)

struct DimensionScores: Codable {
    let confidence: Double
    let energy: Double
    let tempo: Double
    let clarity: Double
    let stability: Double
    let charisma: Double
    
    var overall: Double {
        confidence * 0.22
        + energy * 0.18
        + tempo * 0.15
        + stability * 0.18
        + charisma * 0.27
    }
    
    func score(for dimension: PerformanceDimension) -> Double {
        switch dimension {
        case .confidence:      return confidence
        case .energy:          return energy
        case .tempo:           return tempo
        case .clarity:         return clarity
        case .stability:       return stability
        case .charisma:        return charisma
        }
    }

    func value(for dimension: PerformanceDimension) -> Double {
        score(for: dimension)
    }
    
    func trend(for dimension: PerformanceDimension, average: Double) -> ScoreTrend {
        let diff = score(for: dimension) - average
        if diff > 5 { return .up }
        if diff < -5 { return .down }
        return .stable
    }

    func withAdjustedCharisma(_ adjustedCharisma: Double) -> DimensionScores {
        DimensionScores(
            confidence: confidence,
            energy: energy,
            tempo: tempo,
            clarity: clarity,
            stability: stability,
            charisma: min(100, max(0, adjustedCharisma))
        )
    }

    func toDictionary() -> [String: Double] {
        [
            "confidence": confidence,
            "energy": energy,
            "tempo": tempo,
            "stability": stability,
            "charisma": charisma
        ]
    }
}

enum ScoreTrend: String {
    case up = "↑"
    case down = "↓"
    case stable = "→"
}

// MARK: - Heatmap

struct HeatmapData: Codable {
    let segments: [HeatmapSegment]  // 3 segments: first, middle, last third
}

struct HeatmapSegment: Codable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let scores: DimensionScores
}

// MARK: - Pitch Types

struct PitchType: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var timeLimit: Int?         // Seconds, nil = no limit
    var challengePrompt: String? = nil
    var isCustom: Bool
    var isDefault: Bool
    
    static let defaults: [PitchType] = [
        PitchType(id: UUID(), name: "Elevator Pitch", description: "30-60 seconds, core message", timeLimit: 60, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Sales Pitch", description: "Persuasive product value pitch", timeLimit: 120, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Cold Call Opening", description: "First 30 seconds of a cold call", timeLimit: 30, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Discovery Call", description: "Needs analysis, asking questions", timeLimit: 180, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Closing", description: "Closing conversation, call-to-action", timeLimit: 120, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Keynote Intro", description: "Opening of a presentation", timeLimit: 120, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Investor Pitch", description: "Startup pitch for investors", timeLimit: 180, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Podcast Intro", description: "Hook listeners in the first 30 seconds", timeLimit: 45, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Story", description: "Narrative with emotional arc", timeLimit: 120, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Explanation", description: "Explain a concept clearly", timeLimit: 90, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Hook", description: "Short, attention-grabbing opener", timeLimit: 20, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Self Introduction", description: "Tell me what you do", timeLimit: 60, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Strengths & Weaknesses", description: "Interview answer framing strengths and growth areas", timeLimit: 90, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Why us?", description: "Interview motivation answer", timeLimit: 75, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Salary Negotiation", description: "Calm and confident salary conversation", timeLimit: 90, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Opinion", description: "State and defend your point of view", timeLimit: 75, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Small Talk", description: "Natural short social conversation", timeLimit: 45, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Anecdote", description: "Short personal story", timeLimit: 75, isCustom: false, isDefault: true),
        PitchType(id: UUID(), name: "Free Practice", description: "No template, open format", timeLimit: nil, isCustom: false, isDefault: true),
    ]
}

// MARK: - Session

struct CompletedSession: Codable {
    let id: UUID
    let date: Date
    let pitchType: String
    let duration: TimeInterval
    let scores: DimensionScores
    let featureZScores: [String: Double]
    let transcription: String
    let quickFeedback: String
    var deepCoaching: String?
    let heatmapData: HeatmapData
    var profileName: String?
    var profileRank: Int?
    var profileConfidence: Double?
    var voiceDNA: VoiceDNAProfile? = nil
}

struct SessionSummary {
    let date: String
    let pitchType: String
    let overallScore: Double
    let weakestDimension: PerformanceDimension
    let scores: DimensionScores

    var id: String { "\(date)-\(pitchType)-\(overallScore)" }
    var dateAsDate: Date? { date.asISODate }
}

struct DailyScoreSummary {
    let date: Date
    let averageOverall: Double
    let averageConfidence: Double
    let averageEnergy: Double
    let averageTempo: Double
    let averageClarity: Double
    let averageStability: Double
    let averageCharisma: Double
    let sessionCount: Int
}

// MARK: - User Profile

struct KlunaUser {
    let name: String
    let language: String        // "de" or "en"
    let firstSessionDate: Date
    var totalSessions: Int
    var weeklyGoal: Int         // 3, 5, or 7
    var currentStreak: Int      // Consecutive weeks
    var strengths: [String]
    var weaknesses: [String]
    var longTermProfile: String?
    var teamCode: String?
    var role: UserRole
    var voiceType: VoiceType
    var goal: UserGoal
    
    var daysSinceFirstSession: Int {
        Calendar.current.dateComponents([.day], from: firstSessionDate, to: Date()).day ?? 0
    }
}

enum UserRole: String, Codable {
    case consumer
    case member
    case admin
}

enum VoiceType: String, Codable, CaseIterable {
    case deep
    case mid
    case high

    var localizedName: String {
        switch self {
        case .deep: return L10n.voiceTypeDeep
        case .mid: return L10n.voiceTypeMid
        case .high: return L10n.voiceTypeHigh
        }
    }
}

enum UserGoal: String, Codable, CaseIterable {
    case pitches
    case content
    case interviews
    case confidence

    var localizedName: String {
        switch self {
        case .pitches: return L10n.goalPitches
        case .content: return L10n.goalContent
        case .interviews: return L10n.goalInterviews
        case .confidence: return L10n.goalConfidence
        }
    }
}

// MARK: - Gamification

struct Streak {
    let currentWeeks: Int
    let weeklyGoal: Int
    let sessionsThisWeek: Int
    let freezesRemaining: Int
    
    var isOnTrack: Bool {
        sessionsThisWeek >= weeklyGoal
    }
    
    var nextMilestone: Int? {
        Config.streakMilestones.first { $0 > currentWeeks }
    }
}

struct Challenge: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let type: ChallengeType
    let target: Double
    var progress: Double
    let expiresAt: Date
    
    var isCompleted: Bool { progress >= target }
    var progressPercent: Double { min(progress / target, 1.0) }
}

enum ChallengeType: String, Codable {
    case improveScore
    case pitchVariety
    case sessionCount
    case streakWeek
    case improveWeakest
    case teamAverage     // B2B only
    case teamStreak      // B2B only
}

// MARK: - Daily Challenge

struct DailyChallenge: Identifiable, Codable {
    let id: String
    let promptDe: String
    let promptEn: String
    let category: DailyChallengeCategory
    let timeLimit: Int
    let difficulty: DailyChallengeDifficulty

    func prompt(language: String) -> String {
        guard language == "de" else { return promptEn }
        return promptDe
            .replacingOccurrences(of: "ae", with: "ä")
            .replacingOccurrences(of: "oe", with: "ö")
            .replacingOccurrences(of: "ue", with: "ü")
            .replacingOccurrences(of: "Ae", with: "Ä")
            .replacingOccurrences(of: "Oe", with: "Ö")
            .replacingOccurrences(of: "Ue", with: "Ü")
    }
}

enum DailyChallengeCategory: String, Codable, CaseIterable {
    case spontan
    case storytelling
    case ueberzeugung
    case emotion
    case klarheit
}

enum DailyChallengeDifficulty: Int, Codable, CaseIterable {
    case easy = 1
    case medium = 2
    case hard = 3
}

final class DailyChallengeProvider {
    static let shared = DailyChallengeProvider()
    private init() {}

    func todaysChallenge() -> DailyChallenge {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % allChallenges.count
        return allChallenges[index]
    }

    func isTodayCompleted() -> Bool {
        UserDefaults.standard.bool(forKey: "challenge_completed_\(dateKey())")
    }

    func markTodayCompleted() {
        UserDefaults.standard.set(true, forKey: "challenge_completed_\(dateKey())")
    }

    func challengeStreak() -> Int {
        var streak = 0
        var date = Date()
        let calendar = Calendar.current
        while true {
            let key = "challenge_completed_\(dateKey(for: date))"
            if UserDefaults.standard.bool(forKey: key) {
                streak += 1
                date = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            } else {
                break
            }
        }
        return streak
    }

    private func dateKey(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    let allChallenges: [DailyChallenge] = [
        DailyChallenge(id: "sp01", promptDe: "Erklaere einem 10-jaehrigen was Inflation ist.", promptEn: "Explain inflation to a 10-year-old.", category: .klarheit, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp02", promptDe: "Was ist deine unpopulaerste Meinung? Verteidige sie.", promptEn: "What's your most unpopular opinion? Defend it.", category: .ueberzeugung, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp03", promptDe: "Beschreibe deinen perfekten Tag von morgens bis abends.", promptEn: "Describe your perfect day from morning to evening.", category: .storytelling, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp04", promptDe: "Ueberzeuge jemanden heute Abend Pizza zu bestellen.", promptEn: "Convince someone to order pizza tonight.", category: .ueberzeugung, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp05", promptDe: "Erzaehle von einem Moment der dein Leben veraendert hat.", promptEn: "Tell about a moment that changed your life.", category: .storytelling, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp06", promptDe: "Erklaere einem Ausserirdischen was Musik ist.", promptEn: "Explain music to an alien.", category: .klarheit, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp07", promptDe: "Du hast 60 Sekunden um deine Lieblingsserie zu pitchen.", promptEn: "You have 60 seconds to pitch your favorite TV show.", category: .ueberzeugung, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp08", promptDe: "Beschreibe deine groesste Angst und warum sie irrational ist.", promptEn: "Describe your biggest fear and why it's irrational.", category: .emotion, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp09", promptDe: "Halte eine Dankesrede fuer einen Preis den du nie gewonnen hast.", promptEn: "Give an acceptance speech for an award you never won.", category: .emotion, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp10", promptDe: "Erklaere warum Schlafen wichtiger ist als Sport.", promptEn: "Explain why sleep is more important than exercise.", category: .ueberzeugung, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp11", promptDe: "Erzaehle eine Geschichte die mit 'Es war 3 Uhr morgens' beginnt.", promptEn: "Tell a story that starts with 'It was 3 AM.'", category: .storytelling, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp12", promptDe: "Stelle dich vor als waerst du der Buergermeister deiner Stadt.", promptEn: "Introduce yourself as if you were the mayor of your city.", category: .spontan, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp13", promptDe: "Was wuerdest du tun wenn du morgen 1 Million Euro bekommst?", promptEn: "What would you do if you got 1 million euros tomorrow?", category: .spontan, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp14", promptDe: "Ueberzeuge deinen Chef dir freitags freizugeben.", promptEn: "Convince your boss to give you Fridays off.", category: .ueberzeugung, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp15", promptDe: "Beschreibe einen Sonnenuntergang ohne das Wort schoen zu benutzen.", promptEn: "Describe a sunset without using the word beautiful.", category: .klarheit, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp16", promptDe: "Erzaehle von deinem peinlichsten Moment mit Humor.", promptEn: "Tell about your most embarrassing moment with humor.", category: .storytelling, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp17", promptDe: "Erklaere das Internet einer Person aus dem Jahr 1900.", promptEn: "Explain the internet to a person from the year 1900.", category: .klarheit, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp18", promptDe: "Gib eine motivierende Rede fuer ein Team das gerade verloren hat.", promptEn: "Give a motivational speech to a team that just lost.", category: .emotion, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp19", promptDe: "Warum ist Scheitern besser als nie versucht zu haben?", promptEn: "Why is failing better than never having tried?", category: .ueberzeugung, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp20", promptDe: "Stelle ein Produkt vor das noch nicht existiert aber sollte.", promptEn: "Present a product that doesn't exist yet but should.", category: .spontan, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp21", promptDe: "Erzaehle von dem besten Rat den du je bekommen hast.", promptEn: "Tell about the best advice you ever received.", category: .storytelling, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp22", promptDe: "Beschreibe dein Lieblingsessen so dass jedem das Wasser im Mund zusammenlaeuft.", promptEn: "Describe your favorite food so that everyone's mouth waters.", category: .emotion, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp23", promptDe: "Halte eine 60-Sekunden-Rede ueber ein Thema das du hasst begeistert.", promptEn: "Give a 60-second speech about a topic you hate enthusiastically.", category: .emotion, timeLimit: 60, difficulty: .hard),
        DailyChallenge(id: "sp24", promptDe: "Erklaere warum Lesen wichtiger ist als Social Media.", promptEn: "Explain why reading is more important than social media.", category: .ueberzeugung, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp25", promptDe: "Du bist Reisefuehrer. Verkaufe deine Heimatstadt in 90 Sekunden.", promptEn: "You're a tour guide. Sell your hometown in 90 seconds.", category: .ueberzeugung, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp26", promptDe: "Erzaehle eine Geschichte in der du etwas Mutiges getan hast.", promptEn: "Tell a story where you did something brave.", category: .storytelling, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp27", promptDe: "Was waere die Welt ohne Musik? Male ein Bild mit Worten.", promptEn: "What would the world be without music? Paint a picture with words.", category: .emotion, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp28", promptDe: "Stelle dich vor als haettest du gerade deinen Traumjob bekommen.", promptEn: "Introduce yourself as if you just got your dream job.", category: .spontan, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp29", promptDe: "Erklaere einem Kind warum der Himmel blau ist.", promptEn: "Explain to a child why the sky is blue.", category: .klarheit, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp30", promptDe: "Halte eine Abschiedsrede fuer deinen besten Freund der auswandert.", promptEn: "Give a farewell speech for your best friend who's moving abroad.", category: .emotion, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp31", promptDe: "Pitche eine App die es noch nicht gibt.", promptEn: "Pitch an app that doesn't exist yet.", category: .ueberzeugung, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp32", promptDe: "Was hast du diese Woche gelernt?", promptEn: "What did you learn this week?", category: .spontan, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp33", promptDe: "Erzaehle von einem Buch das dich veraendert hat.", promptEn: "Tell about a book that changed you.", category: .storytelling, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp34", promptDe: "Ueberzeuge jemanden Meditation auszuprobieren.", promptEn: "Convince someone to try meditation.", category: .ueberzeugung, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp35", promptDe: "Du bist CEO. Motiviere dein Team nach einem harten Quartal.", promptEn: "You're a CEO. Motivate your team after a tough quarter.", category: .emotion, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp36", promptDe: "Beschreibe den Klang von Regen jemandem der nie Regen gehoert hat.", promptEn: "Describe the sound of rain to someone who's never heard it.", category: .klarheit, timeLimit: 60, difficulty: .hard),
        DailyChallenge(id: "sp37", promptDe: "Was macht eine gute Freundschaft aus?", promptEn: "What makes a good friendship?", category: .spontan, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp38", promptDe: "Halte eine 1-Minuten TED-Talk ueber Schlaf.", promptEn: "Give a 1-minute TED talk about sleep.", category: .ueberzeugung, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp39", promptDe: "Erzaehle eine Geschichte die mit einem Plot-Twist endet.", promptEn: "Tell a story that ends with a plot twist.", category: .storytelling, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp40", promptDe: "Erklaere Machine Learning mit einer Kochanalogie.", promptEn: "Explain machine learning using a cooking analogy.", category: .klarheit, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp41", promptDe: "Stelle dich vor als waerst du ein Charakter in deinem Lieblingsfilm.", promptEn: "Introduce yourself as a character from your favorite movie.", category: .spontan, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp42", promptDe: "Warum sollte jeder Mensch ein Instrument lernen?", promptEn: "Why should everyone learn a musical instrument?", category: .ueberzeugung, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp43", promptDe: "Beschreibe deinen Morgen so spannend wie einen Actionfilm.", promptEn: "Describe your morning as exciting as an action movie.", category: .storytelling, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp44", promptDe: "Gib Lebensratschlaege an dein 16-jaehriges Ich.", promptEn: "Give life advice to your 16-year-old self.", category: .emotion, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp45", promptDe: "Erklaere das Konzept Zeit einem Wesen das ewig lebt.", promptEn: "Explain the concept of time to a being that lives forever.", category: .klarheit, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp46", promptDe: "Pitche deine Lieblingspizza an jemanden der nie Pizza gegessen hat.", promptEn: "Pitch your favorite pizza to someone who's never had pizza.", category: .ueberzeugung, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp47", promptDe: "Was bedeutet Mut fuer dich? Gib ein Beispiel.", promptEn: "What does courage mean to you? Give an example.", category: .emotion, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp48", promptDe: "Du moderierst eine Talkshow. Stelle deinen Gast vor.", promptEn: "You host a talk show. Introduce your guest.", category: .spontan, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp49", promptDe: "Warum ist Neugier die wichtigste Eigenschaft?", promptEn: "Why is curiosity the most important trait?", category: .ueberzeugung, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp50", promptDe: "Erzaehle die Geschichte deines Lebens in 90 Sekunden.", promptEn: "Tell the story of your life in 90 seconds.", category: .storytelling, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp51", promptDe: "Erklaere einem Fisch was Fliegen ist.", promptEn: "Explain flying to a fish.", category: .klarheit, timeLimit: 60, difficulty: .medium),
        DailyChallenge(id: "sp52", promptDe: "Halte eine Trauzeugenrede fuer einen imaginaeren besten Freund.", promptEn: "Give a best man speech for an imaginary best friend.", category: .emotion, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp53", promptDe: "Was ist deine Superkraft im Alltag?", promptEn: "What's your everyday superpower?", category: .spontan, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp54", promptDe: "Ueberzeuge jemanden seine Komfortzone zu verlassen.", promptEn: "Convince someone to leave their comfort zone.", category: .ueberzeugung, timeLimit: 90, difficulty: .medium),
        DailyChallenge(id: "sp55", promptDe: "Beschreibe Stille. Was hoert man wenn man nichts hoert?", promptEn: "Describe silence. What do you hear when you hear nothing?", category: .klarheit, timeLimit: 60, difficulty: .hard),
        DailyChallenge(id: "sp56", promptDe: "Du stellst dich bei einem Networking-Event vor. 30 Sekunden.", promptEn: "You're introducing yourself at a networking event. 30 seconds.", category: .spontan, timeLimit: 30, difficulty: .easy),
        DailyChallenge(id: "sp57", promptDe: "Erzaehle von einer Person die dich inspiriert und warum.", promptEn: "Tell about a person who inspires you and why.", category: .emotion, timeLimit: 60, difficulty: .easy),
        DailyChallenge(id: "sp58", promptDe: "Pitche eine verrueckte Geschaeftsidee total ernst.", promptEn: "Pitch a crazy business idea completely seriously.", category: .ueberzeugung, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp59", promptDe: "Was wuerdest du der Welt sagen wenn alle 5 Minuten zuhoeren?", promptEn: "What would you tell the world if everyone listened for 5 minutes?", category: .emotion, timeLimit: 90, difficulty: .hard),
        DailyChallenge(id: "sp60", promptDe: "Fasse deinen Tag in einer Geschichte mit Happy End zusammen.", promptEn: "Summarize your day as a story with a happy ending.", category: .storytelling, timeLimit: 60, difficulty: .easy),
    ]
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let username: String
    let score: Double
    let rank: Int
    let isCurrentUser: Bool
}

enum LeaderboardTab {
    case topScore
    case topImprovement
}

// MARK: - Team (B2B)

struct Team {
    let code: String
    let name: String
    let memberCount: Int
    let averageScore: Double
    let averageImprovement: Double
    let activeThisWeek: Int
}
