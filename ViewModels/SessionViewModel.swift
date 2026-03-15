import SwiftUI
import Combine
import AVFoundation

/// Orchestrates the complete Kluna AI pipeline:
/// Select Pitch → Record → Extract → Score → Feedback → Memory → Gamification
@MainActor
final class SessionViewModel: ObservableObject {
    private enum MicrophonePermission {
        case granted
        case denied
        case undetermined
    }
    
    // MARK: - Published State
    
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0
    @Published var selectedPitchType: PitchType = PitchType.defaults[0]
    @Published var pitchTypes: [PitchType] = PitchType.defaults
    @Published var liveTranscription: String = ""
    @Published var transcription: String = ""
    @Published var transcriptionSource: TranscriptionManager.TranscriptionSource = .failed
    @Published var previousScores: DimensionScores?
    
    // Post-session
    @Published var currentScores: DimensionScores?
    @Published var quickFeedback: String = ""
    @Published var deepCoaching: String?
    @Published var heatmapData: HeatmapData?
    @Published var showScoreScreen = false
    @Published var isProcessing = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    @Published var isNewHighScore = false
    @Published var isLoadingDeepCoaching = false
    @Published var recordingURL: URL?
    @Published var isPlayingBack = false
    @Published var playbackProgress: Double = 0
    @Published var playbackCurrentTime: TimeInterval = 0
    @Published var attemptCount: Int = 1

    @Published var isDrill: Bool = false
    @Published var preDrillScore: Double?
    @Published var preDrillDimension: PerformanceDimension?
    @Published var timestampedComments: [TimestampedComment] = []
    @Published var activeProgressiveChallenge: ProgressiveChallenge?
    @Published var challengeResult: ChallengeResult?
    @Published var showLevelUp: Bool = false
    @Published var baselineProgress: BaselineProgress?
    @Published var pendingBaselineToast: BaselineToast?
    @Published var showBaselineEstablishedCelebration = false
    @Published var activeGoal: DimensionGoal?
    @Published var goalProgress: Double?
    @Published var goalCompletion: GoalCompletionResult?
    @Published var activeBiomarkerChallenge: BiomarkerChallenge?
    @Published var biomarkerResult: BiomarkerResult?
    @Published var profileClassification: ProfileClassification?
    @Published var melodicAnalysis: MelodicContourAnalysis?
    @Published var spectralAnalysis: SpectralBandResult?
    @Published var currentPrediction: ScorePrediction?
    @Published var currentPredictionError: PredictionError?
    @Published var currentConsistency: ConsistencyResult?
    @Published var latestMilestones: [Milestone] = []
    @Published var vocalState: VocalStateResult?
    @Published var vocalEfficiency: VocalEfficiencyResult?
    @Published var circadianProfile: CircadianProfile?
    @Published var detectedPatterns: [DetectedPattern] = []
    @Published var suggestedExercise: TrainingExercise?
    @Published var voiceDNAProfile: VoiceDNAProfile?
    @Published var voiceDNAInsight: VoiceInsight?
    @Published var isVoiceDNADiscoveryComplete = false
    @Published var voiceDNADiscoverySessionCount = 0
    @Published var selectedVoiceDNAQuadrant: String?

    // MARK: - Dependencies
    
    private let audioRecorder = AudioRecorder()
    private let openSMILE = OpenSMILEExtractor()
    private let baselineEngine = BaselineEngine()
    private let dimensionScorer: DimensionScorer
    private let memoryManager: MemoryManager
    private let streakManager: StreakManager
    private let challengeManager: ChallengeManager
    private let subscriptionManager: SubscriptionManager
    private let consistencyTracker = ConsistencyTracker()
    private let milestoneChecker = MilestoneChecker()
    
    private var cancellables = Set<AnyCancellable>()
    private var currentSessionId: UUID?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    
    init() {
        self.dimensionScorer = DimensionScorer(baselineEngine: baselineEngine)
        self.memoryManager = MemoryManager(context: PersistenceController.shared.container.viewContext)
        self.streakManager = StreakManager(memoryManager: memoryManager)
        self.challengeManager = ChallengeManager(memoryManager: memoryManager)
        self.subscriptionManager = .shared
        self.pitchTypes = sortedPitchTypes(for: memoryManager.loadUser().goal)
        if let first = pitchTypes.first {
            self.selectedPitchType = first
        }
        self.baselineProgress = BaselineProgress(totalSessions: memoryManager.totalSessionCount())
        self.activeGoal = DimensionGoalManager.shared.activeGoal()
        self.currentPrediction = ScorePredictionEngine.predict(from: memoryManager.recentOverallScores(limit: 10, oldestFirst: true))
        self.currentConsistency = consistencyTracker.analyze()
        self.voiceDNADiscoverySessionCount = DiscoveryStateManager.shared.discoverySessionCount
        self.isVoiceDNADiscoveryComplete = DiscoveryStateManager.shared.isDiscoveryComplete
        self.selectedVoiceDNAQuadrant = DiscoveryStateManager.shared.selectedQuadrant
        
        audioRecorder.$audioLevel.assign(to: &$audioLevel)
        audioRecorder.$recordingDuration.assign(to: &$recordingDuration)
    }
    
    // MARK: - Recording
    
