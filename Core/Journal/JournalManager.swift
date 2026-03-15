import Foundation
import CoreData

struct JournalEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let transcript: String
    let audioRelativePath: String?
    let prompt: String?
    let mood: String?
    let arousal: Float
    let acousticValence: Float
    let quadrant: EmotionQuadrant
    let moodLabel: String?
    let coachText: String?
    let themes: [String]
    let pillarVQ: Float
    let pillarClarity: Float
    let pillarDynamics: Float
    let pillarRhythm: Float
    let overallScore: Float
    let deltaArousal: Float
    let deltaValence: Float
    let rawFeatures: [String: Double]
    let f0Mean: Float
    let f0Range: Float
    let jitter: Float
    let shimmer: Float
    let hnr: Float
    let speechRate: Float
    let pauseRate: Float
    let loudnessMean: Float
    let loudnessRange: Float
    let flags: [AcousticFlag]
    let warmth: Float
    let stability: Float
    let energy: Float
    let tempo: Float
    let openness: Float
    var conversationId: UUID? = nil
    var roundIndex: Int16 = 0
    var deltaEnergy: Float = 0
    var deltaTension: Float = 0
    var deltaFatigue: Float = 0
    var deltaWarmth: Float = 0
    var deltaExpressiveness: Float = 0
    var deltaTempo: Float = 0
    var cardTitle: String? = nil
    var cardRarity: String? = nil
    var cardAtmosphereHex: String? = nil
    var voiceObservation: String? = nil

    var energyLevel: Double {
        rawFeatures[FeatureKeys.loudnessRMSOriginal] ?? rawFeatures[FeatureKeys.loudness] ?? 0
    }

    var voiceStability: Double {
        let jitter = rawFeatures[FeatureKeys.jitter] ?? 0.03
        return max(0, 1.0 - jitter * 20)
    }

    var vocalWarmth: Double {
        rawFeatures[FeatureKeys.hnr] ?? 12
    }
}

enum AcousticFlag: String, Codable {
    case isMonotone
    case isHighPitchVariation
    case isJitterElevated
    case isTempoFast
    case isTempoSlow
    case isPauseLong
    case isPauseAbsent
    case isLoudnessLow
    case isLoudnessHigh
    case isWarmthHigh
    case isWarmthLow

    var promptLabel: String {
        switch self {
        case .isMonotone: return "Stimme ist monotoner als sonst"
        case .isHighPitchVariation: return "Stimme ist melodischer als sonst"
        case .isJitterElevated: return "Stimme zittert mehr als sonst"
        case .isTempoFast: return "Spricht schneller als sonst"
        case .isTempoSlow: return "Spricht langsamer als sonst"
        case .isPauseLong: return "Macht längere Pausen als sonst"
        case .isPauseAbsent: return "Redet durch ohne Pausen"
        case .isLoudnessLow: return "Stimme ist leiser als sonst"
        case .isLoudnessHigh: return "Stimme ist lauter als sonst"
        case .isWarmthHigh: return "Stimme klingt wärmer als sonst"
        case .isWarmthLow: return "Stimme klingt kühler als sonst"
        }
    }
}

struct EngineVoiceDimensions: Codable {
    let energy: Float
    let tension: Float
    let fatigue: Float
    let warmth: Float
    let expressiveness: Float
    let tempo: Float
}

enum MoodCategory: String, CaseIterable {
    case begeistert
    case aufgekratzt
    case aufgewuehlt
    case angespannt
    case frustriert
    case ruhig
    case zufrieden
    case erschoepft
    case nachdenklich
    case verletzlich

