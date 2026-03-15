import Foundation
import AVFoundation
import Combine
import CoreData
import CoreGraphics
import SwiftUI

@MainActor
final class KlunaDataManager: ObservableObject {
    static let shared = KlunaDataManager()

    @Published var entries: [JournalEntry] = []
    @Published var lastUpdated: Date = Date()

    private let journalManager: JournalManager

    private init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.journalManager = JournalManager(context: context)
        loadEntries()
    }

    func loadEntries(limit: Int = 500) {
        entries = journalManager.recentEntries(limit: limit)
        lastUpdated = Date()
    }

    func refresh(limit: Int = 500) {
        loadEntries(limit: limit)
    }

    func addEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        lastUpdated = Date()
    }
}

struct GeneratedVoiceType: Codable, Equatable {
    let key: String
    let name: String
    let nameEN: String
    let emoji: String
    let description: String
    let descriptionEN: String
    let colorHex: String
    var color: Color { Color(hex: colorHex) }
}

enum VoiceTypeGenerator {
    enum Trait: String, CaseIterable { case energy, tension, warmth, expressiveness, tempo, fatigue }

    static func generate(dims: VoiceDimensions) -> GeneratedVoiceType {
        let dominant = findDominant(dims)
        let secondary = findSecondary(dims, excluding: dominant)
        return voiceTypeMap["\(dominant.rawValue)_\(secondary.rawValue)"] ?? fallback
    }

    static func saveLatest(_ type: GeneratedVoiceType) {
        guard let data = try? JSONEncoder().encode(type) else { return }
        UserDefaults.standard.set(data, forKey: "kluna_latest_voice_type")
    }

    static func loadLatest() -> GeneratedVoiceType? {
        guard let data = UserDefaults.standard.data(forKey: "kluna_latest_voice_type") else { return nil }
        return try? JSONDecoder().decode(GeneratedVoiceType.self, from: data)
    }

    private static func findDominant(_ d: VoiceDimensions) -> Trait {
        let values: [(Trait, CGFloat)] = [(.energy, d.energy), (.warmth, d.warmth), (.expressiveness, d.expressiveness), (.tension, d.tension), (.fatigue, d.fatigue), (.tempo, d.tempo)]
        return values.max(by: { $0.1 < $1.1 })?.0 ?? .warmth
    }

    private static func findSecondary(_ d: VoiceDimensions, excluding: Trait) -> Trait {
        let values: [(Trait, CGFloat)] = [(.energy, d.energy), (.warmth, d.warmth), (.expressiveness, d.expressiveness), (.tension, d.tension), (.fatigue, d.fatigue), (.tempo, d.tempo)].filter { $0.0 != excluding }
        return values.max(by: { $0.1 < $1.1 })?.0 ?? .warmth
    }

    private static let fallback = GeneratedVoiceType(
        key: "default", name: "Der Entdecker", nameEN: "The Explorer", emoji: "🔭",
        description: "Neugierig und offen. Deine Stimme sucht.",
        descriptionEN: "Curious and open. Your voice is searching.",
        colorHex: "6BC5A0"
    )

    private static let voiceTypeMap: [String: GeneratedVoiceType] = [
        "warmth_expressiveness": .init(key: "warmth_expressiveness", name: "Die warme Flamme", nameEN: "The Warm Flame", emoji: "🔥", description: "Wärme und Lebendigkeit. Deine Stimme leuchtet bei Menschen.", descriptionEN: "Warmth and liveliness. Your voice lights up around people.", colorHex: "E8825C"),
        "warmth_energy": .init(key: "warmth_energy", name: "Das offene Herz", nameEN: "The Open Heart", emoji: "💛", description: "Warm und energetisch. Deine Stimme strahlt Zuversicht aus.", descriptionEN: "Warm and energetic. Your voice radiates confidence.", colorHex: "F5B731"),
        "energy_expressiveness": .init(key: "energy_expressiveness", name: "Der Wirbelwind", nameEN: "The Whirlwind", emoji: "🌪️", description: "Voller Energie und Ausdruck. Deine Stimme tanzt.", descriptionEN: "Full of energy and expression. Your voice dances.", colorHex: "E8825C"),
        "energy_tempo": .init(key: "energy_tempo", name: "Der Rennfahrer", nameEN: "The Racer", emoji: "⚡", description: "Schnell und kraftvoll. Deine Stimme rast vorwärts.", descriptionEN: "Fast and powerful. Your voice races ahead.", colorHex: "F5B731"),
        "expressiveness_warmth": .init(key: "expressiveness_warmth", name: "Der Geschichtenerzähler", nameEN: "The Storyteller", emoji: "📖", description: "Lebendig und warm. Deine Stimme malt Bilder.", descriptionEN: "Lively and warm. Your voice paints pictures.", colorHex: "6BC5A0"),
        "tension_energy": .init(key: "tension_energy", name: "Der Kämpfer", nameEN: "The Fighter", emoji: "🛡️", description: "Angespannt aber stark. Deine Stimme hält stand.", descriptionEN: "Tense but strong. Your voice holds its ground.", colorHex: "E85C5C"),
        "tension_tempo": .init(key: "tension_tempo", name: "Der Getriebene", nameEN: "The Driven One", emoji: "🎯", description: "Unter Druck, aber fokussiert. Deine Stimme jagt einem Ziel nach.", descriptionEN: "Under pressure but focused. Your voice chases a goal.", colorHex: "E85C5C"),
        "fatigue_warmth": .init(key: "fatigue_warmth", name: "Der stille Beschützer", nameEN: "The Quiet Guardian", emoji: "🌙", description: "Müde, aber warm. Deine Stimme gibt mehr als sie hat.", descriptionEN: "Tired but warm. Your voice gives more than it has.", colorHex: "8B9DAF"),
        "fatigue_tension": .init(key: "fatigue_tension", name: "Der Durchhalter", nameEN: "The Endurer", emoji: "🏔️", description: "Erschöpft, aber zäh. Deine Stimme gibt nicht auf.", descriptionEN: "Exhausted but tough. Your voice does not quit.", colorHex: "8B9DAF"),
        "tempo_energy": .init(key: "tempo_energy", name: "Der Blitz", nameEN: "The Lightning", emoji: "⚡", description: "Schnell und voller Kraft. Deine Stimme elektrisiert.", descriptionEN: "Fast and full of power. Your voice electrifies.", colorHex: "F5B731"),
        "warmth_fatigue": .init(key: "warmth_fatigue", name: "Die sanfte Stärke", nameEN: "The Gentle Strength", emoji: "🕊️", description: "Warm trotz Müdigkeit. Deine Stimme tröstet zuerst andere.", descriptionEN: "Warm despite fatigue. Your voice comforts others first.", colorHex: "B088A8"),
        "expressiveness_tension": .init(key: "expressiveness_tension", name: "Das Gewitter", nameEN: "The Thunderstorm", emoji: "⛈️", description: "Emotional und angespannt. Deine Stimme trägt viel zugleich.", descriptionEN: "Emotional and tense. Your voice carries a lot at once.", colorHex: "7BA7C4"),
        "energy_warmth": .init(key: "energy_warmth", name: "Die Sonne", nameEN: "The Sun", emoji: "☀️", description: "Strahlend und herzlich. Deine Stimme wärmt jeden Raum.", descriptionEN: "Radiant and heartfelt. Your voice warms every room.", colorHex: "F5B731"),
        "fatigue_expressiveness": .init(key: "fatigue_expressiveness", name: "Der Träumer", nameEN: "The Dreamer", emoji: "💭", description: "Müde aber melodisch. Deine Stimme wandert durch innere Welten.", descriptionEN: "Tired but melodic. Your voice wanders through inner worlds.", colorHex: "B088A8"),
        "tension_warmth": .init(key: "tension_warmth", name: "Der verborgene Held", nameEN: "The Hidden Hero", emoji: "🦋", description: "Angespannt aber fürsorglich. Deine Stimme kämpft für andere.", descriptionEN: "Tense but caring. Your voice fights for others.", colorHex: "E85C5C")
    ]
}