    func startRecording() {
        guard !isRecording else { return }
        stopPlayback()
        currentPrediction = ScorePredictionEngine.predict(from: memoryManager.recentOverallScores(limit: 10, oldestFirst: true))
        let micPermission = microphonePermissionStatus()
        switch micPermission {
        case .granted:
            break
        case .denied:
            presentError("Mikrofon-Zugriff verweigert. Bitte in den iPhone-Einstellungen aktivieren.")
            return
        case .undetermined:
            PermissionManager.requestMicrophonePermission { [weak self] granted in
                guard let self else { return }
                Task { @MainActor in
                    if granted {
                        self.startRecording()
                    } else {
                        self.presentError("Mikrofon-Zugriff verweigert. Bitte in den iPhone-Einstellungen aktivieren.")
                    }
                }
            }
            return
        @unknown default:
            presentError("Mikrofon nicht verfügbar.")
            return
        }

        let hasInput = !(AVAudioSession.sharedInstance().availableInputs ?? []).isEmpty
        guard hasInput else {
            presentError("Kein Mikrofon verfügbar.")
            return
        }

        let started = audioRecorder.startRecording(
            onBuffer: { _ in },
            onForcedStop: { [weak self] data in
                guard let self else { return }
                Task { @MainActor in
                    if !self.isRecording { return }
                    self.isRecording = false
                    self.isProcessing = true
                    await self.processSession(audioData: data)
                }
            }
        )
        if started {
            isRecording = true
        } else {
            presentError("Aufnahme konnte nicht gestartet werden.")
        }
    }
    
    func stopRecording() {
        isRecording = false
        isProcessing = true
        if let currentScores {
            previousScores = currentScores
        }
        
        let audioData = audioRecorder.stopRecording()
        Task { await processSession(audioData: audioData) }
    }

    func resetForNewSession() {
        stopPlayback()
        if let currentScores {
            previousScores = currentScores
            attemptCount += 1
        }
        currentScores = nil
        quickFeedback = ""
        deepCoaching = nil
        voiceDNAProfile = nil
        voiceDNAInsight = nil
        heatmapData = nil
        timestampedComments = []
        showScoreScreen = false
        isProcessing = false
        showErrorAlert = false
        errorMessage = ""
        transcription = ""
        liveTranscription = ""
        transcriptionSource = .failed
        isNewHighScore = false
        isLoadingDeepCoaching = false
        challengeResult = nil
        showLevelUp = false
        pendingBaselineToast = nil
        showBaselineEstablishedCelebration = false
        goalCompletion = nil
        biomarkerResult = nil
        goalProgress = nil
        profileClassification = nil
        melodicAnalysis = nil
        spectralAnalysis = nil
        currentPredictionError = nil
        latestMilestones = []
        vocalState = nil
        vocalEfficiency = nil
        circadianProfile = nil
        detectedPatterns = []
        suggestedExercise = nil
        voiceDNADiscoverySessionCount = DiscoveryStateManager.shared.discoverySessionCount
        isVoiceDNADiscoveryComplete = DiscoveryStateManager.shared.isDiscoveryComplete
        selectedVoiceDNAQuadrant = DiscoveryStateManager.shared.selectedQuadrant
        if !isDrill {
            isDrill = false
            preDrillScore = nil
            preDrillDimension = nil
        }
    }

    func startDrill(weakDimension: PerformanceDimension, currentWeakScore: Double) {
        isDrill = true
        preDrillScore = currentWeakScore
        preDrillDimension = weakDimension
    }

    func startBiomarkerChallenge(for dimension: PerformanceDimension, language: String) {
        let challenge = BiomarkerChallengeProvider.shared.challengeForWeakness(dimension)
        activeBiomarkerChallenge = challenge
        biomarkerResult = nil
        selectedPitchType = PitchType(
            id: UUID(),
            name: challenge.title(language: language),
            description: "Biomarker Challenge",
            timeLimit: challenge.timeLimit,
            challengePrompt: challenge.instruction(language: language),
            isCustom: true,
            isDefault: false
        )
    }

    func selectVoiceDNAQuadrant(_ quadrant: String) {
        DiscoveryStateManager.shared.selectedQuadrant = quadrant
        selectedVoiceDNAQuadrant = quadrant
    }
    
    // MARK: - Pipeline
    