    static func resolve(_ raw: String?) -> MoodCategory? {
        guard let raw else { return nil }
        let mood = raw
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ß", with: "ss")

        if let exact = MoodCategory(rawValue: mood) { return exact }

        switch mood {
        case let m where m.contains("begeister"): return .begeistert
        case let m where m.contains("excited"): return .begeistert
        case let m where m.contains("aufgekratzt"): return .aufgekratzt
        case let m where m.contains("energized"): return .aufgekratzt
        case let m where m.contains("aufgewuehlt"): return .aufgewuehlt
        case let m where m.contains("stirred_up"), let m where m.contains("stirred up"): return .aufgewuehlt
        case let m where m.contains("angespannt"): return .angespannt
        case let m where m.contains("tense"): return .angespannt
        case let m where m.contains("frustriert"): return .frustriert
        case let m where m.contains("frustrated"): return .frustriert
        case let m where m.contains("erschoepft"): return .erschoepft
        case let m where m.contains("exhausted"): return .erschoepft
        case let m where m.contains("verletzlich"): return .verletzlich
        case let m where m.contains("vulnerable"): return .verletzlich
        case let m where m.contains("ruhig"): return .ruhig
        case let m where m.contains("calm"): return .ruhig
        case let m where m.contains("zufrieden"): return .zufrieden
        case let m where m.contains("content"): return .zufrieden
        case let m where m.contains("nachdenklich"): return .nachdenklich
        case let m where m.contains("reflective"): return .nachdenklich
        default: return nil
        }
    }

    var quadrant: EmotionQuadrant {
        switch self {
        case .begeistert, .aufgekratzt:
            return .begeistert
        case .aufgewuehlt, .angespannt:
            return .aufgewuehlt
        case .ruhig, .zufrieden, .nachdenklich:
            return .zufrieden
        case .frustriert, .erschoepft, .verletzlich:
            return .erschoepft
        }
    }
}

enum EmotionQuadrant: String, Codable, CaseIterable {
    case begeistert
    case aufgewuehlt
    case zufrieden
    case erschoepft

    var dot: String {
        switch self {
        case .begeistert: return "🟡"
        case .aufgewuehlt: return "🔴"
        case .zufrieden: return "🟢"
        case .erschoepft: return "🔵"
        }
    }

    var subtitleDE: String {
        switch self {
        case .begeistert: return "aufgewühlt aber positiv"
        case .aufgewuehlt: return "angespannt"
        case .zufrieden: return "ruhig und zufrieden"
        case .erschoepft: return "ruhig und erschöpft"
        }
    }
}

struct EmotionProfile: Codable {
    let arousal: Float
    let acousticValence: Float

    var quadrant: EmotionQuadrant {
        let highArousal = arousal > 50
        let positiveValence = acousticValence > 50
        switch (highArousal, positiveValence) {
        case (true, true): return .begeistert
        case (true, false): return .aufgewuehlt
        case (false, true): return .zufrieden
        case (false, false): return .erschoepft
        }
    }
}

struct BaselineDeltas: Codable {
    var arousalDelta: Float = 0
    var arousalZScore: Float = 0
    var valenceDelta: Float = 0
    var valenceZScore: Float = 0

    var f0Delta: Float = 0
    var f0ZScore: Float = 0

    var jitterDelta: Float = 0
    var jitterZScore: Float = 0

    var hnrDelta: Float = 0
    var hnrZScore: Float = 0

    var speechRateDelta: Float = 0
    var speechRateZScore: Float = 0

    var loudnessDelta: Float = 0
    var loudnessZScore: Float = 0

    var pauseRateDelta: Float = 0
    var pauseRateZScore: Float = 0
}

struct WeeklyVoiceSnapshot: Identifiable {
    let id = UUID()
    let weekStart: Date
    let avgEnergy: Double
    let avgStability: Double
    let avgWarmth: Double
    let avgF0: Double
    let entryCount: Int
    let dominantQuadrant: EmotionQuadrant?
}

