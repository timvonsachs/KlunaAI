import CoreData
import Foundation
import Combine

final class BaselineEngine {
    private let alpha = Config.ewmaAlpha
    private let minSessions = Config.baselineMinSessions
    private let minSessionsForPersonalScoring = Config.baselineMinSessions
    private let varianceFloor = 1e-4

    func updateBaseline(with features: VoiceFeatures, context: NSManagedObjectContext) {
        let values = FeatureKeyMapper.normalize(features.asDictionary)
        context.performAndWait {
            for (featureKey, value) in values {
                let request: NSFetchRequest<CDBaseline> = CDBaseline.fetchRequest()
                request.predicate = NSPredicate(format: "feature == %@", featureKey)
                request.fetchLimit = 1
                let entity = (try? context.fetch(request).first) ?? CDBaseline(context: context)
                entity.feature = featureKey
                let oldMean = entity.sampleCount > 0 ? entity.ewmaMean : value
                let oldVar = entity.sampleCount > 0 ? entity.ewmaVariance : 0

                if entity.sampleCount == 0 {
                    entity.ewmaMean = value
                    entity.ewmaVariance = 0
                    entity.sampleCount = 1
                } else {
                    entity.ewmaMean = alpha * value + (1 - alpha) * oldMean
                    entity.ewmaVariance = (1 - alpha) * (oldVar + alpha * pow(value - oldMean, 2))
                    entity.sampleCount += 1
                }
                entity.lastUpdated = Date()
            }
            try? context.save()
        }
    }

    func calculateAllZScores(for features: VoiceFeatures, voiceType: VoiceType, context: NSManagedObjectContext) -> [String: Double] {
        let values = features.asDictionary
        return calculateAllZScores(for: values, voiceType: voiceType, context: context)
    }

    func calculateAllZScores(for values: [String: Double], voiceType: VoiceType, context: NSManagedObjectContext) -> [String: Double] {
        let normalizedValues = FeatureKeyMapper.normalize(values)
        let populationValues = PopulationBaseline.values(for: voiceType)
        var zScores: [String: Double] = [:]
        context.performAndWait {
            for (featureKey, value) in normalizedValues {
                if let entity = loadBaseline(for: featureKey, context: context),
                   Int(entity.sampleCount) >= minSessionsForPersonalScoring {
                    let personalStd = max(sqrt(max(varianceFloor, entity.ewmaVariance)), varianceFloor)
                    let popStd = max(populationValues[featureKey]?.stddev ?? personalStd, varianceFloor)
                    // Guard against unrealistically tiny personal variance in early adaptation.
                    let effectiveStd = max(personalStd, popStd * 0.25)
                    let personalZ = (value - entity.ewmaMean) / effectiveStd

                    if abs(personalZ) > 8, let pop = populationValues[featureKey] {
                        let popZ = (value - pop.mean) / max(pop.stddev, varianceFloor)
                        zScores[featureKey] = max(-4, min(4, popZ))
                    } else {
                        zScores[featureKey] = max(-4, min(4, personalZ))
                    }
                } else if let pop = populationValues[featureKey] {
                    let popZ = (value - pop.mean) / max(pop.stddev, varianceFloor)
                    zScores[featureKey] = max(-4, min(4, popZ))
                }
            }
        }
        return zScores
    }

    func isBaselineEstablished(context: NSManagedObjectContext) -> Bool {
        context.performAndWait {
            let request: NSFetchRequest<CDBaseline> = CDBaseline.fetchRequest()
            request.fetchLimit = 1
            guard let first = try? context.fetch(request).first else { return false }
            return Int(first.sampleCount) >= minSessions
        }
    }

    func baselineStatus(context: NSManagedObjectContext) -> BaselineStatus {
        context.performAndWait {
            let request: NSFetchRequest<CDBaseline> = CDBaseline.fetchRequest()
            request.fetchLimit = 1
            let first = try? context.fetch(request).first
            let count = Int(first?.sampleCount ?? 0)
            return BaselineStatus(sessionCount: count, isEstablished: count >= minSessions)
        }
    }