    private func processSession(audioData: Data?) async {
        let context = PersistenceController.shared.container.viewContext

        guard recordingDuration >= 3 else {
            isProcessing = false
            presentError("Sprich mindestens 3 Sekunden.")
            return
        }

        guard let audioData else {
            isProcessing = false
            presentError("Analyse fehlgeschlagen, bitte nochmal versuchen.")
            return
        }
        let sessionId = UUID()
        let duration = recordingDuration
        let user = loadUser()
        let savedRecordingURL = AudioRecorder.saveRecordingForPlayback(pcmData: audioData, sessionId: sessionId)
        AudioRecorder.cleanupOldRecordings(keepLast: 50)
        recordingURL = savedRecordingURL
        async let transcriptionTask: TranscriptionManager.TranscriptionResult = {
            guard let savedRecordingURL else {
                return TranscriptionManager.TranscriptionResult(
                    text: "",
                    source: .failed,
                    segments: nil,
                    language: user.language,
                    confidence: 0
                )
            }
            return await TranscriptionManager.shared.transcribe(
                audioURL: savedRecordingURL,
                language: user.language
            )
        }()
        FeatureLogger.shared.beginSession(
            practiceType: selectedPitchType.name,
            duration: duration,
            sessionId: sessionId.uuidString
        )
        #if DEBUG
        let pcm16Duration = Double(audioData.count / 2) / Config.audioSampleRate
        let float32Duration = Double(audioData.count / 4) / Config.audioSampleRate
        print("🎙️ Sending to bridge: \(audioData.count) bytes, sampleRate: \(Config.audioSampleRate)")
        print("🎙️ Expected format: PCM16 = \(audioData.count / 2) samples, Float32 = \(audioData.count / 4) samples")
        print("🎙️ Duration: PCM16 = \(String(format: "%.2f", pcm16Duration))s, Float32 = \(String(format: "%.2f", float32Duration))s")
        #endif

        // 1) Feature extraction
        let extractionStart = CFAbsoluteTimeGetCurrent()
        let extracted: VoiceFeatures?
        #if DEBUG
        if DebugConfig.useMockScores {
            extracted = VoiceFeatures(
                f0Mean: 180, f0Variability: 15, f0Range: 60, jitter: 0.01, shimmer: 0.03,
                speechRate: 2.5, energy: 0.4, hnr: 15, f1: 500, f2: 1500, f3: 2400, f4: 3200,
                pauseDuration: 0.3, pauseDistribution: 0.4
            )
        } else {
            extracted = await Task.detached(priority: .userInitiated) {
                OpenSMILEExtractor().extractFeatures(from: audioData, sampleRate: Config.audioSampleRate)
            }.value
        }
        #else
        extracted = await Task.detached(priority: .userInitiated) {
            OpenSMILEExtractor().extractFeatures(from: audioData, sampleRate: Config.audioSampleRate)
        }.value
        #endif

        let extractionTime = CFAbsoluteTimeGetCurrent() - extractionStart
        logTiming("🔬 Feature extraction", seconds: extractionTime)

        guard let features = extracted else {
            isProcessing = false
            presentError("Analyse fehlgeschlagen, bitte nochmal versuchen.")
            return
        }

        // 2) Score calculation

        let scoreStart = CFAbsoluteTimeGetCurrent()
        var scores: DimensionScores
        var voiceDNA: VoiceDNAProfile?
        var generatedInsight: VoiceInsight?
        var discoveryComplete = DiscoveryStateManager.shared.isDiscoveryComplete
        var discoveryCount = DiscoveryStateManager.shared.discoverySessionCount
        var rawFeatureDict = FeatureKeyMapper.normalize(features.asDictionary)
        if rawFeatureDict[FeatureKeys.loudnessRMSOriginal] == nil {
            rawFeatureDict[FeatureKeys.loudnessRMSOriginal] = rawFeatureDict[FeatureKeys.loudnessRMS] ?? rawFeatureDict[FeatureKeys.loudness] ?? 0.004
        }
        if rawFeatureDict[FeatureKeys.loudnessDynamicRangeOriginal] == nil {
            rawFeatureDict[FeatureKeys.loudnessDynamicRangeOriginal] = rawFeatureDict[FeatureKeys.loudnessDynamicRange] ?? 17.0
        }
        if rawFeatureDict[FeatureKeys.gainFactor] == nil {
            let loudnessNorm = rawFeatureDict[FeatureKeys.loudnessRMS] ?? rawFeatureDict[FeatureKeys.loudness] ?? 0.05
            let loudnessOriginal = rawFeatureDict[FeatureKeys.loudnessRMSOriginal] ?? 0.004
            rawFeatureDict[FeatureKeys.gainFactor] = loudnessOriginal > 0.0001 ? (loudnessNorm / loudnessOriginal) : 15.0
        }
        let profileClassification = SpeakerProfileClassifier.classify(features: rawFeatureDict)
        let pcmSamples = SpectralBandAnalyzer.audioDataToFloatSamples(audioData)
        let spectralInputSamples = pcmSamples
        let spectralAnalyzer = SpectralBandAnalyzer()
        let segmentSpectralResults = spectralSegments(
            samples: spectralInputSamples,
            sampleRate: Float(Config.audioSampleRate),
            analyzer: spectralAnalyzer
        )
        let spectralResult: SpectralBandResult
        if !segmentSpectralResults.isEmpty {
            spectralResult = SpectralBandResult.mean(of: segmentSpectralResults)
            print("🔬 Spectral: Using SEGMENT MEAN (\(segmentSpectralResults.count) segments, source=ORIGINAL)")
        } else {
            spectralResult = spectralAnalyzer.analyze(
                samples: spectralInputSamples,
                sampleRate: Float(Config.audioSampleRate)
            )
            print("🔬 Spectral: Using FULL-SESSION FFT (fallback, source=ORIGINAL)")
        }
        logRawFeatures(rawFeatureDict, sessionType: selectedPitchType.name)
        let zScores = baselineEngine.calculateAllZScores(for: rawFeatureDict, voiceType: user.voiceType, context: context)
        let pillarScoresForDNA = PillarScoreEngine.calculatePillarScores(features: rawFeatureDict, spectral: spectralResult)
        voiceDNA = pillarScoresForDNA.voiceDNA
        let baselineEntries = baselineEngine.baselineDebug(values: rawFeatureDict, voiceType: user.voiceType, context: context)
        if let voiceDNA {
            let discovery = DiscoveryStateManager.shared
            let nextSession = discovery.discoverySessionCount + 1
            generatedInsight = InsightEngine.generateInsight(
                dna: voiceDNA,
                sessionCount: nextSession,
                previousInsights: discovery.previousInsights,
                rawFeatures: rawFeatureDict
            )
            discovery.recordSession(dna: voiceDNA, shownQuadrant: generatedInsight?.quadrant)
            discoveryCount = discovery.discoverySessionCount
            discoveryComplete = discovery.isDiscoveryComplete
            print("🧬 === DISCOVERY ===")
            print("🧬 Session: \(discoveryCount)/7")
            print("🧬 Complete: \(discoveryComplete)")
            if let generatedInsight {
                print("🧬 Insight: \(generatedInsight.title)")
                print("🧬 Quadrant: \(generatedInsight.quadrant)")
                print("🧬 Score: \(Int(generatedInsight.value))")
            }
            print("🧬 =================")
        }
        #if DEBUG
        let debugFeatureOrder = [
            FeatureKeys.loudnessRMSOriginal,
            FeatureKeys.loudnessRMS,
            FeatureKeys.loudnessDynamicRangeOriginal,
            FeatureKeys.f0Mean,
            FeatureKeys.f0Range,
            FeatureKeys.f0StdDev,
            FeatureKeys.jitter,
            FeatureKeys.shimmer,
            FeatureKeys.hnr,
            FeatureKeys.gainFactor,
            FeatureKeys.speechRate,
            FeatureKeys.pauseRate,
            FeatureKeys.meanPauseDuration,
        ]
        print("🔬 === BASELINE DEBUG ===")
        for key in debugFeatureOrder {
            if let entry = baselineEntries.first(where: { $0.feature == key }) {
                print("🔬 \(key): value=\(String(format: "%.4f", entry.value)) mean=\(String(format: "%.4f", entry.mean)) std=\(String(format: "%.4f", entry.stdDev)) z=\(String(format: "%.2f", entry.zScore)) source=\(entry.source)")
            }
        }
        print("🔬 =======================")
        #endif
        #if DEBUG
        if DebugConfig.useMockScores {
            scores = DebugConfig.mockScores
        } else {
            scores = DimensionScores(confidence: 0, energy: 0, tempo: 0, clarity: 0, stability: 0, charisma: 0)
        }
        #else
        scores = DimensionScores(confidence: 0, energy: 0, tempo: 0, clarity: 0, stability: 0, charisma: 0)
        #endif

        let f0Contour = ContourExtractor.extractF0Contour(from: audioData, sampleRate: Config.audioSampleRate)
        let loudnessContour = ContourExtractor.extractLoudnessContour(from: audioData, sampleRate: Config.audioSampleRate)
        let melodicAnalysis = MelodicContourAnalyzer.analyze(
            f0Contour: f0Contour,
            loudnessContour: loudnessContour,
            frameDuration: 0.010
        )
        let vocalStateResult = VocalStateDetector().detect(
            spectral: spectralResult,
            bridgeFeatures: rawFeatureDict,
            zScores: zScores,
            melodic: melodicAnalysis
        )
        let efficiencyResult = VocalEfficiencyCalculator.calculate(
            spectral: spectralResult,
            jitter: rawFeatureDict[FeatureKeys.jitter] ?? rawFeatureDict["Jitter"] ?? 0.022,
            shimmer: rawFeatureDict[FeatureKeys.shimmer] ?? rawFeatureDict["Shimmer"] ?? 0.17,
            loudnessRMS: rawFeatureDict[FeatureKeys.loudnessRMS] ?? rawFeatureDict[FeatureKeys.loudness] ?? 0.05,
            loudnessOriginal: rawFeatureDict["loudnessRMSOriginal"] ?? 0.003
        )
        #if DEBUG
        if !DebugConfig.useMockScores {
            scores = dimensionScorer.score(
                rawFeatures: rawFeatureDict,
                zScores: zScores,
                segmentFeatures: nil,
                spectral: spectralResult,
                vocalState: vocalStateResult,
                efficiency: efficiencyResult
            )
        }
        #else
        scores = dimensionScorer.score(
            rawFeatures: rawFeatureDict,
            zScores: zScores,
            segmentFeatures: nil,
            spectral: spectralResult,
            vocalState: vocalStateResult,
            efficiency: efficiencyResult
        )
        #endif
        let adjustedCharisma = scores.charisma * 0.65 + melodicAnalysis.intentionalityScore * 0.35
        scores = scores.withAdjustedCharisma(adjustedCharisma)
        let predictionError = currentPrediction?.predictionError(actualScore: scores.overall)
        let allLogs = FeatureLogger.shared.loadAllLogs()
        let circadian = CircadianVoiceAnalyzer.analyze(logs: allLogs)
        let patterns = PatternDetector.detect(logs: allLogs)
        let nextExercise = AdaptiveTrainingEngine.selectExercise(
            vocalState: vocalStateResult,
            scores: scores,
            efficiency: efficiencyResult,
            consistency: currentConsistency,
            sessionCount: memoryManager.totalSessionCount()
        )
        let transcriptionResult = await transcriptionTask
        let finalTranscription = transcriptionResult.text.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📝 Transcription source: \(transcriptionResult.source.rawValue)")
        print("📝 Transcription length: \(finalTranscription.count) characters")
        let claudeTranscription = finalTranscription.isEmpty
            ? "[Transcription unavailable – feedback based on acoustic analysis only]"
            : finalTranscription

        let contextualPrompt = ContextualCoachingEngine.buildPrompt(
            scores: scores,
            bridgeFeatures: rawFeatureDict,
            vocalState: vocalStateResult,
            efficiency: efficiencyResult,
            spectral: spectralResult,
            profile: profileClassification.profile,
            prediction: currentPrediction,
            circadian: circadian,
            patterns: patterns,
            consistency: currentConsistency,
            sessionCount: memoryManager.totalSessionCount(),
            recentScores: memoryManager.recentOverallScores(limit: 10, oldestFirst: true),
            transcription: finalTranscription
        )

        let scoreTime = CFAbsoluteTimeGetCurrent() - scoreStart
        logTiming("📊 Score calculation", seconds: scoreTime)

        #if DEBUG
        print("🔬 === RAW FEATURES ===")
        for (key, value) in rawFeatureDict.sorted(by: { $0.key < $1.key }) {
            print("🔬 \(key): \(String(format: "%.4f", value))")
        }
        print("🔬 === Z-SCORES ===")
        for (key, value) in zScores.sorted(by: { $0.key < $1.key }) {
            print("🔬 \(key): \(String(format: "%.4f", value))")
        }
        print("🔬 === SCORES ===")
        print("🔬 Overall: \(scores.overall)")
        print("🔬 Confidence: \(scores.confidence)")
        print("🔬 Energy: \(scores.energy)")
        print("🔬 Tempo: \(scores.tempo)")
        print("🔬 Gelassenheit: \(scores.stability)")
        print("🔬 Charisma: \(scores.charisma)")
        print("🔬 === SPECTRAL ANALYSIS ===")
        print("🔬 Warmth: \(String(format: "%.1f", spectralResult.warmthScore))/100")
        print("🔬 Body: \(String(format: "%.1f", spectralResult.bodyScore))/100")
        print("🔬 Presence: \(String(format: "%.1f", spectralResult.presenceScore))/100")
        print("🔬 Air: \(String(format: "%.1f", spectralResult.airScore))/100")
        print("🔬 Balance: \(String(format: "%.1f", spectralResult.spectralBalance))/100")
        print("🔬 Timbre: \(String(format: "%.1f", spectralResult.overallTimbreScore))/100")
        #endif

        FeatureLogger.shared.setBridgeFeatures(rawFeatureDict)
        FeatureLogger.shared.setZScores(zScores)
        FeatureLogger.shared.setSpectralFeatures(
            warmth: Double(spectralResult.warmthScore),
            body: Double(spectralResult.bodyScore),
            presence: Double(spectralResult.presenceScore),
            air: Double(spectralResult.airScore),
            timbre: Double(spectralResult.overallTimbreScore),
            warmthToPresence: Double(spectralResult.warmthToPresenceRatio),
            bodyToTotal: Double(spectralResult.bodyToTotalRatio),
            presenceToTotal: Double(spectralResult.presenceToTotalRatio),
            balance: Double(spectralResult.spectralBalance)
        )
        FeatureLogger.shared.setMelodicFeatures(
            hatPatterns: melodicAnalysis.hatPatternCount,
            hatScore: melodicAnalysis.hatPatternScore,
            emphasisCorr: melodicAnalysis.emphasisCorrelation,
            emphasisReg: melodicAnalysis.emphasisRegularity,
            downstep: melodicAnalysis.downstepPresent,
            downstepStrength: melodicAnalysis.downstepStrength,
            finalLowering: melodicAnalysis.finalLoweringPresent,
            finalLoweringStrength: melodicAnalysis.finalLoweringStrength,
            intentionality: melodicAnalysis.intentionalityScore
        )
        FeatureLogger.shared.setScores(
            overall: scores.overall,
            confidence: scores.confidence,
            energy: scores.energy,
            tempo: scores.tempo,
            clarity: scores.clarity,
            stability: scores.stability,
            charisma: scores.charisma
        )
        if let voiceDNA {
            FeatureLogger.shared.setVoiceDNA(
                authority: Double(voiceDNA.authority),
                charisma: Double(voiceDNA.charisma),
                warmth: Double(voiceDNA.warmth),
                composure: Double(voiceDNA.composure)
            )
        }
        FeatureLogger.shared.setPrediction(
            expected: currentPrediction?.expectedScore,
            delta: predictionError?.delta,
            trend: currentPrediction?.trend.rawValue
        )
        FeatureLogger.shared.setVocalState(
            state: vocalStateResult.primaryState.rawValue,
            confidence: vocalStateResult.confidence
        )
        FeatureLogger.shared.setEfficiency(
            score: efficiencyResult.efficiencyScore,
            category: efficiencyResult.category.rawValue,
            presencePerJitter: efficiencyResult.presencePerJitter
        )
        FeatureLogger.shared.setExercise(
            id: nextExercise.id,
            successRate: nil
        )
        FeatureLogger.shared.setTranscription(
            text: finalTranscription,
            source: transcriptionResult.source.rawValue,
            confidence: transcriptionResult.confidence,
            segments: transcriptionResult.segments
        )

        // 3) Heatmap
        let segmentDuration = duration / Double(Config.heatmapSegments)
        var segments: [VoiceFeatures] = []
        for i in 0..<Config.heatmapSegments {
            let start = Double(i) * segmentDuration
            let end = start + segmentDuration
            if let segFeatures = openSMILE.extractFeatures(from: audioData, sampleRate: Config.audioSampleRate,
                                                            startTime: start, endTime: end) {
                segments.append(segFeatures)
            }
        }
        let heatmap = dimensionScorer.heatmap(segments: segments, voiceType: user.voiceType, context: context)

        // 4) Baseline
        baselineEngine.updateBaseline(with: features, context: context)

        // 5) Load profile + history
        var mutableUser = user
        let recentSessions = memoryManager.recentSessions()
        let heatmapSummary = formatHeatmapSummary(heatmap)

        var feedback = "Coach nicht verfügbar."
        let claudeStart = CFAbsoluteTimeGetCurrent()
        if Config.claudeAPIKey.isEmpty {
            feedback = "Coach nicht verfügbar."
        } else {
            do {
                let deltas: [String: Float] = Dictionary(
                    uniqueKeysWithValues: baselineEntries.map { ($0.feature, Float($0.zScore)) }
                )
                let extracted = ExtractedFeatures(
                    speechRate: rawFeatureDict[FeatureKeys.speechRate] ?? 0,
                    pauseDur: rawFeatureDict[FeatureKeys.meanPauseDuration] ?? rawFeatureDict[FeatureKeys.pauseDuration] ?? 0,
                    jitter: rawFeatureDict[FeatureKeys.jitter] ?? 0,
                    hnr: rawFeatureDict[FeatureKeys.hnr] ?? 0,
                    f0Mean: rawFeatureDict[FeatureKeys.f0Mean] ?? 0,
                    dynamicRange: rawFeatureDict[FeatureKeys.loudnessDynamicRangeOriginal] ?? rawFeatureDict[FeatureKeys.loudnessDynamicRange] ?? 0
                )
                let discoveryState = DiscoveryState(
                    sessionCount: discoveryCount,
                    isComplete: discoveryComplete,
                    focus: generatedInsight?.quadrant ?? (discoveryComplete ? (selectedVoiceDNAQuadrant ?? "training") : "discovery")
                )
                let payload = CoachAPIManager.buildSessionPayload(
                    transcript: claudeTranscription,
                    dna: voiceDNA ?? VoiceDNAProfile(authority: 50, charisma: 50, warmth: 50, composure: 50),
                    pillars: pillarScoresForDNA,
                    features: extracted,
                    baselineDeltas: deltas,
                    discoveryState: discoveryState,
                    trainingQuadrant: selectedVoiceDNAQuadrant,
                    totalSessions: memoryManager.totalSessionCount() + 1
                )
                feedback = try await CoachAPIManager.requestCoaching(payload: payload, apiKey: Config.claudeAPIKey)
                if feedback.isEmpty {
                    feedback = "Coach nicht verfügbar."
                }
            } catch {
                if let claudeError = error as? CoachAPIError {
                    switch claudeError {
                    case .missingAPIKey:
                        feedback = "Coach nicht verfügbar."
                    case .rateLimited(let _):
                        feedback = "Coach ist aktuell ausgelastet (Rate Limit). Bitte später erneut versuchen."
                    default:
                        feedback = "Konnte Coach nicht erreichen. Versuche es später."
                    }
                } else if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
                    feedback = "Offline-Modus: Scores verfügbar, Coach-Feedback benötigt Internet."
                } else {
                    feedback = "Konnte Coach nicht erreichen. Versuche es später."
                }
            }
        }
        let claudeTime = CFAbsoluteTimeGetCurrent() - claudeStart
        logTiming("🤖 Claude response", seconds: claudeTime)