final class JournalManager {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func saveEntry(_ entry: JournalEntry) {
        context.performAndWait {
            let entity = CDJournalEntry(context: context)
            entity.id = entry.id
            entity.date = entry.date
            entity.duration = entry.duration
            entity.rawFeaturesJSON = try? JSONEncoder().encode(entry.rawFeatures)
            entity.transcription = entry.transcript
            entity.audioRelativePath = entry.audioRelativePath
            entity.recordingURL = entry.audioRelativePath
            entity.prompt = entry.prompt
            entity.mood = entry.mood
            entity.arousal = entry.arousal
            entity.acousticValence = entry.acousticValence
            entity.quadrant = entry.quadrant.rawValue
            entity.moodLabel = entry.moodLabel
            entity.coachText = entry.coachText
            entity.themesRaw = entry.themes.joined(separator: ",")
            entity.pillarVQ = entry.pillarVQ
            entity.pillarClarity = entry.pillarClarity
            entity.pillarDynamics = entry.pillarDynamics
            entity.pillarRhythm = entry.pillarRhythm
            entity.overallScore = entry.overallScore
            entity.deltaArousal = entry.deltaArousal
            entity.deltaValence = entry.deltaValence
            entity.f0Mean = entry.f0Mean
            entity.f0Range = entry.f0Range
            entity.jitter = entry.jitter
            entity.shimmer = entry.shimmer
            entity.hnr = entry.hnr
            entity.speechRate = entry.speechRate
            entity.pauseRate = entry.pauseRate
            entity.loudnessMean = entry.loudnessMean
            entity.loudnessRange = entry.loudnessRange
            entity.flagsRaw = entry.flags.map(\.rawValue).joined(separator: ",")
            entity.warmth = entry.warmth
            entity.stability = entry.stability
            entity.energy = entry.energy
            entity.tempo = entry.tempo
            entity.openness = entry.openness
            entity.conversationId = entry.conversationId
            entity.roundIndex = entry.roundIndex
            entity.deltaEnergy = entry.deltaEnergy
            entity.deltaTension = entry.deltaTension
            entity.deltaFatigue = entry.deltaFatigue
            entity.deltaWarmth = entry.deltaWarmth
            entity.deltaExpressiveness = entry.deltaExpressiveness
            entity.deltaTempo = entry.deltaTempo
            entity.cardTitle = entry.cardTitle
            entity.cardRarity = entry.cardRarity
            entity.cardAtmosphereHex = entry.cardAtmosphereHex
            entity.voiceObservation = entry.voiceObservation
            try? context.save()
        }
    }

