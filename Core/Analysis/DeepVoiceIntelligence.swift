import Foundation

struct TimestampedWord: Codable {
    let word: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

struct SegmentFeatureWindow {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let features: [String: Double]
}

struct EnrichedSegment: Codable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let words: [TimestampedWord]
    let features: [String: Double]
    let dimensions: EngineVoiceDimensions

    var text: String { words.map(\.word).joined(separator: " ") }
}

struct SegmentShift: Codable {
    let fromSegment: Int
    let toSegment: Int
    let dimension: String
    let direction: Float
    let magnitude: Float
    let triggerWords: [String]
}

enum MentionType: String, Codable {
    case person
    case topic
    case place
}

struct MentionReaction: Codable {
    let mention: String
    let mentionType: MentionType
    let averageDimensions: EngineVoiceDimensions
    let occurrences: Int
    let trend: Float?
}

struct LinguisticAnalysis: Codable {
    let hedging: Float
    let distancing: Float
    let negation: Float
    let absoluteness: Float
    let selfReference: Float
    let questionRatio: Float

    static func analyze(transcript: String) -> LinguisticAnalysis {
        let lower = transcript.lowercased()
        let words = lower
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        let totalWords = Float(max(words.count, 1))

        let hedgeWords = Set(["eigentlich", "vielleicht", "irgendwie", "bisschen", "etwas", "quasi", "sozusagen", "halt", "eben", "schon"])
        let distanceWords = Set(["man", "halt", "eben", "irgendwie", "irgendwer", "jemand"])
        let negationWords = Set(["nicht", "kein", "keine", "keinen", "nie", "niemals", "nichts", "nirgends", "weder"])
        let absoluteWords = Set(["immer", "nie", "alles", "nichts", "jeder", "keiner", "staendig", "ständig", "total", "komplett", "absolut"])
        let selfWords = Set(["ich", "mir", "mich", "mein", "meine", "meinem", "meinen"])

        let hedging = Float(words.filter { hedgeWords.contains($0) }.count) / totalWords
        let distancing = Float(words.filter { distanceWords.contains($0) }.count) / totalWords
        let negation = Float(words.filter { negationWords.contains($0) }.count) / totalWords
        let absoluteness = Float(words.filter { absoluteWords.contains($0) }.count) / totalWords
        let selfRef = Float(words.filter { selfWords.contains($0) }.count) / totalWords
        let questionCount = transcript.filter { $0 == "?" }.count

        return LinguisticAnalysis(
            hedging: min(hedging * 10, 1),
            distancing: min(distancing * 10, 1),
            negation: min(negation * 8, 1),
            absoluteness: min(absoluteness * 12, 1),
            selfReference: min(selfRef * 5, 1),
            questionRatio: min(Float(questionCount) / max(Float(questionCount + 2), 1), 1)
        )
    }
}

struct Absence: Codable {
    let theme: String
    let lastMentioned: Date
    let previousFrequency: Int
}

enum AbsenceDetector {
    static func detectAbsences(
        recentEntries: [JournalEntry],
        olderEntries: [JournalEntry]
    ) -> [Absence] {
        let recentThemes = Set(recentEntries.flatMap(\.themes))
        let olderThemes = Set(olderEntries.flatMap(\.themes))
        let disappeared = olderThemes.subtracting(recentThemes)

        let significant = disappeared.filter { theme in
            olderEntries.filter { $0.themes.contains(theme) }.count >= 2
        }

        return significant.map { theme in
            let lastMention = olderEntries
                .filter { $0.themes.contains(theme) }
                .map(\.date)
                .max() ?? Date()
            return Absence(
                theme: theme,
                lastMentioned: lastMention,
                previousFrequency: olderEntries.filter { $0.themes.contains(theme) }.count
            )
        }
        .sorted(by: { $0.lastMentioned > $1.lastMentioned })
    }
}

@MainActor
final class MentionTracker {
    static let shared = MentionTracker()

    private struct MentionSample: Codable {
        let dimensions: EngineVoiceDimensions
        let timestamp: TimeInterval
    }

    private let key = "kluna_mention_reactions_v1"
    private var reactions: [String: [MentionSample]] = [:]

    private init() {
        load()
    }

