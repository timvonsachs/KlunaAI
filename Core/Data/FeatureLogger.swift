import Foundation
import Darwin

struct SessionFeatureLog: Codable {
    let sessionId: String
    let timestamp: String
    let durationSeconds: Double
    let practiceType: String
    let appVersion: String
    let deviceModel: String

    var loudnessRMS: Double?
    var loudnessRMSOriginal: Double?
    var loudnessStdDev: Double?
    var loudnessDynamicRange: Double?
    var f0Mean: Double?
    var f0RangeST: Double?
    var f0StdDev: Double?
    var jitter: Double?
    var shimmer: Double?
    var hnr: Double?
    var speechRate: Double?
    var articulationRate: Double?
    var pauseRate: Double?
    var meanPauseDuration: Double?
    var formantDispersion: Double?
    var appliedGain: Double?

    var warmthScore: Double?
    var bodyScore: Double?
    var presenceScore: Double?
    var airScore: Double?
    var timbreScore: Double?
    var warmthToPresenceRatio: Double?
    var bodyToTotalRatio: Double?
    var presenceToTotalRatio: Double?
    var spectralBalance: Double?

    var hatPatternCount: Int?
    var hatPatternScore: Double?
    var emphasisCorrelation: Double?
    var emphasisRegularity: Double?
    var downstepPresent: Bool?
    var downstepStrength: Double?
    var finalLoweringPresent: Bool?
    var finalLoweringStrength: Double?
    var intentionalityScore: Double?

    var scoreOverall: Double?
    var scoreConfidence: Double?
    var scoreEnergy: Double?
    var scoreTempo: Double?
    var scoreClarity: Double?
    var scoreStability: Double?
    var scoreCharisma: Double?
    var dnaAuthority: Double?
    var dnaCharisma: Double?
    var dnaWarmth: Double?
    var dnaComposure: Double?

    var profileName: String?
    var profileRank: Int?
    var profileConfidence: Double?
    var secondaryProfile: String?

    var predictedScore: Double?
    var predictionDelta: Double?
    var predictionTrend: String?

    var masteryLevel: String?
    var consistencyScore: Double?
    var currentStreak: Int?

    var vocalState: String?
    var vocalStateConfidence: Double?
    var efficiencyScore: Double?
    var efficiencyCategory: String?
    var presencePerJitter: Double?
    var exerciseId: String?
    var exerciseSuccessRate: Double?

    var zScores: [String: Double]?

    var userRating: Int?
    var claudeRating: String?

    var transcriptionLength: Int?
    var transcriptionText: String?
    var transcriptionSource: String?
    var transcriptionConfidence: Double?
    var whisperSegments: [WhisperSegment]?

    var segmentScores: [SegmentLog]?
}

struct SegmentLog: Codable {
    let rangeStart: Double
    let rangeEnd: Double
    var loudnessRMS: Double?
    var f0Mean: Double?
    var f0RangeST: Double?
    var speechRate: Double?
    var pauseRate: Double?
}

final class FeatureLogger {
    static let shared = FeatureLogger()

    private let fileName = "kluna_feature_logs.jsonl"
    private let encoder: JSONEncoder
    private let queue = DispatchQueue(label: "com.kluna.featurelogger", qos: .utility)
    private let isoFormatter = ISO8601DateFormatter()
    private var currentLog: SessionFeatureLog?