        // 6) Persist session + gamification
        let previousBest = memoryManager.allTimeBestScore()
        currentSessionId = sessionId
        let session = CompletedSession(
            id: sessionId,
            date: Date(),
            pitchType: selectedPitchType.name,
            duration: duration,
            scores: scores,
            featureZScores: features.asDictionary,
            transcription: finalTranscription,
            quickFeedback: feedback,
            deepCoaching: nil,
            heatmapData: heatmap,
            profileName: profileClassification.profile.rawValue,
            profileRank: profileClassification.profile.rank,
            profileConfidence: profileClassification.confidence,
            voiceDNA: voiceDNA
        )
        memoryManager.saveSession(session)

        consistencyTracker.recordSession(
            overallScore: scores.overall,
            dimensionScores: [
                "confidence": scores.confidence,
                "energy": scores.energy,
                "tempo": scores.tempo,
                "stability": scores.stability,
                "charisma": scores.charisma,
            ]
        )
        let consistency = consistencyTracker.analyze()
        let newMilestones = milestoneChecker.checkMilestones(consistency: consistency, latestScore: scores.overall)
        FeatureLogger.shared.setConsistency(
            level: consistency.masteryLevel.title,
            score: consistency.overallConsistency,
            streak: consistency.currentStreak
        )
        FeatureLogger.shared.setProfile(
            name: profileClassification.profile.rawValue,
            rank: profileClassification.profile.rank,
            confidence: profileClassification.confidence,
            secondary: profileClassification.secondaryProfile?.rawValue
        )
        print("🏆 === CONSISTENCY ===")
        print("🏆 Overall: \(String(format: "%.0f", consistency.overallConsistency))/100")
        print("🏆 Level: \(consistency.masteryLevel.icon) \(consistency.masteryLevel.title)")
        print("🏆 Streak: \(consistency.currentStreak) Tage (Rekord: \(consistency.longestStreak))")
        print("🏆 Sessions: \(consistency.totalSessions)")
        if let best = consistency.mostConsistent { print("🏆 Stärkste Dimension: \(best)") }
        if let worst = consistency.leastConsistent { print("🏆 Schwächste Dimension: \(worst)") }
        let trendText = consistency.consistencyTrend > 0 ? "📈 wird konsistenter" : (consistency.consistencyTrend < -5 ? "📉 mehr Variation" : "→ stabil")
        print("🏆 Trend: \(trendText)")
        print("🏆 ===================")
        print("🧠 ═══════════════════════════════════")
        print("🧠 VOICE INTELLIGENCE ENGINE")
        print("🧠 State: \(vocalStateResult.primaryState.icon) \(vocalStateResult.primaryState.rawValue) (\(Int(vocalStateResult.confidence * 100))%)")
        print("🧠 Efficiency: \(efficiencyResult.category.icon) \(efficiencyResult.category.rawValue) (\(Int(efficiencyResult.efficiencyScore))/100)")
        print("🧠 Profile: \(profileClassification.profile.rawValue)")
        print("🧠 Score: \(Int(scores.overall))/100")
        print("🧠 Spectral: W\(Int(spectralResult.warmthScore)) B\(Int(spectralResult.bodyScore)) P\(Int(spectralResult.presenceScore)) A\(Int(spectralResult.airScore))")
        if circadian.isReady {
            print("🧠 Peak-Time: \(circadian.optimalHourRange ?? "-")")
        }
        if !patterns.isEmpty {
            print("🧠 Patterns: \(patterns.map { $0.id }.joined(separator: ", "))")
        }
        print("🧠 Next Exercise: \(nextExercise.title)")
        print("🧠 ═══════════════════════════════════")