enum VoiceTypeShareContent {
    static func shareText(type: GeneratedVoiceType, isGerman: Bool) -> String {
        isGerman
            ? "Mein Stimm-Typ ist \(type.emoji) \(type.name). Was ist deiner? 👉 kluna.app"
            : "My voice type is \(type.emoji) \(type.nameEN). What's yours? 👉 kluna.app"
    }
}

final class OpenThread {
    static let shared = OpenThread()
    var currentThread: String? {
        get { UserDefaults.standard.string(forKey: "kluna_open_thread") }
        set {
            UserDefaults.standard.set(newValue, forKey: "kluna_open_thread")
            UserDefaults.standard.synchronize()
        }
    }

    func detectThread(from conversation: ConversationManager.ActiveConversation) {
        guard let last = conversation.rounds.last else { return }
        if last.dimensions.tension > 0.6 { currentThread = "unresolved_tension"; return }
        if let q = last.claudeQuestion, !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { currentThread = q; return }
        if last.transcript.count < 60 { currentThread = "short_ending"; return }
        currentThread = nil
    }
}

enum ContradictionStore {
    private static let keyPrefix = "kluna.contradiction."

    static func save(_ contradiction: VoiceContradiction?, for entryId: UUID) {
        let key = keyPrefix + entryId.uuidString
        guard let contradiction else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        let value = "\(contradiction.wordsSay)|\(contradiction.voiceSays)"
        UserDefaults.standard.set(value, forKey: key)
    }

    static func load(for entryId: UUID) -> VoiceContradiction? {
        let key = keyPrefix + entryId.uuidString
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        let parts = raw.split(separator: "|", maxSplits: 1).map {
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return VoiceContradiction(wordsSay: parts[0], voiceSays: parts[1])
    }
}

struct VoiceSegmentSnapshot: Codable {
    let startSecond: Int
    let endSecond: Int
    let energy: Double
    let warmth: Double
    let stability: Double
    let transcriptSnippet: String?
    let tension: Double?
    let fatigue: Double?
    let expressiveness: Double?
    let tempo: Double?
    let f0Mean: Double?
    let jitter: Double?
    let hnr: Double?
    let speechRate: Double?
    let words: [TimestampedWord]?
}

enum VoiceSegmentStore {
    static func save(_ segments: [VoiceSegmentSnapshot], for entryId: UUID) {
        guard let url = fileURL(for: entryId) else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(segments)
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ Could not save voice segments: \(error)")
        }
    }

    static func load(for entryId: UUID) -> [VoiceSegmentSnapshot] {
        guard let url = fileURL(for: entryId),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([VoiceSegmentSnapshot].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func fileURL(for entryId: UUID) -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documents
            .appendingPathComponent("journal_audio_segments", isDirectory: true)
            .appendingPathComponent("\(entryId.uuidString).json")
    }
}

struct KlunaResponseViewData {
    var mood: String?
    var label: String?
    var text: String
    var themes: [String]
    var question: String?
    var voiceObservation: String?
}

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var latestSavedEntry: JournalEntry?
    @Published var latestKlunaResponse: KlunaResponseViewData?
    @Published var recordingError: String?