    func entries(lastDays: Int) -> [JournalEntry] {
        context.performAndWait {
            let request: NSFetchRequest<CDJournalEntry> = CDJournalEntry.fetchRequest()
            let startDate = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date()) ?? Date()
            request.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

            guard let results = try? context.fetch(request) else { return [] }
            return results.compactMap { entity -> JournalEntry? in
                guard let id = entity.id, let date = entity.date else { return nil }
                let features: [String: Double] = {
                    guard let data = entity.rawFeaturesJSON else { return [:] }
                    return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
                }()
                return JournalEntry(
                    id: id,
                    date: date,
                    duration: entity.duration,
                    transcript: entity.transcription ?? "",
                    audioRelativePath: entity.audioRelativePath ?? entity.recordingURL,
                    prompt: entity.prompt,
                    mood: entity.mood,
                    arousal: entity.arousal,
                    acousticValence: entity.acousticValence,
                    quadrant: EmotionQuadrant(rawValue: entity.quadrant ?? "") ?? .zufrieden,
                    moodLabel: entity.moodLabel,
                    coachText: entity.coachText,
                    themes: (entity.themesRaw ?? "")
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty },
                    pillarVQ: entity.pillarVQ,
                    pillarClarity: entity.pillarClarity,
                    pillarDynamics: entity.pillarDynamics,
                    pillarRhythm: entity.pillarRhythm,
                    overallScore: entity.overallScore,
                    deltaArousal: entity.deltaArousal,
                    deltaValence: entity.deltaValence,
                    rawFeatures: features,
                    f0Mean: entity.f0Mean,
                    f0Range: entity.f0Range,
                    jitter: entity.jitter,
                    shimmer: entity.shimmer,
                    hnr: entity.hnr,
                    speechRate: entity.speechRate,
                    pauseRate: entity.pauseRate,
                    loudnessMean: entity.loudnessMean,
                    loudnessRange: entity.loudnessRange,
                    flags: (entity.flagsRaw ?? "")
                        .split(separator: ",")
                        .compactMap { AcousticFlag(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) },
                    warmth: entity.warmth,
                    stability: entity.stability,
                    energy: entity.energy,
                    tempo: entity.tempo,
                    openness: entity.openness,
                    conversationId: entity.conversationId,
                    roundIndex: entity.roundIndex,
                    deltaEnergy: entity.deltaEnergy,
                    deltaTension: entity.deltaTension,
                    deltaFatigue: entity.deltaFatigue,
                    deltaWarmth: entity.deltaWarmth,
                    deltaExpressiveness: entity.deltaExpressiveness,
                    deltaTempo: entity.deltaTempo,
                    cardTitle: entity.cardTitle,
                    cardRarity: entity.cardRarity,
                    cardAtmosphereHex: entity.cardAtmosphereHex,
                    voiceObservation: entity.voiceObservation
                )
            }
        }
    }

    func recentEntries(limit: Int = 20) -> [JournalEntry] {
        context.performAndWait {
            let request: NSFetchRequest<CDJournalEntry> = CDJournalEntry.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            request.fetchLimit = limit
            guard let results = try? context.fetch(request) else { return [] }
            return results.compactMap { entity -> JournalEntry? in
                guard let id = entity.id, let date = entity.date else { return nil }
                let features: [String: Double] = {
                    guard let data = entity.rawFeaturesJSON else { return [:] }
                    return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
                }()
                return JournalEntry(
                    id: id,
                    date: date,
                    duration: entity.duration,
                    transcript: entity.transcription ?? "",
                    audioRelativePath: entity.audioRelativePath ?? entity.recordingURL,
                    prompt: entity.prompt,
                    mood: entity.mood,
                    arousal: entity.arousal,
                    acousticValence: entity.acousticValence,
                    quadrant: EmotionQuadrant(rawValue: entity.quadrant ?? "") ?? .zufrieden,
                    moodLabel: entity.moodLabel,
                    coachText: entity.coachText,
                    themes: (entity.themesRaw ?? "")
                        .split(separator: ",")
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty },
                    pillarVQ: entity.pillarVQ,
                    pillarClarity: entity.pillarClarity,
                    pillarDynamics: entity.pillarDynamics,
                    pillarRhythm: entity.pillarRhythm,
                    overallScore: entity.overallScore,
                    deltaArousal: entity.deltaArousal,
                    deltaValence: entity.deltaValence,
                    rawFeatures: features,
                    f0Mean: entity.f0Mean,
                    f0Range: entity.f0Range,
                    jitter: entity.jitter,
                    shimmer: entity.shimmer,
                    hnr: entity.hnr,
                    speechRate: entity.speechRate,
                    pauseRate: entity.pauseRate,
                    loudnessMean: entity.loudnessMean,
                    loudnessRange: entity.loudnessRange,
                    flags: (entity.flagsRaw ?? "")
                        .split(separator: ",")
                        .compactMap { AcousticFlag(rawValue: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) },
                    warmth: entity.warmth,
                    stability: entity.stability,
                    energy: entity.energy,
                    tempo: entity.tempo,
                    openness: entity.openness,
                    conversationId: entity.conversationId,
                    roundIndex: entity.roundIndex,
                    deltaEnergy: entity.deltaEnergy,
                    deltaTension: entity.deltaTension,
                    deltaFatigue: entity.deltaFatigue,
                    deltaWarmth: entity.deltaWarmth,
                    deltaExpressiveness: entity.deltaExpressiveness,
                    deltaTempo: entity.deltaTempo,
                    cardTitle: entity.cardTitle,
                    cardRarity: entity.cardRarity,
                    cardAtmosphereHex: entity.cardAtmosphereHex,
                    voiceObservation: entity.voiceObservation
                )
            }
        }
    }

    func todayHasEntry() -> Bool {
        context.performAndWait {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()

            let request: NSFetchRequest<CDJournalEntry> = CDJournalEntry.fetchRequest()
            request.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
            request.fetchLimit = 1
            return ((try? context.count(for: request)) ?? 0) > 0
        }
    }

    func totalEntriesCount() -> Int {
        context.performAndWait {
            let request: NSFetchRequest<CDJournalEntry> = CDJournalEntry.fetchRequest()
            return (try? context.count(for: request)) ?? 0
        }
    }

    func weeklyVoiceProfile(weeks: Int = 4) -> [WeeklyVoiceSnapshot] {
        let journalEntries = entries(lastDays: weeks * 7)
        let calendar = Calendar.current
        var snapshots: [WeeklyVoiceSnapshot] = []

        for weekOffset in 0..<weeks {
            guard let currentWeekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()),
                  let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)
            else { continue }

            let weekEntries = journalEntries.filter { $0.date >= currentWeekStart && $0.date < nextWeekStart }
            guard !weekEntries.isEmpty else { continue }

            let count = Double(weekEntries.count)
            let avgEnergy = weekEntries.map(\.energyLevel).reduce(0, +) / count
            let avgStability = weekEntries.map(\.voiceStability).reduce(0, +) / count
            let avgWarmth = weekEntries.map(\.vocalWarmth).reduce(0, +) / count
            let avgF0 = weekEntries.compactMap { $0.rawFeatures[FeatureKeys.f0Mean] }.reduce(0, +) / count
            let dominantQuadrant = weekEntries.map(\.quadrant)
                .reduce(into: [EmotionQuadrant: Int]()) { $0[$1, default: 0] += 1 }
                .max(by: { $0.value < $1.value })?
                .key

            snapshots.append(
                WeeklyVoiceSnapshot(
                    weekStart: currentWeekStart,
                    avgEnergy: avgEnergy,
                    avgStability: avgStability,
                    avgWarmth: avgWarmth,
                    avgF0: avgF0,
                    entryCount: weekEntries.count,
                    dominantQuadrant: dominantQuadrant
                )
            )
        }

        return snapshots.sorted(by: { $0.weekStart < $1.weekStart })
    }
}