        FeatureLogger.shared.finalizeSession()
        let totalSessionsAfterSave = memoryManager.totalSessionCount()
        baselineProgress = BaselineProgress(totalSessions: totalSessionsAfterSave)
        checkBaselineMilestones(totalSessions: totalSessionsAfterSave, language: user.language)
        if selectedPitchType.challengePrompt != nil {
            DailyChallengeProvider.shared.markTodayCompleted()
        }

        streakManager.recordSession()
        challengeManager.updateProgress(
            scores: scores,
            pitchType: selectedPitchType.name,
            previousWeakest: memoryManager.recentSessions().first?.weakestDimension
        )
        subscriptionManager.incrementSessionCount()
        XPManager.shared.addXP(XPManager.shared.xpForSession(overallScore: scores.overall))

        let parsedComments = CoachAPIManager.parseTimestampedComments(feedback)
        timestampedComments = parsedComments
        quickFeedback = CoachAPIManager.extractQuickFeedback(feedback)

        if activeProgressiveChallenge != nil {
            let progressiveResult = ProgressiveChallengeProvider.shared.evaluateSession(
                scores: scores,
                heatmapSegments: heatmap.segments.map(\.scores)
            )
            challengeResult = progressiveResult
            if progressiveResult.passed {
                ProgressiveChallengeProvider.shared.completeCurrentLevel()
                XPManager.shared.addXP(progressiveResult.challenge.xpReward)
                showLevelUp = true
            }
            activeProgressiveChallenge = nil
        } else {
            challengeResult = nil
            showLevelUp = false
        }