    private let audioRecorder = AudioRecorder()
    private let openSMILE = OpenSMILEExtractor()
    private let journalManager: JournalManager
    private let context: NSManagedObjectContext
    private let conversationManager = ConversationManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        self.journalManager = JournalManager(context: context)
        audioRecorder.$recordingDuration.assign(to: &$elapsedTime)
        audioRecorder.$audioLevel.assign(to: &$audioLevel)
    }

    func startRecording() {
        guard !isRecording else { return }
        latestSavedEntry = nil
        latestKlunaResponse = nil
        recordingError = nil
        let started = audioRecorder.startRecording(onBuffer: { _ in }, onForcedStop: { [weak self] data in
            guard let self else { return }
            Task { @MainActor in
                await self.finishRecording(with: data)
            }
        })
        isRecording = started
        if !started {
            recordingError = "Mikrofon konnte nicht gestartet werden. Bitte Berechtigung prüfen."
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        let data = audioRecorder.stopRecording()
        Task { await finishRecording(with: data) }
    }

    private func finishRecording(with audioData: Data?) async {
        isRecording = false
        guard let audioData, elapsedTime >= 3 else { return }
        isProcessing = true

        let features = openSMILE.extractFeatures(from: audioData, sampleRate: Config.audioSampleRate)
        var raw = FeatureKeyMapper.normalize(features?.asDictionary ?? [:])
        if raw[FeatureKeys.loudnessRMSOriginal] == nil {
            raw[FeatureKeys.loudnessRMSOriginal] = raw[FeatureKeys.loudnessRMS] ?? raw[FeatureKeys.loudness] ?? 0.004
        }
        if raw[FeatureKeys.loudnessDynamicRangeOriginal] == nil {
            raw[FeatureKeys.loudnessDynamicRangeOriginal] = raw[FeatureKeys.loudnessDynamicRange] ?? 17.0
        }
        if raw[FeatureKeys.pauseRate] == nil {
            raw[FeatureKeys.pauseRate] = raw[FeatureKeys.pauseDistribution] ?? 12.0
        }

        let entryId = UUID()
        let recordingURL = saveJournalAudio(pcmData: audioData, entryId: entryId)
        let transcriptionResult: TranscriptionManager.TranscriptionResult
        if let recordingURL {
            transcriptionResult = await TranscriptionManager.shared.transcribe(audioURL: recordingURL, language: "de")
        } else {
            transcriptionResult = .init(text: "", source: .failed, segments: nil, language: "de", confidence: 0)
        }

        let spectralSamples = SpectralBandAnalyzer.audioDataToFloatSamples(audioData)
        let spectral = SpectralBandAnalyzer().analyze(samples: spectralSamples, sampleRate: Float(Config.audioSampleRate))
        let pillars = PillarScoreEngine.calculatePillarScores(features: raw, spectral: spectral)
        let f0Baseline = Double(BaselineManager.shared.baselineFor("f0Mean") ?? 120)
        let emotion = EmotionEngine.calculateProfile(features: raw, spectral: spectral, f0MeanBaseline: f0Baseline)
        var enriched = raw
        enriched["acousticValence"] = Double(emotion.acousticValence)
        let calibrationResult = PersonalCalibration.shared.processEntry(features: enriched)
        KlunaAnalytics.shared.trackCalibrationPhase(calibrationResult.phase)
        let dimensions = PersonalCalibration.shared.personalizedDimensions(features: enriched)
        let personalizedArousal = PersonalCalibration.shared.personalizedArousal(features: enriched)
        enriched["arousal"] = Double(personalizedArousal)

        let deltas = PersonalCalibration.shared.baselineDeltas(from: calibrationResult)
        let hasReliableBaseline = PersonalCalibration.shared.hasReliableCalibration()
        let baselineEntryCount = PersonalCalibration.shared.entryCount
        let fallbackFlags = EmotionEngine.deriveAbsoluteFlags(features: enriched)
        let flags = PersonalCalibration.shared.acousticFlags(from: calibrationResult, fallback: fallbackFlags)
        let calibrationFlagDescriptions = calibrationResult.flags.map(\.description)

        let previous = journalManager.recentEntries(limit: 10)
        let segmentWindows = buildSegmentFeatureWindows(audioData: audioData, duration: elapsedTime)
        let timestampedWords = DeepVoiceIntelligence.timestampedWords(whisperSegments: transcriptionResult.segments)
        let enrichedSegments = DeepVoiceIntelligence.enrichSegments(
            segmentWindows: segmentWindows,
            words: timestampedWords
        )
        let segmentShifts = DeepVoiceIntelligence.detectShifts(segments: enrichedSegments)
        let linguistic = LinguisticAnalysis.analyze(transcript: transcriptionResult.text)
        let mentionReactions = MentionTracker.shared.allSignificantReactions()
        let now = Date()
        let recentEntries = previous.filter { $0.date >= Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now }
        let olderEntries = previous.filter {
            $0.date < (Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now)
                && $0.date >= (Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now)
        }
        let absences = AbsenceDetector.detectAbsences(recentEntries: recentEntries, olderEntries: olderEntries)

        enriched["linguistic_hedging"] = Double(linguistic.hedging)
        enriched["linguistic_distancing"] = Double(linguistic.distancing)
        enriched["linguistic_negation"] = Double(linguistic.negation)
        enriched["linguistic_absoluteness"] = Double(linguistic.absoluteness)
        enriched["linguistic_self_reference"] = Double(linguistic.selfReference)

        var finalCoachText: String?
        var finalMood: MoodCategory = .nachdenklich
        var finalLabel: String = "Nachdenklich"
        var finalInsight: String?
        var finalThemes: [String] = []
        var finalPrompt: String?
        var finalVoiceObservation: String?
        var parsedContradiction: VoiceContradiction?
        var claudeAvailable = false
        let entryNumber = journalManager.totalEntriesCount() + 1
        let isConversationRound = conversationManager.isInConversation
        let roundIndex = isConversationRound ? conversationManager.currentRound : 0
        let conversationDelta = isConversationRound ? conversationManager.calculateDelta(current: dimensions) : nil
        let memory = KlunaMemory.shared.fullMemory
        let lastPrompt = UserDefaults.standard.string(forKey: "kluna_last_prompt")
        print("🧠 ===== MEMORY DEBUG =====")
        print("🧠 Memory exists: \(!memory.isEmpty)")
        print("🧠 Memory length: \(memory.count) chars")
        print("🧠 Memory content: \(memory.prefix(200))")
        print("🧠 Memory layers active: \(KlunaMemory.shared.unlockedLayerCount)")
        print("🧠 =======================")
        do {
            let userName = UserDefaults.standard.string(forKey: "kluna_user_name") ?? ""
            let input = buildKlunaInput(
                memory: KlunaMemory.shared,
                transcript: transcriptionResult.text,
                features: Dictionary(uniqueKeysWithValues: enriched.map { ($0.key, Float($0.value)) }),
                calibration: calibrationResult,
                segments: enrichedSegments,
                shifts: segmentShifts,
                linguistic: linguistic,
                previousRounds: isConversationRound ? conversationManager.activeConversation?.rounds : nil,
                entryNumber: entryNumber,
                userName: userName
            )
            let rawClaude = try await CoachAPIManager.requestInsights(
                payload: input,
                systemPrompt: CoachAPIManager.klunaSystemPrompt,
                maxTokens: 420,
                apiKey: Config.claudeAPIKey
            )
            let parsed = CoachAPIManager.parseConversationResponse(rawClaude)
            claudeAvailable = true
            if let mood = MoodCategory.resolve(parsed.mood) {
                finalMood = mood
            }
            if let label = parsed.label, !label.isEmpty {
                finalLabel = label
            }
            finalCoachText = parsed.text
            finalInsight = parsed.insight
            finalThemes = parsed.themes
            finalPrompt = parsed.question
            finalVoiceObservation = parsed.voiceObservation
            latestKlunaResponse = KlunaResponseViewData(
                mood: parsed.mood,
                label: parsed.label,
                text: parsed.text,
                themes: parsed.themes,
                question: parsed.question,
                voiceObservation: parsed.voiceObservation
            )
            parsedContradiction = parsed.contradiction
            DeepVoiceIntelligence.trackMentionsInSegments(
                segments: enrichedSegments,
                themes: parsed.themes
            )
            ContradictionStore.save(parsed.contradiction, for: entryId)
        } catch {
            print("CLAUDE FAILED: \(error)")
            ContradictionStore.save(nil, for: entryId)
        }

        if !claudeAvailable {
            if dimensions.energy > 0.6 {
                finalMood = .aufgekratzt
                finalLabel = "Energetisch"
            } else if dimensions.fatigue > 0.6 {
                finalMood = .erschoepft
                finalLabel = "Müde"
            } else if dimensions.tension > 0.6 {
                finalMood = .angespannt
                finalLabel = "Angespannt"
            } else {
                finalMood = .ruhig
                finalLabel = "Ruhig"
            }
            finalCoachText = fallbackCoachText(dimensions: dimensions)
            latestKlunaResponse = KlunaResponseViewData(
                mood: finalMood.rawValue,
                label: finalLabel,
                text: finalCoachText ?? "",
                themes: finalThemes,
                question: finalPrompt,
                voiceObservation: nil
            )
        }

        var entry = JournalEntry(
            id: entryId,
            date: Date(),
            duration: elapsedTime,
            transcript: transcriptionResult.text,
            audioRelativePath: (recordingURL?.lastPathComponent).map { "journal_audio/\($0)" },
            prompt: PromptManager.shared.currentPrompt,
            mood: finalMood.rawValue,
            arousal: personalizedArousal,
            acousticValence: emotion.acousticValence,
            quadrant: finalMood.quadrant,
            moodLabel: finalLabel,
            coachText: finalCoachText,
            themes: finalThemes,
            pillarVQ: Float(pillars.voiceQuality),
            pillarClarity: Float(pillars.clarity),
            pillarDynamics: Float(pillars.dynamics),
            pillarRhythm: Float(pillars.rhythm),
            overallScore: Float(pillars.overall),
            deltaArousal: deltas.arousalDelta,
            deltaValence: deltas.valenceDelta,
            rawFeatures: enriched,
            f0Mean: Float(enriched[FeatureKeys.f0Mean] ?? 0),
            f0Range: Float(enriched[FeatureKeys.f0RangeST] ?? enriched[FeatureKeys.f0Range] ?? 0),
            jitter: Float(enriched[FeatureKeys.jitter] ?? 0),
            shimmer: Float(enriched[FeatureKeys.shimmer] ?? 0),
            hnr: Float(enriched[FeatureKeys.hnr] ?? 0),
            speechRate: Float(enriched[FeatureKeys.speechRate] ?? 0),
            pauseRate: Float(enriched[FeatureKeys.pauseRate] ?? 0),
            loudnessMean: Float(enriched[FeatureKeys.loudnessRMSOriginal] ?? enriched[FeatureKeys.loudnessRMS] ?? enriched[FeatureKeys.loudness] ?? 0),
            loudnessRange: Float(enriched[FeatureKeys.loudnessDynamicRangeOriginal] ?? enriched[FeatureKeys.loudnessDynamicRange] ?? 0),
            flags: flags,
            warmth: dimensions.warmth,
            stability: dimensions.tension,
            energy: dimensions.energy,
            tempo: dimensions.tempo,
            openness: dimensions.expressiveness,
            conversationId: isConversationRound ? conversationManager.activeConversation?.id : nil,
            roundIndex: Int16(roundIndex),
            deltaEnergy: conversationDelta?.energy ?? 0,
            deltaTension: conversationDelta?.tension ?? 0,
            deltaFatigue: conversationDelta?.fatigue ?? 0,
            deltaWarmth: conversationDelta?.warmth ?? 0,
            deltaExpressiveness: conversationDelta?.expressiveness ?? 0,
            deltaTempo: conversationDelta?.tempo ?? 0
        )
        let card = DailyCardGenerator.generate(
            entry: entry,
            dims: VoiceDimensions.from(entry),
            baseline: nil,
            zScores: calibrationResult.zScores,
            mood: finalMood.rawValue,
            coachText: finalCoachText
        )
        entry.cardTitle = card.title
        entry.cardRarity = card.rarity.rawValue
        entry.cardAtmosphereHex = DailyCardGenerator.atmosphereHexes(
            dims: VoiceDimensions.from(entry),
            mood: finalMood.rawValue
        ).joined(separator: ",")
        entry.voiceObservation = finalVoiceObservation
        let segmentSnapshots = buildVoiceSegments(from: enrichedSegments)
        let donationSegments = buildDonationSegments(from: segmentWindows)
        VoiceSegmentStore.save(segmentSnapshots, for: entry.id)
        journalManager.saveEntry(entry)
        KlunaDataManager.shared.addEntry(entry)
        KlunaAnalytics.shared.track("entry_recorded", value: "\(entryNumber)")
        KlunaAnalytics.shared.track(claudeAvailable ? "entry_with_claude" : "entry_fallback")
        if isConversationRound {
            KlunaAnalytics.shared.track("conversation_round", value: "\(roundIndex + 1)")
            let round = ConversationManager.ConversationRound(
                index: roundIndex,
                transcript: transcriptionResult.text,
                features: Dictionary(uniqueKeysWithValues: enriched.map { ($0.key, Float($0.value)) }),
                dimensions: dimensions,
                segments: enrichedSegments,
                shifts: segmentShifts,
                linguistic: linguistic,
                claudeResponse: finalCoachText ?? "Ich hoere dich.",
                claudeQuestion: finalPrompt,
                claudeVoiceObservation: finalVoiceObservation,
                claudeMood: finalMood.rawValue,
                claudeLabel: finalLabel,
                claudeThemes: finalThemes,
                hasContradiction: parsedContradiction != nil,
                contradictionWords: parsedContradiction?.wordsSay,
                contradictionVoice: parsedContradiction?.voiceSays,
                deltaFromPrevious: conversationDelta
            )
            conversationManager.addRound(round)
        }
        if parsedContradiction != nil {
            KlunaAnalytics.shared.track("contradiction_shown")
        }
        Task {
            await SupabaseManager.shared.donateFullBiomarkers(
                features: enriched,
                dimensions: dimensions,
                arousal: personalizedArousal,
                acousticValence: emotion.acousticValence,
                mood: finalMood.rawValue,
                flags: flags,
                deltas: deltas,
                pillarScores: pillars,
                voiceDNA: pillars.voiceDNA,
                segments: donationSegments,
                durationSeconds: Float(elapsedTime),
                gainApplied: Float(enriched[FeatureKeys.gainFactor] ?? 1),
                entryCount: baselineEntryCount,
                hasBaseline: hasReliableBaseline
            )
        }
        saveTodayInsightIfNeeded(finalInsight)
        if !isConversationRound,
           let prompt = finalPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !prompt.isEmpty,
           prompt.hasSuffix("?") {
            PromptManager.shared.currentPrompt = prompt
            UserDefaults.standard.set(prompt, forKey: "kluna_current_prompt")
            UserDefaults.standard.set(prompt, forKey: "kluna_last_prompt")
            UserDefaults.standard.set(prompt, forKey: "kluna_personalized_prompt")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "kluna_prompt_timestamp")
            PromptHistory.shared.addPrompt(prompt)
            KlunaWidgetBridge.shared.updateQuestion(prompt)
            Task {
                await KlunaNotificationManager.shared.refreshPromptReminder()
            }
        }
        let allEntries = journalManager.recentEntries(limit: 2000)
        let isDonating = UserDefaults.standard.bool(forKey: "kluna_data_donation_enabled")
        BadgeManager.shared.checkBadges(stats: KlunaStats.from(entries: allEntries, isDonating: isDonating))
        latestSavedEntry = entry
        KlunaWidgetBridge.shared.updateFrom(entry: entry, question: PromptManager.shared.currentPrompt)

        let dimensionsSummary = "E:\(Int((dimensions.energy * 100).rounded()))% An:\(Int((dimensions.tension * 100).rounded()))% M:\(Int((dimensions.fatigue * 100).rounded()))% W:\(Int((dimensions.warmth * 100).rounded()))% L:\(Int((dimensions.expressiveness * 100).rounded()))% T:\(Int((dimensions.tempo * 100).rounded()))%"
        let contradictionText = parsedContradiction.map { "\($0.wordsSay) | \($0.voiceSays)" }
        let memoryFlags = calibrationFlagDescriptions.isEmpty ? flags.map(\.promptLabel) : calibrationFlagDescriptions
        let shiftText = segmentShifts.prefix(1).map { shift in
            let direction = shift.direction > 0 ? "↑" : "↓"
            return "\(shift.dimension)\(direction) bei \"\(shift.triggerWords.joined(separator: " "))\""
        }.first
        let linguisticNote: String? = {
            var notes: [String] = []
            if linguistic.hedging > 0.3 { notes.append("relativiert viel") }
            if linguistic.distancing > 0.3 { notes.append("distanziert (man/halt)") }
            if linguistic.absoluteness > 0.3 { notes.append("absolute Aussagen") }
            if linguistic.negation > 0.3 { notes.append("viel Verneinung") }
            return notes.isEmpty ? nil : notes.joined(separator: " · ")
        }()
        if !isConversationRound {
            let memoryPayload = MemoryEntryData(
                date: Date(),
                mood: finalMood.rawValue,
                label: finalLabel,
                transcriptSnippet: String(transcriptionResult.text.prefix(200)),
                themes: finalThemes,
                dimensionsSummary: dimensionsSummary,
                flags: memoryFlags,
                contradiction: contradictionText,
                entryNumber: entryNumber,
                shift: shiftText,
                linguisticNote: linguisticNote
            )
            Task {
                await KlunaMemory.shared.updateMemory(newEntry: memoryPayload)
            }
        }

        isProcessing = false
        elapsedTime = 0
    }

    private func saveTodayInsightIfNeeded(_ insight: String?) {
        guard let trimmed = insight?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: "todayInsight")
        UserDefaults.standard.set(Date(), forKey: "todayInsightDate")
        UserDefaults.standard.set(trimmed, forKey: "kluna_today_insight")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "kluna_insight_timestamp")
    }

    private func saveJournalAudio(pcmData: Data, entryId: UUID) -> URL? {
        guard !pcmData.isEmpty else { return nil }
        guard let sourceURL = AudioRecorder.saveRecordingForPlayback(pcmData: pcmData, sessionId: entryId) else { return nil }
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return sourceURL }
        let dir = documents.appendingPathComponent("journal_audio", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let destination = dir.appendingPathComponent("\(entryId.uuidString).wav")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            print("❌ Could not save journal audio: \(error)")
            return sourceURL
        }
    }

    private func buildSegmentFeatureWindows(
        audioData: Data,
        duration: TimeInterval
    ) -> [SegmentFeatureWindow] {
        guard duration > 0.8 else { return [] }

        let segmentDuration: TimeInterval = 5
        let segmentCount = max(1, Int(ceil(duration / segmentDuration)))
        var windows: [SegmentFeatureWindow] = []

        for index in 0..<segmentCount {
            let start = TimeInterval(index) * segmentDuration
            let end = min(duration, start + segmentDuration)
            guard end - start > 0.4 else { continue }

            let features = openSMILE.extractFeatures(
                from: audioData,
                sampleRate: Config.audioSampleRate,
                startTime: start,
                endTime: end
            )
            let normalized = FeatureKeyMapper.normalize(features?.asDictionary ?? [:])
            windows.append(
                SegmentFeatureWindow(
                    startTime: start,
                    endTime: end,
                    features: normalized
                )
            )
        }

        return windows
    }

    private func buildVoiceSegments(
        from enrichedSegments: [EnrichedSegment]
    ) -> [VoiceSegmentSnapshot] {
        enrichedSegments.map { segment in
            VoiceSegmentSnapshot(
                startSecond: Int(segment.startTime.rounded(.down)),
                endSecond: Int(segment.endTime.rounded(.up)),
                energy: Double(segment.dimensions.energy),
                warmth: Double(segment.dimensions.warmth),
                stability: Double(max(0, min(1, 1 - segment.dimensions.tension))),
                transcriptSnippet: segment.text.isEmpty ? nil : segment.text,
                tension: Double(segment.dimensions.tension),
                fatigue: Double(segment.dimensions.fatigue),
                expressiveness: Double(segment.dimensions.expressiveness),
                tempo: Double(segment.dimensions.tempo),
                f0Mean: segment.features[FeatureKeys.f0Mean],
                jitter: segment.features[FeatureKeys.jitter],
                hnr: segment.features[FeatureKeys.hnr],
                speechRate: segment.features[FeatureKeys.speechRate],
                words: segment.words
            )
        }
    }

    private func buildDonationSegments(
        from segmentWindows: [SegmentFeatureWindow]
    ) -> [DonationSegmentData] {
        var segments: [DonationSegmentData] = []
        for window in segmentWindows {
            segments.append(
                DonationSegmentData(
                    startSeconds: Float(window.startTime),
                    endSeconds: Float(window.endTime),
                    features: window.features
                )
            )
        }
        return segments
    }

    private func buildKlunaInput(
        memory: KlunaMemory,
        transcript: String,
        features: [String: Float],
        calibration: CalibrationResult,
        segments: [EnrichedSegment],
        shifts: [SegmentShift],
        linguistic: LinguisticAnalysis,
        previousRounds: [ConversationManager.ConversationRound]?,
        entryNumber: Int,
        userName: String
    ) -> String {
        var input = ""

        if !userName.isEmpty { input += "NAME: \(userName)\n\n" }
        let mem = memory.fullMemory
        if !mem.isEmpty { input += mem + "\n\n" }

        let history = PromptHistory.shared.recentPrompts
        if !history.isEmpty {
            input += "LETZTE FRAGEN:\n"
            for question in history.suffix(3) { input += "- \(question)\n" }
            input += "\n"
        }

        let roundInfo: String = {
            if let rounds = previousRounds, !rounds.isEmpty {
                return "Gespräch Runde \(rounds.count + 1)"
            }
            return "Neuer Eintrag"
        }()
        input += "\(roundInfo) · #\(entryNumber) · \(CoachAPIManager.timeOfDay(Date()))\n\n"
        input += "GESAGT: \"\(String(transcript.prefix(500)))\"\n\n"

        if let rounds = previousRounds, !rounds.isEmpty {
            input += "BISHERIGES GESPRÄCH:\n"
            for prev in rounds {
                input += "Runde \(prev.index + 1): \"\(String(prev.transcript.prefix(150)))\"\n"
                input += "  Kluna: \(String(prev.claudeResponse.prefix(100)))\n"
                input += "  Stimme: Zittern:\(r(value(prev.features, [FeatureKeys.jitter, "Jitter"]))) Klarheit:\(r(value(prev.features, [FeatureKeys.hnr, "HNR"]))) Tempo:\(r(value(prev.features, [FeatureKeys.speechRate, "SpeechRate"])))\n\n"
            }
        }

        input += "STIMME:\n"
        input += "Zittern: \(r(value(features, [FeatureKeys.jitter, "Jitter"]))), Klarheit: \(r(value(features, [FeatureKeys.hnr, "HNR"])))\n"
        input += "Tempo: \(r(value(features, [FeatureKeys.speechRate, "SpeechRate"]))) Silben/s, Pausen: \(r(value(features, [FeatureKeys.meanPauseDuration, FeatureKeys.pauseDuration, "PauseDur"])))s\n"
        input += "Melodie: \(r(value(features, [FeatureKeys.f0RangeST, FeatureKeys.f0Range, "f0RangeST"]))) HT, Tonhöhe: \(r(value(features, [FeatureKeys.f0Mean, "F0Mean"]))) Hz\n"
        input += "Kiefer: \(r(value(features, [FeatureKeys.f1, "F1"]))) Hz, Mundform: \(r(value(features, [FeatureKeys.f2, "F2"]))) Hz\n"
        input += "Dynamik: \(r(value(features, [FeatureKeys.loudnessDynamicRangeOriginal, FeatureKeys.loudnessDynamicRange, "loudnessDynamicRange"]))) dB\n"

        let significant = calibration.zScores
            .filter { abs($0.value) > 1.0 }
            .sorted { abs($0.value) > abs($1.value) }
        if !significant.isEmpty {
            input += "\nABWEICHUNG VOM NORMAL:\n"
            for (featureName, z) in significant.prefix(8) {
                input += "\(humanReadableFeature(featureName)): \(abs(z) > 2.0 ? "DEUTLICH" : "merklich") \(z > 0 ? "höher" : "niedriger") (z=\(String(format: "%.1f", z)))\n"
            }
        } else {
            input += "\nAlle Stimmwerte im normalen Bereich.\n"
        }

        if !shifts.isEmpty {
            input += "\nSTIMMVERLAUF:\n"
            for shift in shifts.prefix(2) {
                input += "Bei \"\(shift.triggerWords.joined(separator: " "))\": \(shift.dimension) \(shift.direction > 0 ? "steigt" : "sinkt")\n"
            }
        }

        if let rounds = previousRounds, let last = rounds.last {
            let dJ = value(features, [FeatureKeys.jitter, "Jitter"]) - value(last.features, [FeatureKeys.jitter, "Jitter"])
            let dH = value(features, [FeatureKeys.hnr, "HNR"]) - value(last.features, [FeatureKeys.hnr, "HNR"])
            let dS = value(features, [FeatureKeys.speechRate, "SpeechRate"]) - value(last.features, [FeatureKeys.speechRate, "SpeechRate"])
            input += "\nVERÄNDERUNG SEIT LETZTER RUNDE:\n"
            if abs(dJ) > 0.005 { input += "Zittern: \(dJ > 0 ? "mehr" : "weniger")\n" }
            if abs(dH) > 0.5 { input += "Klarheit: \(dH > 0 ? "klarer" : "rauer")\n" }
            if abs(dS) > 0.5 { input += "Tempo: \(dS > 0 ? "schneller" : "langsamer")\n" }
            if abs(dJ) < 0.003, abs(dH) < 0.3, abs(dS) < 0.3 {
                input += "Kaum Veränderung zur vorherigen Runde.\n"
            }
        }

        var patterns: [String] = []
        if linguistic.hedging > 0.4 { patterns.append("Relativiert viel (eigentlich, vielleicht)") }
        if linguistic.distancing > 0.4 { patterns.append("Distanziert (man, halt statt ich)") }
        if !patterns.isEmpty { input += "\nSPRACHMUSTER: \(patterns.joined(separator: ". "))\n" }

        if segments.count >= 2 {
            input += "\nSEGMENT-DATEN:\n"
            for segment in segments.prefix(2) {
                let snippet = segment.words.prefix(4).map(\.word).joined(separator: " ")
                input += "[\(Int(segment.startTime))-\(Int(segment.endTime))s] \(snippet)\n"
            }
        }

        return input
    }

    private func p(_ value: Float) -> String {
        "\(Int(value * 100))%"
    }

    private func r(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func value(_ features: [String: Double], _ keys: [String]) -> Double {
        for key in keys {
            if let val = features[key] { return val }
        }
        return 0
    }

    private func value(_ features: [String: Float], _ keys: [String]) -> Double {
        for key in keys {
            if let val = features[key] { return Double(val) }
        }
        return 0
    }

    private func humanReadableFeature(_ feature: String) -> String {
        switch feature {
        case FeatureKeys.jitter: return "Stimmzittern"
        case FeatureKeys.shimmer: return "Stimmflackern"
        case FeatureKeys.hnr: return "Stimmklarheit"
        case FeatureKeys.speechRate: return "Sprechtempo"
        case FeatureKeys.f0RangeST, FeatureKeys.f0Range: return "Stimm-Melodie"
        case FeatureKeys.f0StdDev, FeatureKeys.f0Variability: return "Tonhöhen-Variation"
        case FeatureKeys.meanPauseDuration, FeatureKeys.pauseDuration: return "Pausenlänge"
        case FeatureKeys.loudnessDynamicRangeOriginal, FeatureKeys.loudnessDynamicRange: return "Dynamik"
        case FeatureKeys.f0Mean: return "Tonhöhe"
        case FeatureKeys.articulationRate: return "Artikulation"
        case FeatureKeys.formantDispersion: return "Vokaltrakt"
        case FeatureKeys.f1: return "Kieferöffnung"
        case FeatureKeys.f2: return "Mundform"
        default: return feature
        }
    }

    private func fallbackCoachText(dimensions: EngineVoiceDimensions) -> String {
        var parts: [String] = []
        if dimensions.energy > 0.7 {
            parts.append("Viel Energie in deiner Stimme heute.")
        } else if dimensions.energy < 0.3 {
            parts.append("Deine Stimme klingt heute ruhig und leise.")
        }
        if dimensions.tension > 0.6 {
            parts.append("Da ist eine Anspannung hörbar.")
        }
        if dimensions.fatigue > 0.6 {
            parts.append("Du klingst müde.")
        }
        if dimensions.warmth > 0.6 {
            parts.append("Deine Stimme klingt warm.")
        } else if dimensions.warmth < 0.3 {
            parts.append("Deine Stimme klingt heute kuehler.")
        }
        if dimensions.expressiveness > 0.7 {
            parts.append("Sehr lebendig und ausdrucksstark.")
        } else if dimensions.expressiveness < 0.3 {
            parts.append("Wenig Melodie in der Stimme heute.")
        }
        if parts.isEmpty {
            parts.append("Deine Stimme wurde analysiert.")
        }
        return parts.prefix(2).joined(separator: " ")
    }
}