    private var logFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }

    private init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = []
    }

    func beginSession(practiceType: String, duration: Double, sessionId: String? = nil) {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        currentLog = SessionFeatureLog(
            sessionId: sessionId ?? UUID().uuidString,
            timestamp: isoFormatter.string(from: Date()),
            durationSeconds: duration,
            practiceType: practiceType,
            appVersion: appVersion,
            deviceModel: getDeviceModel()
        )
    }

    func setBridgeFeatures(_ features: [String: Double]) {
        guard currentLog != nil else { return }
        currentLog?.loudnessRMS = features[FeatureKeys.loudnessRMS] ?? features[FeatureKeys.loudness]
        currentLog?.loudnessRMSOriginal = features["loudnessRMSOriginal"]
        currentLog?.loudnessStdDev = features[FeatureKeys.loudnessStdDev]
        currentLog?.loudnessDynamicRange = features["loudnessDynamicRange"]
        currentLog?.f0Mean = features[FeatureKeys.f0Mean]
        currentLog?.f0RangeST = features[FeatureKeys.f0RangeST] ?? features[FeatureKeys.f0Range]
        currentLog?.f0StdDev = features[FeatureKeys.f0StdDev] ?? features[FeatureKeys.f0Variability]
        currentLog?.jitter = features[FeatureKeys.jitter]
        currentLog?.shimmer = features[FeatureKeys.shimmer]
        currentLog?.hnr = features[FeatureKeys.hnr]
        currentLog?.speechRate = features[FeatureKeys.speechRate]
        currentLog?.articulationRate = features[FeatureKeys.articulationRate]
        currentLog?.pauseRate = features[FeatureKeys.pauseRate] ?? features[FeatureKeys.pauseDistribution]
        currentLog?.meanPauseDuration = features[FeatureKeys.meanPauseDuration] ?? features[FeatureKeys.pauseDuration]
        currentLog?.formantDispersion = features[FeatureKeys.formantDispersion]
        currentLog?.appliedGain = features["appliedGain"]
    }

    func setZScores(_ zScores: [String: Double]) {
        currentLog?.zScores = zScores
    }

    func setSpectralFeatures(
        warmth: Double,
        body: Double,
        presence: Double,
        air: Double,
        timbre: Double,
        warmthToPresence: Double,
        bodyToTotal: Double,
        presenceToTotal: Double,
        balance: Double
    ) {
        currentLog?.warmthScore = warmth
        currentLog?.bodyScore = body
        currentLog?.presenceScore = presence
        currentLog?.airScore = air
        currentLog?.timbreScore = timbre
        currentLog?.warmthToPresenceRatio = warmthToPresence
        currentLog?.bodyToTotalRatio = bodyToTotal
        currentLog?.presenceToTotalRatio = presenceToTotal
        currentLog?.spectralBalance = balance
    }

    func setMelodicFeatures(
        hatPatterns: Int,
        hatScore: Double,
        emphasisCorr: Double,
        emphasisReg: Double,
        downstep: Bool,
        downstepStrength: Double,
        finalLowering: Bool,
        finalLoweringStrength: Double,
        intentionality: Double
    ) {
        currentLog?.hatPatternCount = hatPatterns
        currentLog?.hatPatternScore = hatScore
        currentLog?.emphasisCorrelation = emphasisCorr
        currentLog?.emphasisRegularity = emphasisReg
        currentLog?.downstepPresent = downstep
        currentLog?.downstepStrength = downstepStrength
        currentLog?.finalLoweringPresent = finalLowering
        currentLog?.finalLoweringStrength = finalLoweringStrength
        currentLog?.intentionalityScore = intentionality
    }

    func setScores(
        overall: Double,
        confidence: Double,
        energy: Double,
        tempo: Double,
        clarity: Double,
        stability: Double,
        charisma: Double
    ) {
        currentLog?.scoreOverall = overall
        currentLog?.scoreConfidence = confidence
        currentLog?.scoreEnergy = energy
        currentLog?.scoreTempo = tempo
        currentLog?.scoreClarity = clarity
        currentLog?.scoreStability = stability
        currentLog?.scoreCharisma = charisma
    }

    func setVoiceDNA(
        authority: Double,
        charisma: Double,
        warmth: Double,
        composure: Double
    ) {
        currentLog?.dnaAuthority = authority
        currentLog?.dnaCharisma = charisma
        currentLog?.dnaWarmth = warmth
        currentLog?.dnaComposure = composure
    }

    func setProfile(name: String, rank: Int, confidence: Double, secondary: String?) {
        currentLog?.profileName = name
        currentLog?.profileRank = rank
        currentLog?.profileConfidence = confidence
        currentLog?.secondaryProfile = secondary
    }

    func setPrediction(expected: Double?, delta: Double?, trend: String?) {
        currentLog?.predictedScore = expected
        currentLog?.predictionDelta = delta
        currentLog?.predictionTrend = trend
    }

    func setConsistency(level: String, score: Double, streak: Int) {
        currentLog?.masteryLevel = level
        currentLog?.consistencyScore = score
        currentLog?.currentStreak = streak
    }

    func setVocalState(state: String, confidence: Double) {
        currentLog?.vocalState = state
        currentLog?.vocalStateConfidence = confidence
    }

    func setEfficiency(score: Double, category: String, presencePerJitter: Double) {
        currentLog?.efficiencyScore = score
        currentLog?.efficiencyCategory = category
        currentLog?.presencePerJitter = presencePerJitter
    }

    func setExercise(id: String?, successRate: Double?) {
        currentLog?.exerciseId = id
        currentLog?.exerciseSuccessRate = successRate
    }

    func setTranscription(
        text: String,
        source: String,
        confidence: Double,
        segments: [WhisperSegment]? = nil
    ) {
        currentLog?.transcriptionText = text
        currentLog?.transcriptionLength = text.count
        currentLog?.transcriptionSource = source
        currentLog?.transcriptionConfidence = confidence
        currentLog?.whisperSegments = segments
    }

    func setSegments(_ segments: [SegmentLog]) {
        currentLog?.segmentScores = segments
    }

    func setClaudeRating(_ rating: String?) {
        currentLog?.claudeRating = rating
    }

    func setUserRating(_ rating: Int, sessionId: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let payload = "{\"type\":\"rating\",\"sessionId\":\"\(sessionId)\",\"userRating\":\(rating),\"timestamp\":\"\(self.isoFormatter.string(from: Date()))\"}\n"
            self.appendToFile(payload)
        }
    }

    func finalizeSession() {
        guard let log = currentLog else {
            print("⚠️ FeatureLogger: No current session to finalize")
            return
        }
        queue.async { [weak self] in
            guard let self else { return }
            do {
                let data = try self.encoder.encode(log)
                guard var jsonString = String(data: data, encoding: .utf8) else { return }
                jsonString += "\n"
                self.appendToFile(jsonString)
                print("📝 FeatureLog written: session=\(log.sessionId.prefix(8))... total=\(self.getLogCount()) logs")
            } catch {
                print("❌ FeatureLogger encode error: \(error)")
            }
        }
        currentLog = nil
    }

    func getLogCount() -> Int {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else { return 0 }
        return content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
    }

    func getLogFileSize() -> String {
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
            let size = attrs[.size] as? Int64
        else { return "0 KB" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / 1024.0 / 1024.0)
    }

    func getLogFilePath() -> URL { logFileURL }

    func loadAllLogs() -> [SessionFeatureLog] {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        return content
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.contains("\"type\":\"rating\"") }
            .compactMap { line -> SessionFeatureLog? in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(SessionFeatureLog.self, from: data)
            }
    }

    func loadRecentLogs(count: Int) -> [SessionFeatureLog] {
        Array(loadAllLogs().suffix(count))
    }

    func exportLogs() -> Data? {
        try? Data(contentsOf: logFileURL)
    }

    func clearAllLogs() {
        try? FileManager.default.removeItem(at: logFileURL)
        print("🗑️ Feature logs cleared")
    }

    private func appendToFile(_ string: String) {
        let url = logFileURL
        if FileManager.default.fileExists(atPath: url.path) {
            guard let fileHandle = try? FileHandle(forWritingTo: url) else { return }
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            if let data = string.data(using: .utf8) {
                fileHandle.write(data)
            }
        } else {
            try? string.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }
}