enum EmotionEngine {
    static func calculateProfile(
        features: [String: Double],
        spectral: SpectralBandResult,
        f0MeanBaseline: Double
    ) -> EmotionProfile {
        let arousal = calculateArousal(features: features)
        let valence = calculateAcousticValenceHints(
            hnr: f(features, FeatureKeys.hnr, 3.0),
            spectralWarmth: Double(spectral.warmthScore),
            spectralBody: Double(spectral.bodyScore),
            shimmer: f(features, FeatureKeys.shimmer, 0.18),
            f0Mean: f(features, FeatureKeys.f0Mean, 120),
            f0MeanBaseline: f0MeanBaseline
        )
        return EmotionProfile(arousal: Float(arousal), acousticValence: Float(valence))
    }

    static func calculateArousal(features: [String: Double]) -> Double {
        // Arousal intentionally avoids absolute RMS loudness (microphone/device dependent).
        let speechRate = f(features, FeatureKeys.speechRate, 4.0)
        let f0Range = f(features, FeatureKeys.f0RangeST, f(features, FeatureKeys.f0Range, 5.0))
        let f0StdDev = f(features, FeatureKeys.f0StdDev, f(features, FeatureKeys.f0Variability, 9.0))
        let articulationRate = f(features, FeatureKeys.articulationRate, 6.0)
        let dynamicRange = f(features, FeatureKeys.loudnessDynamicRangeOriginal, f(features, FeatureKeys.loudnessDynamicRange, 25.0))

        let speechRateNorm = mapTo01(speechRate, min: 2.5, max: 6.5)
        let f0RangeNorm = mapTo01(f0Range, min: 2.0, max: 12.0)
        let f0VarNorm = mapTo01(f0StdDev, min: 4.0, max: 18.0)
        let articulationNorm = mapTo01(articulationRate, min: 4.0, max: 9.0)
        let dynamicNorm = mapTo01(dynamicRange, min: 15.0, max: 40.0)

        let arousal01 =
            speechRateNorm * 0.25
            + f0RangeNorm * 0.20
            + f0VarNorm * 0.20
            + articulationNorm * 0.15
            + dynamicNorm * 0.20

        return clamp(arousal01 * 100)
    }

    static func calculateAcousticValenceHints(
        hnr: Double,
        spectralWarmth: Double,
        spectralBody: Double,
        shimmer: Double,
        f0Mean: Double,
        f0MeanBaseline: Double
    ) -> Double {
        let hnrScore = mapToScore(hnr, low: 0.5, high: 5.0)
        let warmthScore = mapToScore(spectralWarmth, low: 0.03, high: 0.15)
        let bodyScore = mapToScore(spectralBody, low: 0.02, high: 0.10)
        let shimmerInverse = 100 - mapToScore(shimmer, low: 0.05, high: 0.30)

        let safeBaseline = max(1.0, f0MeanBaseline)
        let f0Deviation = (f0Mean - safeBaseline) / safeBaseline
        let f0Score = mapToScore(f0Deviation, low: -0.15, high: 0.15)

        return clamp(
            hnrScore * 0.30
                + warmthScore * 0.25
                + bodyScore * 0.15
                + shimmerInverse * 0.15
                + f0Score * 0.15
        )
    }