@MainActor
final class ConversationManager: ObservableObject {
    static let shared = ConversationManager()

    @Published var activeConversation: ActiveConversation?
    @Published var currentRound: Int = 0
    @Published var isInConversation: Bool = false
    @Published var lastConversationSummary: String?
    private var isEndingConversation = false

    struct ActiveConversation {
        let id: UUID
        var rounds: [ConversationRound]
        let startedAt: Date
    }

    struct ConversationRound {
        let index: Int
        let transcript: String
        let features: [String: Float]
        let dimensions: EngineVoiceDimensions
        let segments: [EnrichedSegment]
        let shifts: [SegmentShift]
        let linguistic: LinguisticAnalysis
        let claudeResponse: String
        let claudeQuestion: String?
        let claudeVoiceObservation: String?
        let claudeMood: String?
        let claudeLabel: String?
        let claudeThemes: [String]
        let hasContradiction: Bool
        let contradictionWords: String?
        let contradictionVoice: String?
        let deltaFromPrevious: DimensionDelta?
    }

    struct DimensionDelta {
        let energy: Float
        let tension: Float
        let fatigue: Float
        let warmth: Float
        let expressiveness: Float
        let tempo: Float

        var summary: String {
            var changes: [String] = []
            if abs(energy) > 0.08 { changes.append("Energie \(energy > 0 ? "↑" : "↓")") }
            if abs(tension) > 0.08 { changes.append("Anspannung \(tension > 0 ? "↑" : "↓")") }
            if abs(fatigue) > 0.08 { changes.append("Muedigkeit \(fatigue > 0 ? "↑" : "↓")") }
            if abs(warmth) > 0.08 { changes.append("Wärme \(warmth > 0 ? "↑" : "↓")") }
            if abs(expressiveness) > 0.08 { changes.append("Lebendigkeit \(expressiveness > 0 ? "↑" : "↓")") }
            if abs(tempo) > 0.08 { changes.append("Tempo \(tempo > 0 ? "↑" : "↓")") }
            return changes.isEmpty ? "Kaum Veraenderung" : changes.joined(separator: ", ")
        }
    }