        if let challenge = activeBiomarkerChallenge {
            let result = BiomarkerChallengeProvider.shared.evaluate(
                challenge: challenge,
                rawFeatures: rawFeatureDict,
                heatmapSegments: heatmap.segments.map(\.scores)
            )
            biomarkerResult = result
            if result.passed {
                XPManager.shared.addXP(result.challenge.xpReward)
            }
            activeBiomarkerChallenge = nil
        }

        _ = DimensionGoalManager.shared.generateGoalIfNeeded(currentScores: scores)
        if let completion = DimensionGoalManager.shared.checkGoalCompletion(currentScores: scores) {
            goalCompletion = completion
        }
        activeGoal = DimensionGoalManager.shared.activeGoal()
        goalProgress = DimensionGoalManager.shared.goalProgress(currentScores: scores)

        if memoryManager.shouldGenerateProfile(for: mutableUser), !Config.claudeAPIKey.isEmpty {
            do {
                let allSessions = memoryManager.recentSessions(count: 30)
                let profilePrompt = PromptBuilder.profileGenerationPrompt(sessions: allSessions)
                let profile = try await CoachAPIManager.requestInsights(
                    payload: profilePrompt,
                    systemPrompt: "You create coaching profiles based on voice performance history.",
                    maxTokens: 500,
                    apiKey: Config.claudeAPIKey
                )
                memoryManager.saveLongTermProfile(profile, for: &mutableUser)
            } catch {
                // Ignore profile generation errors in MVP.
            }
        }