    static func deriveFlags(
        features: [String: Double],
        deltas: BaselineDeltas,
        hasReliableBaseline: Bool
    ) -> [AcousticFlag] {
        let threshold: Float = 1.2
        if !hasReliableBaseline {
            return deriveAbsoluteFlags(features: features)
        }

        var flags: [AcousticFlag] = []

        if deltas.f0ZScore < -threshold {
            flags.append(.isMonotone)
        } else if deltas.f0ZScore > threshold {
            flags.append(.isHighPitchVariation)
        }
        if deltas.jitterZScore > threshold { flags.append(.isJitterElevated) }

        if deltas.speechRateZScore > threshold {
            flags.append(.isTempoFast)
        } else if deltas.speechRateZScore < -threshold {
            flags.append(.isTempoSlow)
        }

        if deltas.pauseRateZScore > threshold {
            flags.append(.isPauseLong)
        } else if deltas.pauseRateZScore < -threshold {
            flags.append(.isPauseAbsent)
        }

        if deltas.loudnessZScore < -threshold {
            flags.append(.isLoudnessLow)
        } else if deltas.loudnessZScore > threshold {
            flags.append(.isLoudnessHigh)
        }

        if deltas.hnrZScore > threshold {
            flags.append(.isWarmthHigh)
        } else if deltas.hnrZScore < -threshold {
            flags.append(.isWarmthLow)
        }

        return flags
    }

    static func deriveAbsoluteFlags(features: [String: Double]) -> [AcousticFlag] {
        var flags: [AcousticFlag] = []
        let f0Range = f(features, FeatureKeys.f0RangeST, f(features, FeatureKeys.f0Range, 0))
        let jitter = f(features, FeatureKeys.jitter, 0)
        let speechRate = f(features, FeatureKeys.speechRate, 0)
        let pauseRate = f(features, FeatureKeys.pauseRate, 0)
        let pauseRate01 = normalizedPauseRate01(pauseRate)
        let loudness = f(features, FeatureKeys.loudnessRMSOriginal, f(features, FeatureKeys.loudnessRMS, f(features, FeatureKeys.loudness, 0)))

        if f0Range < 3 { flags.append(.isMonotone) }
        if jitter > 2.5 { flags.append(.isJitterElevated) }
        if speechRate > 5.5 { flags.append(.isTempoFast) }
        if speechRate < 2.5 { flags.append(.isTempoSlow) }
        if pauseRate01 > 0.40 { flags.append(.isPauseLong) }
        if pauseRate01 < 0.10 { flags.append(.isPauseAbsent) }
        if loudness < 0.004 { flags.append(.isLoudnessLow) }
        return flags
    }