    func baselineDebug(values: [String: Double], voiceType: VoiceType, context: NSManagedObjectContext) -> [BaselineDebugEntry] {
        let normalizedValues = FeatureKeyMapper.normalize(values)
        let populationValues = PopulationBaseline.values(for: voiceType)
        var entries: [BaselineDebugEntry] = []
        context.performAndWait {
            for (feature, value) in normalizedValues.sorted(by: { $0.key < $1.key }) {
                if let entity = loadBaseline(for: feature, context: context),
                   Int(entity.sampleCount) >= minSessionsForPersonalScoring {
                    let std = max(sqrt(max(varianceFloor, entity.ewmaVariance)), varianceFloor)
                    let z = (value - entity.ewmaMean) / std
                    entries.append(BaselineDebugEntry(feature: feature, value: value, mean: entity.ewmaMean, stdDev: std, zScore: z, source: "personal"))
                } else if let pop = populationValues[feature] {
                    let std = max(pop.stddev, varianceFloor)
                    let z = (value - pop.mean) / std
                    entries.append(BaselineDebugEntry(feature: feature, value: value, mean: pop.mean, stdDev: std, zScore: z, source: "population"))
                } else {
                    entries.append(BaselineDebugEntry(feature: feature, value: value, mean: 0, stdDev: 1, zScore: 0, source: "missing"))
                }
            }
        }
        return entries
    }

    private func loadBaseline(for key: String, context: NSManagedObjectContext) -> CDBaseline? {
        let request: NSFetchRequest<CDBaseline> = CDBaseline.fetchRequest()
        request.predicate = NSPredicate(format: "feature == %@", key)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    func resetAll(context: NSManagedObjectContext) {
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CDBaseline")
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            _ = try? context.execute(delete)
            try? context.save()
        }
    }
}

struct BaselineStatus {
    let sessionCount: Int
    let isEstablished: Bool
}

struct BaselineDebugEntry {
    let feature: String
    let value: Double
    let mean: Double
    let stdDev: Double
    let zScore: Double
    let source: String
}

final class BaselineManager {
    static let shared = BaselineManager()

    private let alpha: Float = 0.1
    private let minEntriesForBaseline: Int = 5
    private let storageKey = "kluna_ewma_baselines"

    struct EWMABaseline: Codable {
        var mean: Float
        var variance: Float
        var count: Int

        var standardDeviation: Float {
            sqrt(max(variance, 0.001))
        }

        func zScore(for value: Float, minCount: Int) -> Float {
            guard count >= minCount else { return 0 }
            return (value - mean) / standardDeviation
        }

        mutating func update(with value: Float, alpha: Float) {
            if count == 0 {
                mean = value
                variance = 0
                count = 1
                return
            }

            let diff = value - mean
            mean = mean + alpha * diff
            variance = (1 - alpha) * (variance + alpha * diff * diff)
            count += 1
        }
    }

    private let trackedFeatures: [String: String] = [
        "arousal": "arousal",
        "acousticValence": "acousticValence",
        "f0Mean": FeatureKeys.f0Mean,
        "f0Range": FeatureKeys.f0RangeST,
        "jitter": FeatureKeys.jitter,
        "hnr": FeatureKeys.hnr,
        "speechRate": FeatureKeys.speechRate,
        "pauseRate": FeatureKeys.pauseRate,
        "loudnessMean": FeatureKeys.loudnessRMSOriginal,
    ]

    private var baselines: [String: EWMABaseline] = [:]

    private init() {
        loadBaselines()
    }

    func processEntry(features: [String: Double]) -> BaselineDeltas {
        var deltas = BaselineDeltas()

        for (deltaKey, featureKey) in trackedFeatures {
            guard let value = featureValue(for: featureKey, in: features) else { continue }
            if baselines[deltaKey] == nil {
                baselines[deltaKey] = EWMABaseline(mean: 0, variance: 0, count: 0)
            }
            guard var baseline = baselines[deltaKey] else { continue }

            let z = baseline.zScore(for: value, minCount: minEntriesForBaseline)
            let delta = baseline.count > 0 ? (value - baseline.mean) : 0

            switch deltaKey {
            case "arousal":
                deltas.arousalDelta = delta
                deltas.arousalZScore = z
            case "acousticValence":
                deltas.valenceDelta = delta
                deltas.valenceZScore = z
            case "f0Mean":
                deltas.f0Delta = delta
                deltas.f0ZScore = z
            case "jitter":
                deltas.jitterDelta = delta
                deltas.jitterZScore = z
            case "hnr":
                deltas.hnrDelta = delta
                deltas.hnrZScore = z
            case "speechRate":
                deltas.speechRateDelta = delta
                deltas.speechRateZScore = z
            case "loudnessMean":
                deltas.loudnessDelta = delta
                deltas.loudnessZScore = z
            case "pauseRate":
                deltas.pauseRateDelta = delta
                deltas.pauseRateZScore = z
            case "f0Range":
                deltas.f0Delta = delta
                deltas.f0ZScore = z
            default:
                break
            }

            baseline.update(with: value, alpha: alpha)
            baselines[deltaKey] = baseline
        }

        saveBaselines()
        return deltas
    }