    func trackMention(word: String, segmentDimensions: EngineVoiceDimensions) {
        let clean = word
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)
        guard clean.count >= 2 else { return }
        let key = clean.lowercased()
        if reactions[key] == nil { reactions[key] = [] }
        reactions[key]?.append(
            MentionSample(
                dimensions: segmentDimensions,
                timestamp: Date().timeIntervalSince1970
            )
        )
        save()
    }

    func reactionFor(_ word: String) -> MentionReaction? {
        let key = word.lowercased()
        guard let samples = reactions[key], samples.count >= 2 else { return nil }
        let dims = samples.map(\.dimensions)
        let c = Float(max(1, dims.count))
        let avg = EngineVoiceDimensions(
            energy: dims.map(\.energy).reduce(0, +) / c,
            tension: dims.map(\.tension).reduce(0, +) / c,
            fatigue: dims.map(\.fatigue).reduce(0, +) / c,
            warmth: dims.map(\.warmth).reduce(0, +) / c,
            expressiveness: dims.map(\.expressiveness).reduce(0, +) / c,
            tempo: dims.map(\.tempo).reduce(0, +) / c
        )

        var trend: Float?
        if dims.count >= 4 {
            let mid = dims.count / 2
            let first = dims.prefix(mid).map(\.tension).reduce(0, +) / Float(max(1, mid))
            let second = dims.suffix(mid).map(\.tension).reduce(0, +) / Float(max(1, mid))
            trend = second - first
        }

        return MentionReaction(
            mention: word,
            mentionType: guessMentionType(word),
            averageDimensions: avg,
            occurrences: dims.count,
            trend: trend
        )
    }

    func allSignificantReactions() -> [MentionReaction] {
        reactions.keys.compactMap { reactionFor($0) }
            .filter { $0.occurrences >= 2 }
            .sorted { $0.occurrences > $1.occurrences }
    }

    func guessMentionType(_ word: String) -> MentionType {
        if word.first?.isUppercase == true { return .person }
        return .topic
    }

    func reset() {
        reactions = [:]
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(reactions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [MentionSample]].self, from: data) else {
            reactions = [:]
            return
        }
        reactions = decoded
    }
}