    private init() {}

    func startConversation() {
        activeConversation = ActiveConversation(id: UUID(), rounds: [], startedAt: Date())
        currentRound = 0
        isInConversation = true
        lastConversationSummary = nil
        KlunaAnalytics.shared.track("conversation_started")
    }

    func addRound(_ round: ConversationRound) {
        guard var conversation = activeConversation else { return }
        conversation.rounds.append(round)
        activeConversation = conversation
        currentRound = round.index + 1
    }

    func calculateDelta(current: EngineVoiceDimensions) -> DimensionDelta? {
        guard let previous = activeConversation?.rounds.last?.dimensions else { return nil }
        return DimensionDelta(
            energy: current.energy - previous.energy,
            tension: current.tension - previous.tension,
            fatigue: current.fatigue - previous.fatigue,
            warmth: current.warmth - previous.warmth,
            expressiveness: current.expressiveness - previous.expressiveness,
            tempo: current.tempo - previous.tempo
        )
    }

    func endConversation(generateFollowUpQuestion: Bool = true, reason: String = "manual_finish") {
        guard !isEndingConversation else { return }
        guard let convo = activeConversation else { return }
        isEndingConversation = true
        isInConversation = false
        print("🎙️ Ending conversation (\(reason)) with \(convo.rounds.count) rounds")
        KlunaAnalytics.shared.track("conversation_ended", value: "\(convo.rounds.count)")
        let summary = buildConversationSummary(convo)
        lastConversationSummary = generateConversationSummaryForDisplay(convo)
        persistConversation(convo, summary: summary)
        Task {
            await updateMemoryFromConversation(convo, summary: summary)
        }
        Task {
            await SupabaseManager.shared.donateConversation(convo)
        }
        OpenThread.shared.detectThread(from: convo)
        if let thread = OpenThread.shared.currentThread {
            KlunaNotificationManager.shared.scheduleThreadReminder(thread)
        }
        let latestType = VoiceTypeGenerator.generate(
            dims: VoiceDimensions(
                energy: CGFloat(convo.rounds.last?.dimensions.energy ?? 0.5),
                tension: CGFloat(convo.rounds.last?.dimensions.tension ?? 0.5),
                fatigue: CGFloat(convo.rounds.last?.dimensions.fatigue ?? 0.5),
                warmth: CGFloat(convo.rounds.last?.dimensions.warmth ?? 0.5),
                expressiveness: CGFloat(convo.rounds.last?.dimensions.expressiveness ?? 0.5),
                tempo: CGFloat(convo.rounds.last?.dimensions.tempo ?? 0.5)
            )
        )
        VoiceTypeGenerator.saveLatest(latestType)
        if generateFollowUpQuestion {
            Task {
                await QuestionGenerator.shared.generateNewQuestion()
                let question = QuestionGenerator.shared.currentQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
                if !question.isEmpty {
                    KlunaNotificationManager.shared.scheduleEveningQuestion(question)
                }
            }
        }
        activeConversation = nil
        currentRound = 0
        isEndingConversation = false
    }