    func baselineFor(_ feature: String) -> Float? {
        guard let baseline = baselines[feature], baseline.count >= minEntriesForBaseline else {
            return nil
        }
        return baseline.mean
    }

    func hasReliableBaseline() -> Bool {
        guard let arousal = baselines["arousal"] else { return false }
        return arousal.count >= minEntriesForBaseline
    }

    func entryCount() -> Int {
        baselines["arousal"]?.count ?? 0
    }

    func resetBaselines() {
        baselines = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func featureValue(for key: String, in features: [String: Double]) -> Float? {
        if key == FeatureKeys.f0RangeST {
            if let value = features[FeatureKeys.f0RangeST] { return Float(value) }
            if let value = features[FeatureKeys.f0Range] { return Float(value) }
            return nil
        }
        if key == FeatureKeys.loudnessRMSOriginal {
            if let value = features[FeatureKeys.loudnessRMSOriginal] { return Float(value) }
            if let value = features[FeatureKeys.loudnessRMS] { return Float(value) }
            if let value = features[FeatureKeys.loudness] { return Float(value) }
            return nil
        }
        guard let value = features[key] else { return nil }
        return Float(value)
    }

    private func saveBaselines() {
        guard let data = try? JSONEncoder().encode(baselines) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadBaselines() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([String: EWMABaseline].self, from: data) else {
            return
        }
        baselines = saved
    }
}

@MainActor
final class PersonalCalibration: ObservableObject {
    static let shared = PersonalCalibration()

    @Published var isCalibrated: Bool = false
    @Published var entryCount: Int = 0

    private var featureProfiles: [String: FeatureProfile] = [:]
    private var baselines: [String: EWMABaseline] = [:]

    struct FeatureProfile: Codable {
        var center: Float
        var low: Float
        var high: Float
        var stdDev: Float
        var sampleCount: Int
    }

    struct EWMABaseline: Codable {
        var mean: Float
        var variance: Float
        var count: Int
    }

    static let trackedFeatures: [String] = [
        FeatureKeys.f0Mean, FeatureKeys.f0RangeST, FeatureKeys.f0StdDev,
        FeatureKeys.jitter, FeatureKeys.shimmer, FeatureKeys.hnr,
        FeatureKeys.speechRate, FeatureKeys.articulationRate, FeatureKeys.pauseRate, FeatureKeys.pauseDuration,
        FeatureKeys.loudnessRMSOriginal, FeatureKeys.loudnessDynamicRangeOriginal, FeatureKeys.loudnessStdDevOriginal,
        FeatureKeys.formantDispersion,
        "spectralWarmthRatio", "spectralPresenceRatio",
    ]

    init() {
        load()
    }

    func processEntry(features: [String: Double]) -> CalibrationResult {
        entryCount += 1

        let alpha: Float
        let result: CalibrationResult

        if entryCount == 1 {
            result = initializeFromFirst(features)
            alpha = 1.0
        } else if entryCount <= 10 {
            alpha = 0.3
            result = updateCalibration(features, alpha: alpha)
        } else {
            alpha = 0.1
            result = updateCalibration(features, alpha: alpha)
        }

        updateBaselines(features, alpha: alpha)
        save()
        isCalibrated = true
        return result
    }

    func personalizedDimensions(features: [String: Double]) -> EngineVoiceDimensions {
        let energy = calculateEnergy(features)
        let tension = calculateTension(features)
        let fatigue = calculateFatigue(features)
        let warmth = calculateWarmth(features)
        let expressiveness = calculateExpressiveness(features)
        let tempo = calculateTempo(features)
        return EngineVoiceDimensions(
            energy: clamp(energy),
            tension: clamp(tension),
            fatigue: clamp(fatigue),
            warmth: clamp(warmth),
            expressiveness: clamp(expressiveness),
            tempo: clamp(tempo)
        )
    }