    static func calculateDimensions(features: [String: Double], arousal _: Float) -> EngineVoiceDimensions {
        let f0Range = Float(f(features, FeatureKeys.f0RangeST, f(features, FeatureKeys.f0Range, 5.0)))
        let f0Var = Float(f(features, FeatureKeys.f0StdDev, f(features, FeatureKeys.f0Variability, 10.0)))
        let jitter = Float(f(features, FeatureKeys.jitter, 0.025))
        let shimmer = Float(f(features, FeatureKeys.shimmer, 0.15))
        let hnr = Float(f(features, FeatureKeys.hnr, 3.5))
        let speechRate = Float(f(features, FeatureKeys.speechRate, 4.0))
        let articulationRate = Float(f(features, FeatureKeys.articulationRate, 7.0))
        let pauseDur = Float(f(features, FeatureKeys.meanPauseDuration, f(features, FeatureKeys.pauseDuration, 0.4)))
        let loudnessRange = Float(f(features, FeatureKeys.loudnessDynamicRangeOriginal, f(features, FeatureKeys.loudnessDynamicRange, 30.0)))
        let spectralWarmth = Float(f(features, "spectralWarmthRatio", 0.5))

        let e1 = mapTo01(Double(speechRate), min: 2.5, max: 6.0)
        let e2 = mapTo01(Double(f0Var), min: 4.0, max: 18.0)
        let e3 = mapTo01(Double(articulationRate), min: 4.0, max: 9.0)
        let e4 = mapTo01(Double(loudnessRange), min: 15.0, max: 40.0)
        let energy = e1 * 0.30 + e2 * 0.25 + e3 * 0.20 + e4 * 0.25

        let t1 = mapTo01(Double(jitter * 40), min: 0.4, max: 1.2)
        let t2 = mapTo01(Double(shimmer), min: 0.10, max: 0.25)
        let t3 = mapTo01(Double(1 - hnr / 8), min: 0.0, max: 1.0)
        let t4 = mapTo01(Double(1 - pauseDur), min: 0.0, max: 1.0)
        let t5 = mapTo01(Double(speechRate), min: 3.0, max: 6.0)
        let tension = t1 * 0.25 + t2 * 0.20 + t3 * 0.20 + t4 * 0.15 + t5 * 0.20

        let f1 = 1 - mapTo01(Double(f0Range), min: 2.0, max: 10.0)
        let f2 = 1 - mapTo01(Double(speechRate), min: 2.5, max: 6.0)
        let f3 = mapTo01(Double(pauseDur), min: 0.2, max: 1.0)
        let f4 = mapTo01(Double(shimmer), min: 0.10, max: 0.25)
        let f5 = 1 - mapTo01(Double(loudnessRange), min: 15.0, max: 40.0)
        let fatigue = f1 * 0.25 + f2 * 0.25 + f3 * 0.20 + f4 * 0.15 + f5 * 0.15

        let w1 = mapTo01(Double(hnr), min: 1.5, max: 8.0)
        let w2 = mapTo01(Double(1 - shimmer * 5), min: 0.0, max: 1.0)
        let w3 = mapTo01(Double(spectralWarmth), min: 0.3, max: 0.7)
        let warmth = w1 * 0.40 + w2 * 0.30 + w3 * 0.30

        let x1 = mapTo01(Double(f0Range), min: 2.0, max: 10.0)
        let x2 = mapTo01(Double(f0Var), min: 4.0, max: 18.0)
        let x3 = mapTo01(Double(loudnessRange), min: 15.0, max: 40.0)
        let x4 = 1 - mapTo01(Double(pauseDur), min: 0.2, max: 0.8)
        let expressiveness = x1 * 0.35 + x2 * 0.30 + x3 * 0.20 + x4 * 0.15

        let tempo = mapTo01(Double(speechRate), min: 2.5, max: 6.5)

        return EngineVoiceDimensions(
            energy: clamp01(Float(energy)),
            tension: clamp01(Float(tension)),
            fatigue: clamp01(Float(fatigue)),
            warmth: clamp01(Float(warmth)),
            expressiveness: clamp01(Float(expressiveness)),
            tempo: clamp01(Float(tempo))
        )
    }

    static func fallbackMoodCategory(arousal: Float, valence: Float) -> MoodCategory {
        switch (arousal, valence) {
        case (75..., 68...): return .begeistert
        case (62..., 52..<68): return .aufgekratzt
        case (65..., ..<45): return .aufgewuehlt
        case (52..<65, ..<52): return .angespannt
        case (..<30, ..<35): return .erschoepft
        case (30..<48, ..<42): return .verletzlich
        case (35..<55, 40..<60): return .nachdenklich
        case (..<55, 60...): return .zufrieden
        case (..<50, 48..<60): return .ruhig
        default: return .frustriert
        }
    }

    static func fallbackLabel(arousal: Float, valence: Float) -> String {
        switch fallbackMoodCategory(arousal: arousal, valence: valence) {
        case .begeistert: return "Energetisch"
        case .aufgewuehlt: return "Aufgewühlt"
        case .zufrieden: return "Ruhig"
        case .erschoepft: return "Erschöpft"
        default: return "Ruhig"
        }
    }

    private static func mapToScore(_ value: Double, low: Double, high: Double) -> Double {
        guard high > low else { return 50 }
        let normalized = (value - low) / (high - low)
        return clamp(normalized * 100)
    }

    private static func mapTo01(_ value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0.5 }
        return Swift.min(Swift.max((value - min) / (max - min), 0), 1)
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(100, value))
    }

    private static func f(_ features: [String: Double], _ key: String, _ fallback: Double) -> Double {
        features[key] ?? fallback
    }

    private static func normalizedPauseRate01(_ pauseRate: Double) -> Float {
        // Supports both representations:
        // - ratio 0...1
        // - pauses/minute (typical 0...40)
        if pauseRate <= 1.2 {
            return clamp01(Float(pauseRate))
        }
        return clamp01(Float(pauseRate / 40.0))
    }

    private static func clamp01(_ value: Float) -> Float {
        Swift.min(Swift.max(value, 0), 1)
    }
}