    func autoEndConversationIfNeeded(reason: String = "app_backgrounded") {
        guard isInConversation else { return }
        endConversation(generateFollowUpQuestion: false, reason: reason)
    }

    func buildConversationSummary(_ convo: ActiveConversation) -> String {
        var summary = "Gespraech mit \(convo.rounds.count) Runden:\n"
        for round in convo.rounds {
            let snippet = String(round.transcript.prefix(100))
            let dims = round.dimensions
            summary += "Runde \(round.index + 1): \"\(snippet)\" "
            summary += "(E:\(Int(dims.energy * 100))% An:\(Int(dims.tension * 100))%)"
            if let delta = round.deltaFromPrevious {
                summary += " Veraenderung: \(delta.summary)"
            }
            summary += "\n"
        }

        if convo.rounds.count >= 2, let first = convo.rounds.first?.dimensions, let last = convo.rounds.last?.dimensions {
            let totalDelta = DimensionDelta(
                energy: last.energy - first.energy,
                tension: last.tension - first.tension,
                fatigue: last.fatigue - first.fatigue,
                warmth: last.warmth - first.warmth,
                expressiveness: last.expressiveness - first.expressiveness,
                tempo: last.tempo - first.tempo
            )
            summary += "Gesamtveraenderung Runde 1 -> \(convo.rounds.count): \(totalDelta.summary)\n"
        }
        return summary
    }