    func personalizedArousal(features: [String: Double]) -> Float {
        let dims = personalizedDimensions(features: features)
        return clamp((dims.tempo * 0.3 + dims.expressiveness * 0.3 + dims.energy * 0.4) * 100, min: 0, max: 100)
    }

    func hasReliableCalibration() -> Bool {
        entryCount >= 2
    }

    func acousticFlags(from result: CalibrationResult, fallback: [AcousticFlag]) -> [AcousticFlag] {
        if result.phase == .initial {
            return fallback
        }

        let threshold: Float = 1.2
        var out: [AcousticFlag] = []
        let z = result.zScores

        if let rangeZ = z[FeatureKeys.f0RangeST] {
            if rangeZ < -threshold { out.append(.isMonotone) }
            if rangeZ > threshold { out.append(.isHighPitchVariation) }
        }
        if let jitterZ = z[FeatureKeys.jitter], jitterZ > threshold { out.append(.isJitterElevated) }
        if let srZ = z[FeatureKeys.speechRate] {
            if srZ > threshold { out.append(.isTempoFast) }
            if srZ < -threshold { out.append(.isTempoSlow) }
        }
        if let pauseZ = z[FeatureKeys.pauseDuration] {
            if pauseZ > threshold { out.append(.isPauseLong) }
            if pauseZ < -threshold { out.append(.isPauseAbsent) }
        }
        if let loudnessZ = z[FeatureKeys.loudnessRMSOriginal] {
            if loudnessZ > threshold { out.append(.isLoudnessHigh) }
            if loudnessZ < -threshold { out.append(.isLoudnessLow) }
        }
        if let hnrZ = z[FeatureKeys.hnr] {
            if hnrZ > threshold { out.append(.isWarmthHigh) }
            if hnrZ < -threshold { out.append(.isWarmthLow) }
        }
        return Array(NSOrderedSet(array: out)) as? [AcousticFlag] ?? out
    }

    func baselineDeltas(from result: CalibrationResult) -> BaselineDeltas {
        var deltas = BaselineDeltas()
        deltas.f0Delta = result.deltas[FeatureKeys.f0RangeST] ?? 0
        deltas.f0ZScore = result.zScores[FeatureKeys.f0RangeST] ?? 0
        deltas.jitterDelta = result.deltas[FeatureKeys.jitter] ?? 0
        deltas.jitterZScore = result.zScores[FeatureKeys.jitter] ?? 0
        deltas.hnrDelta = result.deltas[FeatureKeys.hnr] ?? 0
        deltas.hnrZScore = result.zScores[FeatureKeys.hnr] ?? 0
        deltas.speechRateDelta = result.deltas[FeatureKeys.speechRate] ?? 0
        deltas.speechRateZScore = result.zScores[FeatureKeys.speechRate] ?? 0
        deltas.loudnessDelta = result.deltas[FeatureKeys.loudnessRMSOriginal] ?? 0
        deltas.loudnessZScore = result.zScores[FeatureKeys.loudnessRMSOriginal] ?? 0
        deltas.pauseRateDelta = result.deltas[FeatureKeys.pauseDuration] ?? 0
        deltas.pauseRateZScore = result.zScores[FeatureKeys.pauseDuration] ?? 0
        deltas.arousalDelta = result.deltas["arousal"] ?? 0
        deltas.arousalZScore = result.zScores["arousal"] ?? 0
        deltas.valenceDelta = result.deltas["acousticValence"] ?? 0
        deltas.valenceZScore = result.zScores["acousticValence"] ?? 0
        return deltas
    }

    func reset() {
        featureProfiles = [:]
        baselines = [:]
        entryCount = 0
        isCalibrated = false
        UserDefaults.standard.removeObject(forKey: "kluna_calibration")
    }