        // 7) Show results
        currentScores = scores
        self.currentConsistency = consistency
        self.latestMilestones = newMilestones
        self.profileClassification = profileClassification
        self.melodicAnalysis = melodicAnalysis
        self.spectralAnalysis = spectralResult
        self.currentPredictionError = predictionError
        self.vocalState = vocalStateResult
        self.vocalEfficiency = efficiencyResult
        self.circadianProfile = circadian
        self.detectedPatterns = patterns
        self.suggestedExercise = nextExercise
        self.voiceDNAProfile = voiceDNA
        self.voiceDNAInsight = generatedInsight
        self.voiceDNADiscoverySessionCount = discoveryCount
        self.isVoiceDNADiscoveryComplete = discoveryComplete
        self.selectedVoiceDNAQuadrant = DiscoveryStateManager.shared.selectedQuadrant
        if quickFeedback.isEmpty {
            quickFeedback = feedback
        }
        self.transcription = finalTranscription
        self.transcriptionSource = transcriptionResult.source
        heatmapData = heatmap
        if let previousBest {
            isNewHighScore = scores.overall > previousBest
        } else {
            isNewHighScore = true
        }
        isProcessing = false
        showScoreScreen = true
    }

    private func checkBaselineMilestones(totalSessions: Int, language: String) {
        switch totalSessions {
        case 7:
            pendingBaselineToast = BaselineToast(
                title: language == "de" ? "Kluna erkennt deine Muster" : "Kluna recognizes your patterns",
                subtitle: language == "de" ? "33% kalibriert" : "33% calibrated",
                icon: "brain.head.profile",
                color: .klunaAccent
            )
        case 14:
            pendingBaselineToast = BaselineToast(
                title: language == "de" ? "Deine Scores werden persönlicher" : "Your scores are becoming personal",
                subtitle: language == "de" ? "66% kalibriert" : "66% calibrated",
                icon: "person.fill.checkmark",
                color: .klunaGreen
            )
        case 21:
            showBaselineEstablishedCelebration = true
        default:
            break
        }
    }
    
    // MARK: - Deep Coaching (on demand)
    
    func requestDeepCoaching(transcription: String) async {
        guard !isLoadingDeepCoaching else { return }
        guard let scores = currentScores else { return }
        isLoadingDeepCoaching = true
        defer { isLoadingDeepCoaching = false }

        let user = loadUser()
        let recentSessions = memoryManager.recentSessions()
        let heatmapSummary = formatHeatmapSummary(heatmapData)
        let effectiveTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? self.transcription
            : transcription
        
        do {
            let systemPrompt = PromptBuilder.buildDeepCoachingPrompt(
                user: user,
                scores: scores,
                pitchType: selectedPitchType.name,
                recentSessions: recentSessions,
                heatmapSummary: heatmapSummary,
                profileClassification: profileClassification,
                melodicAnalysis: melodicAnalysis,
                spectralResult: spectralAnalysis,
                consistency: currentConsistency,
                prediction: currentPrediction,
                predictionError: currentPredictionError,
                contextualInsights: {
                    guard let spectralAnalysis, let vocalState, let vocalEfficiency else { return nil }
                    return ContextualCoachingEngine.buildPrompt(
                        scores: scores,
                        bridgeFeatures: [:],
                        vocalState: vocalState,
                        efficiency: vocalEfficiency,
                        spectral: spectralAnalysis,
                        profile: profileClassification?.profile,
                        prediction: currentPrediction,
                        circadian: circadianProfile,
                        patterns: detectedPatterns,
                        consistency: currentConsistency,
                        sessionCount: memoryManager.totalSessionCount(),
                        recentScores: memoryManager.recentOverallScores(limit: 10, oldestFirst: true),
                        transcription: effectiveTranscription
                    )
                }()
            )
            deepCoaching = try await CoachAPIManager.requestInsights(
                payload: effectiveTranscription,
                systemPrompt: systemPrompt,
                maxTokens: Config.deepCoachingMaxTokens,
                apiKey: Config.claudeAPIKey
            )
        } catch {
            deepCoaching = user.language == "de"
                ? "Deep Coaching ist gerade nicht verfügbar. Bitte versuche es in ein paar Sekunden erneut."
                : "Deep coaching is temporarily unavailable. Please try again in a few seconds."
        }
    }

    // MARK: - Playback

    func togglePlayback() {
        isPlayingBack ? stopPlayback() : startPlayback()
    }

    private func startPlayback() {
        guard let url = recordingURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            isPlayingBack = true

            playbackTimer?.invalidate()
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                guard let self, let player = self.audioPlayer else { return }
                self.playbackCurrentTime = player.currentTime
                self.playbackProgress = player.duration > 0 ? (player.currentTime / player.duration) : 0
                if !player.isPlaying {
                    self.stopPlayback(resetProgress: false)
                }
            }
        } catch {
            print("❌ Playback failed: \(error)")
        }
    }

    func stopPlayback(resetProgress: Bool = true) {
        audioPlayer?.stop()
        audioPlayer = nil
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlayingBack = false
        playbackCurrentTime = resetProgress ? 0 : playbackCurrentTime
        playbackProgress = resetProgress ? 0 : 1
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    // MARK: - Helpers
    
    private func loadUser() -> KlunaUser {
        memoryManager.loadUser()
    }
    
    private func formatHeatmapSummary(_ heatmap: HeatmapData?) -> String {
        guard heatmap != nil else { return "No heatmap data" }
        // TODO: Format segment scores as text summary for Claude
        return "First third: ..., Second third: ..., Final third: ..."
    }

    private func spectralSegments(
        samples: [Float],
        sampleRate: Float,
        analyzer: SpectralBandAnalyzer
    ) -> [SpectralBandResult] {
        guard !samples.isEmpty else { return [] }
        let targetSegments = max(3, Config.heatmapSegments)
        let segmentLength = max(2048, samples.count / targetSegments)
        guard segmentLength > 0 else { return [] }

        var result: [SpectralBandResult] = []
        var start = 0
        while start < samples.count {
            let end = min(samples.count, start + segmentLength)
            let segment = Array(samples[start..<end])
            let spectral = analyzer.analyze(samples: segment, sampleRate: sampleRate)
            if spectral.presenceScore > 0 || spectral.overallTimbreScore > 0 {
                result.append(spectral)
            }
            start = end
        }
        return result
    }

    private func microphonePermissionStatus() -> MicrophonePermission {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                return .undetermined
            @unknown default:
                return .undetermined
            }
        }
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .undetermined
        @unknown default:
            return .undetermined
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }

    private func logTiming(_ label: String, seconds: CFTimeInterval) {
        #if DEBUG
        guard DebugConfig.showTimingLogs else { return }
        print("\(label): \(String(format: "%.0f", seconds * 1000))ms")
        #endif
    }

    private func logRawFeatures(_ features: [String: Double], sessionType: String) {
        #if DEBUG
        print("═══════════════════════════════════════")
        print("🎤 Session: \(sessionType)")
        print("═══════════════════════════════════════")
        print("F0 Mean:            \(String(format: "%.1f", features[FeatureKeys.f0Mean] ?? 0)) Hz")
        print("F0 Range:           \(String(format: "%.1f", features[FeatureKeys.f0RangeST] ?? features[FeatureKeys.f0Range] ?? 0)) ST")
        print("F0 StdDev:          \(String(format: "%.1f", features[FeatureKeys.f0StdDev] ?? 0)) Hz")
        print("Jitter:             \(String(format: "%.4f", features[FeatureKeys.jitter] ?? 0))")
        print("Shimmer:            \(String(format: "%.4f", features[FeatureKeys.shimmer] ?? 0))")
        print("HNR:                \(String(format: "%.1f", features[FeatureKeys.hnr] ?? 0)) dB")
        print("Loudness RMS:       \(String(format: "%.3f", features[FeatureKeys.loudnessRMS] ?? features[FeatureKeys.loudness] ?? 0))")
        print("Loudness StdDev:    \(String(format: "%.6f", features[FeatureKeys.loudnessStdDev] ?? 0))")
        print("Speech Rate:        \(String(format: "%.2f", features[FeatureKeys.speechRate] ?? 0)) syl/s")
        print("Pause Rate:         \(String(format: "%.1f", features[FeatureKeys.pauseRate] ?? 0)) /min")
        print("Mean Pause Dur:     \(String(format: "%.2f", features[FeatureKeys.meanPauseDuration] ?? features[FeatureKeys.pauseDuration] ?? 0)) s")
        print("Formant Dispersion: \(String(format: "%.0f", features[FeatureKeys.formantDispersion] ?? 0)) Hz")
        print("Articulation Rate:  \(String(format: "%.2f", features[FeatureKeys.articulationRate] ?? 0)) syl/s")
        print("═══════════════════════════════════════")
        #endif
    }

    private func sortedPitchTypes(for goal: UserGoal) -> [PitchType] {
        let all = memoryManager.allPitchTypes()
        guard !all.isEmpty else { return PitchType.defaults }
        let prioritized: [String]
        switch goal {
        case .pitches:
            prioritized = ["Elevator Pitch", "Investor Pitch", "Sales Pitch", "Closing"]
        case .content:
            prioritized = ["Podcast Intro", "Story", "Free Practice", "Explanation", "Hook"]
        case .interviews:
            prioritized = ["Self Introduction", "Strengths & Weaknesses", "Why us?", "Salary Negotiation"]
        case .confidence:
            prioritized = ["Free Practice", "Self Introduction", "Opinion", "Small Talk", "Anecdote"]
        }
        return all.sorted { a, b in
            let aIndex = prioritized.firstIndex(of: a.name) ?? 999
            let bIndex = prioritized.firstIndex(of: b.name) ?? 999
            if aIndex == bIndex { return a.name < b.name }
            return aIndex < bIndex
        }
    }

    deinit {
        playbackTimer?.invalidate()
    }
}