    func generateConversationSummaryForDisplay(_ convo: ActiveConversation) -> String? {
        guard convo.rounds.count >= 2,
              let first = convo.rounds.first?.dimensions,
              let last = convo.rounds.last?.dimensions else { return nil }
        var summary = ""
        if last.tension < first.tension - 0.1 { summary += "Deine Anspannung ist im Gespraech gesunken. " }
        if last.warmth > first.warmth + 0.1 { summary += "Deine Stimme wurde waermer. " }
        if last.energy < first.energy - 0.1 { summary += "Du bist ruhiger geworden. " }
        if summary.isEmpty { summary = "\(convo.rounds.count) Runden. Deine Stimme hat sich bewegt." }
        return summary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractAllThemes(_ convo: ActiveConversation) -> [String] {
        let themes = convo.rounds.flatMap(\.claudeThemes).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        return Array(Set(themes.filter { !$0.isEmpty })).sorted()
    }

    private func updateMemoryFromConversation(_ convo: ActiveConversation, summary: String) async {
        guard let final = convo.rounds.last?.dimensions else { return }
        await KlunaMemory.shared.updateAfterConversation(
            conversationSummary: summary,
            roundCount: convo.rounds.count,
            finalMood: final,
            themes: extractAllThemes(convo)
        )
    }

    private func persistConversation(_ convo: ActiveConversation, summary: String) {
        let context = PersistenceController.shared.container.viewContext
        context.performAndWait {
            let entity = CDConversation(context: context)
            entity.id = convo.id
            entity.createdAt = convo.startedAt
            entity.roundCount = Int16(convo.rounds.count)
            entity.isComplete = true
            entity.memorySummary = summary
            try? context.save()
        }
    }
}