    private func initializeFromFirst(_ features: [String: Double]) -> CalibrationResult {
        for key in Self.trackedFeatures {
            guard let value = floatValue(features, key) else { continue }
            let estimatedVariance = estimateVariance(feature: key, firstValue: value)
            featureProfiles[key] = FeatureProfile(
                center: value,
                low: value - estimatedVariance * 1.5,
                high: value + estimatedVariance * 1.5,
                stdDev: max(0.0001, estimatedVariance),
                sampleCount: 1
            )
            baselines[key] = EWMABaseline(
                mean: value,
                variance: max(0.0001, estimatedVariance * estimatedVariance),
                count: 1
            )
        }
        print("🎯 Calibration: Initialized from first entry")
        printCalibrationSummary(features)
        return CalibrationResult(zScores: [:], deltas: [:], flags: [], phase: .initial)
    }

    private func estimateVariance(feature: String, firstValue: Float) -> Float {
        switch feature {
        case FeatureKeys.f0Mean: return max(0.01, firstValue * 0.12)
        case FeatureKeys.f0RangeST: return 2.0
        case FeatureKeys.f0StdDev: return max(0.01, firstValue * 0.3)
        case FeatureKeys.jitter: return 0.008
        case FeatureKeys.shimmer: return 0.04
        case FeatureKeys.hnr: return 1.0
        case FeatureKeys.speechRate: return 1.0
        case FeatureKeys.articulationRate: return 1.2
        case FeatureKeys.pauseRate: return 8.0
        case FeatureKeys.pauseDuration: return 0.2
        case FeatureKeys.loudnessRMSOriginal: return max(0.0005, firstValue * 0.4)
        case FeatureKeys.loudnessDynamicRangeOriginal: return 6.0
        case FeatureKeys.loudnessStdDevOriginal: return max(0.0005, firstValue * 0.3)
        case FeatureKeys.formantDispersion: return 150.0
        case "spectralWarmthRatio": return 0.1
        case "spectralPresenceRatio": return 0.01
        default: return max(0.01, firstValue * 0.2)
        }
    }

    private func updateCalibration(_ features: [String: Double], alpha: Float) -> CalibrationResult {
        var zScores: [String: Float] = [:]
        var deltas: [String: Float] = [:]
        var flags: [CalibrationFlag] = []

        for key in Self.trackedFeatures {
            guard let value = floatValue(features, key),
                  var profile = featureProfiles[key] else { continue }

            let currentStd = max(profile.stdDev, 0.0001)
            let zScore = (value - profile.center) / currentStd
            zScores[key] = zScore
            deltas[key] = value - profile.center

            if abs(zScore) > 1.2 {
                flags.append(
                    CalibrationFlag(
                        feature: key,
                        zScore: zScore,
                        description: flagDescription(feature: key, zScore: zScore)
                    )
                )
            }

            profile.center = profile.center * (1 - alpha) + value * alpha
            profile.sampleCount += 1

            let diff = value - profile.center
            profile.stdDev = sqrt(max(0.0001, profile.stdDev * profile.stdDev * (1 - alpha) + diff * diff * alpha))
            profile.low = profile.center - profile.stdDev * 1.5
            profile.high = profile.center + profile.stdDev * 1.5
            featureProfiles[key] = profile
        }

        let phase: CalibrationPhase = entryCount <= 10 ? .learning : .stable
        if entryCount == 2 { print("🎯 Calibration: First comparison available") }
        if entryCount == 10 { print("🎯 Calibration: Learning phase complete") }

        return CalibrationResult(zScores: zScores, deltas: deltas, flags: flags, phase: phase)
    }

    private func updateBaselines(_ features: [String: Double], alpha: Float) {
        for key in Self.trackedFeatures {
            guard let value = floatValue(features, key) else { continue }
            if var baseline = baselines[key] {
                let diff = value - baseline.mean
                baseline.mean += alpha * diff
                baseline.variance = (1 - alpha) * baseline.variance + alpha * diff * diff
                baseline.count += 1
                baselines[key] = baseline
            }
        }
    }

    private func calculateEnergy(_ f: [String: Double]) -> Float {
        let sr = personalizedScore(FeatureKeys.speechRate, f)
        let f0v = personalizedScore(FeatureKeys.f0StdDev, f)
        let ar = personalizedScore(FeatureKeys.articulationRate, f)
        let dr = personalizedScore(FeatureKeys.loudnessDynamicRangeOriginal, f)
        return sr * 0.30 + f0v * 0.25 + ar * 0.20 + dr * 0.25
    }