enum DeepVoiceIntelligence {
    static func timestampedWords(whisperSegments: [WhisperSegment]?) -> [TimestampedWord] {
        guard let whisperSegments, !whisperSegments.isEmpty else { return [] }
        var words: [TimestampedWord] = []
        for segment in whisperSegments {
            let tokens = segment.text
                .components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }
                .filter { !$0.isEmpty }
            guard !tokens.isEmpty else { continue }
            let duration = max(0.05, segment.end - segment.start)
            let slot = duration / Double(tokens.count)
            for (index, token) in tokens.enumerated() {
                let start = segment.start + (Double(index) * slot)
                let end = min(segment.end, start + slot)
                words.append(
                    TimestampedWord(word: token, startTime: start, endTime: end)
                )
            }
        }
        return words
    }

    static func enrichSegments(
        segmentWindows: [SegmentFeatureWindow],
        words: [TimestampedWord]
    ) -> [EnrichedSegment] {
        segmentWindows.map { window in
            let segmentWords = words.filter { $0.startTime >= window.startTime && $0.startTime < window.endTime }
            return EnrichedSegment(
                startTime: window.startTime,
                endTime: window.endTime,
                words: segmentWords,
                features: window.features,
                dimensions: EmotionEngine.calculateDimensions(
                    features: window.features,
                    arousal: Float(EmotionEngine.calculateArousal(features: window.features))
                )
            )
        }
    }

    static func detectShifts(segments: [EnrichedSegment]) -> [SegmentShift] {
        guard segments.count >= 2 else { return [] }
        var shifts: [SegmentShift] = []

        for i in 1..<segments.count {
            let prev = segments[i - 1].dimensions
            let curr = segments[i].dimensions
            let checks: [(String, Float, Float)] = [
                ("Energie", prev.energy, curr.energy),
                ("Anspannung", prev.tension, curr.tension),
                ("Muedigkeit", prev.fatigue, curr.fatigue),
                ("Waerme", prev.warmth, curr.warmth),
                ("Lebendigkeit", prev.expressiveness, curr.expressiveness),
                ("Tempo", prev.tempo, curr.tempo),
            ]
            for (name, a, b) in checks {
                let diff = b - a
                if abs(diff) > 0.15 {
                    let words = Array(segments[i].words.prefix(3).map(\.word))
                    shifts.append(
                        SegmentShift(
                            fromSegment: i - 1,
                            toSegment: i,
                            dimension: name,
                            direction: diff,
                            magnitude: abs(diff),
                            triggerWords: words
                        )
                    )
                }
            }
        }
        return shifts
    }

    @MainActor
    static func trackMentionsInSegments(segments: [EnrichedSegment], themes: [String]) {
        for segment in segments {
            let text = segment.text.lowercased()
            for theme in themes {
                let themeWords = theme.lowercased().split(separator: " ").map(String.init)
                if !themeWords.isEmpty, themeWords.allSatisfy({ text.contains($0) }) {
                    MentionTracker.shared.trackMention(word: theme, segmentDimensions: segment.dimensions)
                }
            }
            for (index, word) in segment.words.enumerated() {
                if word.word.first?.isUppercase == true && index > 0 {
                    MentionTracker.shared.trackMention(word: word.word, segmentDimensions: segment.dimensions)
                }
            }
        }
    }

    static func buildDeepInput(
        transcript: String,
        dims: EngineVoiceDimensions,
        flags: [String],
        shifts: [SegmentShift],
        linguistic: LinguisticAnalysis,
        mentionReactions: [MentionReaction],
        absences: [Absence],
        lastEntries: [JournalEntry]
    ) -> String {
        var input = ""
        input += "Text: \(String(transcript.prefix(400)))\n"
        input += "Stimme: E:\(percent(dims.energy)) An:\(percent(dims.tension)) M:\(percent(dims.fatigue)) W:\(percent(dims.warmth)) L:\(percent(dims.expressiveness)) T:\(percent(dims.tempo))\n"

        if !flags.isEmpty {
            input += "Auffaellig: \(flags.prefix(3).joined(separator: ", "))\n"
        }

        if !shifts.isEmpty {
            input += "\nStimmveraenderungen waehrend der Aufnahme:\n"
            for shift in shifts.prefix(3) {
                let direction = shift.direction > 0 ? "steigt" : "sinkt"
                let words = shift.triggerWords.joined(separator: " ")
                input += "- \(shift.dimension) \(direction) bei \"\(words)\"\n"
            }
        }

        if linguistic.hedging > 0.3 {
            input += "\nSprachmuster: Viele Relativierungen (eigentlich, vielleicht, irgendwie)\n"
        }
        if linguistic.distancing > 0.3 {
            input += "Sprachmuster: Distanzierte Sprache (man, halt) statt ich\n"
        }
        if linguistic.absoluteness > 0.3 {
            input += "Sprachmuster: Absolute Aussagen (immer, nie, alles)\n"
        }

        let significant = mentionReactions.filter { $0.occurrences >= 3 }
        if !significant.isEmpty {
            input += "\nBekannte Stimmreaktionen:\n"
            for reaction in significant.prefix(3) {
                input += "- Bei \"\(reaction.mention)\": meist \(dominantDimension(reaction.averageDimensions))"
                if let trend = reaction.trend, abs(trend) > 0.1 {
                    input += trend > 0 ? " (wird angespannter ueber Zeit)" : " (wird entspannter ueber Zeit)"
                }
                input += "\n"
            }
        }

        if !absences.isEmpty {
            input += "\nNicht mehr erwaehnt:\n"
            for absence in absences.prefix(2) {
                let days = Calendar.current.dateComponents([.day], from: absence.lastMentioned, to: Date()).day ?? 0
                input += "- \"\(absence.theme)\" - zuletzt vor \(days) Tagen, davor \(absence.previousFrequency)x erwaehnt\n"
            }
        }

        if let last = lastEntries.first {
            input += "\nDavor: \"\(String(last.transcript.prefix(100)))\" (\(last.moodLabel ?? "?"))\n"
        }

        return input
    }

    static func dominantDimension(_ d: EngineVoiceDimensions) -> String {
        let dims: [(String, Float)] = [
            ("energetisch", d.energy),
            ("angespannt", d.tension),
            ("muede", d.fatigue),
            ("warm", d.warmth),
            ("lebendig", d.expressiveness),
        ]
        return dims.max(by: { $0.1 < $1.1 })?.0 ?? "neutral"
    }

    private static func percent(_ value: Float) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
