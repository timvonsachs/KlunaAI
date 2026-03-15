import Foundation

final class OpenSMILEExtractor {
    private let bridge: OpenSMILEBridge
    static let outputKeys: Set<String> = FeatureKeys.canonical

    init(configPath: String? = nil) {
        if let configPath {
            bridge = OpenSMILEBridge(config: configPath)
        } else {
            bridge = OpenSMILEBridge(config: "")
        }
    }

    func extractFeatures(from audioData: Data, sampleRate: Double) -> VoiceFeatures? {
        guard let result = bridge.extractFeatures(fromPCMData: audioData, sampleRate: sampleRate) else { return nil }
        print("🔬 ====== OpenSMILE OUTPUT ======")
        print("🔬 Total features: \(result.count)")
        for (key, value) in result.sorted(by: { $0.key < $1.key }) {
            print("🔬 \(key) = \(value.doubleValue)")
        }
        print("🔬 ================================")
        return mapToVoiceFeatures(result)
    }

    func extractFeatures(from audioData: Data, sampleRate: Double,
                         startTime: TimeInterval, endTime: TimeInterval) -> VoiceFeatures? {
        guard let result = bridge.extractFeatures(
            fromPCMData: audioData,
            sampleRate: sampleRate,
            startTime: startTime,
            endTime: endTime
        ) else { return nil }
        print("🔬 ====== OpenSMILE SEGMENT OUTPUT ======")
        print("🔬 Range: \(startTime)s - \(endTime)s")
        print("🔬 Total features: \(result.count)")
        for (key, value) in result.sorted(by: { $0.key < $1.key }) {
            print("🔬 \(key) = \(value.doubleValue)")
        }
        print("🔬 ======================================")
        return mapToVoiceFeatures(result)
    }

    private func mapToVoiceFeatures(_ dict: [String: NSNumber]) -> VoiceFeatures? {
        guard !dict.isEmpty else { return nil }
        let g = { (k: String) -> Double in dict[k]?.doubleValue ?? 0 }
        var extended: [String: Double] = [:]
        for (key, value) in dict {
            extended[key] = value.doubleValue
        }
        return VoiceFeatures(
            f0Mean: g("F0Mean"),
            f0Variability: g("F0Var"),
            f0Range: g("F0Range"),
            jitter: g("Jitter"),
            shimmer: g("Shimmer"),
            speechRate: g("SpeechRate"),
            energy: g("Energy"),
            hnr: g("HNR"),
            f1: g("F1"),
            f2: g("F2"),
            f3: g("F3"),
            f4: g("F4"),
            pauseDuration: g("PauseDur"),
            pauseDistribution: g("PauseDist"),
            extended: extended
        )
    }
}