    private func calculateTension(_ f: [String: Double]) -> Float {
        let j = personalizedScore(FeatureKeys.jitter, f)
        let sh = personalizedScore(FeatureKeys.shimmer, f)
        let hnr = 1.0 - personalizedScore(FeatureKeys.hnr, f)
        let pd = 1.0 - personalizedScore(FeatureKeys.pauseDuration, f)
        let sr = personalizedScore(FeatureKeys.speechRate, f)
        return j * 0.25 + sh * 0.20 + hnr * 0.20 + pd * 0.15 + sr * 0.20
    }

    private func calculateFatigue(_ f: [String: Double]) -> Float {
        let fr = 1.0 - personalizedScore(FeatureKeys.f0RangeST, f)
        let sr = 1.0 - personalizedScore(FeatureKeys.speechRate, f)
        let pd = personalizedScore(FeatureKeys.pauseDuration, f)
        let sh = personalizedScore(FeatureKeys.shimmer, f)
        let dr = 1.0 - personalizedScore(FeatureKeys.loudnessDynamicRangeOriginal, f)
        return fr * 0.25 + sr * 0.25 + pd * 0.20 + sh * 0.15 + dr * 0.15
    }

    private func calculateWarmth(_ f: [String: Double]) -> Float {
        let hnr = personalizedScore(FeatureKeys.hnr, f)
        let sh = 1.0 - personalizedScore(FeatureKeys.shimmer, f)
        let sw = personalizedScore("spectralWarmthRatio", f)
        return hnr * 0.40 + sh * 0.30 + sw * 0.30
    }

    private func calculateExpressiveness(_ f: [String: Double]) -> Float {
        let fr = personalizedScore(FeatureKeys.f0RangeST, f)
        let fv = personalizedScore(FeatureKeys.f0StdDev, f)
        let dr = personalizedScore(FeatureKeys.loudnessDynamicRangeOriginal, f)
        let pd = 1.0 - personalizedScore(FeatureKeys.pauseDuration, f)
        return fr * 0.35 + fv * 0.30 + dr * 0.20 + pd * 0.15
    }

    private func calculateTempo(_ f: [String: Double]) -> Float {
        personalizedScore(FeatureKeys.speechRate, f)
    }

    private func personalizedScore(_ feature: String, _ features: [String: Double]) -> Float {
        guard let value = floatValue(features, feature),
              let profile = featureProfiles[feature] else {
            return fallbackScore(feature, features)
        }
        guard profile.high > profile.low else { return 0.5 }
        let score = (value - profile.low) / (profile.high - profile.low)
        return clamp(score)
    }

    private func fallbackScore(_ feature: String, _ features: [String: Double]) -> Float {
        guard let value = floatValue(features, feature) else { return 0.5 }
        let ranges: [String: (Float, Float)] = [
            FeatureKeys.f0Mean: (80, 250),
            FeatureKeys.f0RangeST: (2, 10),
            FeatureKeys.f0StdDev: (4, 18),
            FeatureKeys.jitter: (0.01, 0.05),
            FeatureKeys.shimmer: (0.08, 0.25),
            FeatureKeys.hnr: (1.5, 8),
            FeatureKeys.speechRate: (2.5, 6.5),
            FeatureKeys.articulationRate: (4, 9),
            FeatureKeys.pauseRate: (5, 40),
            FeatureKeys.pauseDuration: (0.2, 1.0),
            FeatureKeys.loudnessRMSOriginal: (0.005, 0.1),
            FeatureKeys.loudnessDynamicRangeOriginal: (15, 40),
            FeatureKeys.loudnessStdDevOriginal: (0.003, 0.06),
            FeatureKeys.formantDispersion: (400, 1200),
            "spectralWarmthRatio": (0.3, 0.7),
            "spectralPresenceRatio": (0.003, 0.12),
        ]
        guard let (low, high) = ranges[feature], high > low else { return 0.5 }
        return clamp((value - low) / (high - low))
    }

    private func flagDescription(feature: String, zScore: Float) -> String {
        let intensity = abs(zScore) > 2.0 ? "deutlich" : "merklich"
        switch feature {
        case FeatureKeys.jitter:
            return zScore > 0 ? "Stimme zittert \(intensity) mehr als gewoehnlich" : "Stimme stabiler als gewoehnlich"
        case FeatureKeys.shimmer:
            return zScore > 0 ? "Stimme schwankt \(intensity) mehr" : "Stimme gleichmaessiger als sonst"
        case FeatureKeys.hnr:
            return zScore > 0 ? "Stimme klingt klarer als sonst" : "Stimme klingt rauer als sonst"
        case FeatureKeys.speechRate:
            return zScore > 0 ? "Sprichst \(intensity) schneller als sonst" : "Sprichst \(intensity) langsamer als sonst"
        case FeatureKeys.f0RangeST:
            return zScore > 0 ? "Mehr Melodie als sonst" : "Monotoner als sonst"
        case FeatureKeys.pauseDuration:
            return zScore > 0 ? "Laengere Pausen als sonst" : "Weniger Pausen als sonst"
        case FeatureKeys.loudnessDynamicRangeOriginal:
            return zScore > 0 ? "Mehr Dynamik als sonst" : "Flacher als sonst"
        case FeatureKeys.f0StdDev:
            return zScore > 0 ? "Mehr Tonhoehenvariation als sonst" : "Gleichfoermiger als sonst"
        default:
            return "\(feature) \(intensity) anders als normal"
        }
    }

    func save() {
        let data = CalibrationStorage(
            profiles: featureProfiles,
            baselines: baselines,
            entryCount: entryCount
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "kluna_calibration")
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: "kluna_calibration"),
              let decoded = try? JSONDecoder().decode(CalibrationStorage.self, from: data) else {
            return
        }
        featureProfiles = decoded.profiles
        baselines = decoded.baselines
        entryCount = decoded.entryCount
        isCalibrated = entryCount > 0
    }

    private func floatValue(_ features: [String: Double], _ key: String) -> Float? {
        if let value = features[key] { return Float(value) }
        if key == FeatureKeys.pauseDuration, let value = features[FeatureKeys.meanPauseDuration] { return Float(value) }
        if key == FeatureKeys.loudnessRMSOriginal {
            if let value = features[FeatureKeys.loudnessRMSOriginal] { return Float(value) }
            if let value = features[FeatureKeys.loudnessRMS] { return Float(value) }
            if let value = features[FeatureKeys.loudness] { return Float(value) }
        }
        if key == FeatureKeys.loudnessDynamicRangeOriginal {
            if let value = features[FeatureKeys.loudnessDynamicRangeOriginal] { return Float(value) }
            if let value = features[FeatureKeys.loudnessDynamicRange] { return Float(value) }
        }
        if key == FeatureKeys.loudnessStdDevOriginal {
            if let value = features[FeatureKeys.loudnessStdDevOriginal] { return Float(value) }
            if let value = features[FeatureKeys.loudnessStdDev] { return Float(value) }
        }
        return nil
    }

    private func clamp(_ value: Float) -> Float {
        clamp(value, min: 0, max: 1)
    }

    private func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.max(min, Swift.min(max, value))
    }

    private func printCalibrationSummary(_ features: [String: Double]) {
        print("🎯 -- Calibration Summary (Entry #\(entryCount)) --")
        for key in [FeatureKeys.f0Mean, FeatureKeys.speechRate, FeatureKeys.hnr, FeatureKeys.jitter, FeatureKeys.f0RangeST] {
            if let profile = featureProfiles[key], let value = floatValue(features, key) {
                print(
                    "🎯 \(key): value=\(String(format: "%.2f", value)) center=\(String(format: "%.2f", profile.center)) range=[\(String(format: "%.2f", profile.low))-\(String(format: "%.2f", profile.high))]"
                )
            }
        }
        let phase = entryCount == 1 ? "Initial" : (entryCount <= 10 ? "Learning (a=0.3)" : "Stable (a=0.1)")
        print("🎯 -- Phase: \(phase) --")
    }
}

struct CalibrationStorage: Codable {
    let profiles: [String: PersonalCalibration.FeatureProfile]
    let baselines: [String: PersonalCalibration.EWMABaseline]
    let entryCount: Int
}

struct CalibrationResult {
    let zScores: [String: Float]
    let deltas: [String: Float]
    let flags: [CalibrationFlag]
    let phase: CalibrationPhase
}

struct CalibrationFlag {
    let feature: String
    let zScore: Float
    let description: String
}

enum CalibrationPhase: Equatable {
    case initial
    case learning
    case stable
}
