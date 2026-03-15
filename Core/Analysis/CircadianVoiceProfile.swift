import Foundation

struct CircadianSlot {
    let hourRange: String
    let avgOverall: Double
    let avgConfidence: Double
    let avgEnergy: Double
    let avgCharisma: Double
    let sessionCount: Int
    let isOptimal: Bool
}

struct CircadianProfile {
    let slots: [CircadianSlot]
    let optimalHourRange: String?
    let worstHourRange: String?
    let totalSessionsAnalyzed: Int
    let isReady: Bool

    var recommendation: String? {
        guard isReady, let best = optimalHourRange, let worst = worstHourRange else { return nil }
        return "Dein Stimm-Peak liegt zwischen \(best) Uhr. Vermeide wichtige Gespraeche \(worst) Uhr."
    }
}

enum CircadianVoiceAnalyzer {
    private static let minSessionsPerSlot = 3
    private static let minTotalSessions = 20

    static func analyze(logs: [SessionFeatureLog]) -> CircadianProfile {
        guard logs.count >= minTotalSessions else {
            return CircadianProfile(
                slots: [],
                optimalHourRange: nil,
                worstHourRange: nil,
                totalSessionsAnalyzed: logs.count,
                isReady: false
            )
        }

        let slotDefinitions: [(range: String, hours: Range<Int>)] = [
            ("06-08", 6..<8), ("08-10", 8..<10), ("10-12", 10..<12), ("12-14", 12..<14),
            ("14-16", 14..<16), ("16-18", 16..<18), ("18-20", 18..<20), ("20-22", 20..<22)
        ]

        let formatter = ISO8601DateFormatter()
        let calendar = Calendar.current
        var slotData: [String: [SessionFeatureLog]] = Dictionary(uniqueKeysWithValues: slotDefinitions.map { ($0.range, []) })

        for log in logs {
            guard let date = formatter.date(from: log.timestamp) else { continue }
            let hour = calendar.component(.hour, from: date)
            if let slot = slotDefinitions.first(where: { $0.hours.contains(hour) }) {
                slotData[slot.range, default: []].append(log)
            }
        }

        var slots: [CircadianSlot] = []
        var best: (String, Double)? = nil
        var worst: (String, Double)? = nil

        for def in slotDefinitions {
            let sessionLogs = slotData[def.range] ?? []
            guard sessionLogs.count >= minSessionsPerSlot else { continue }
            let avgOverall = sessionLogs.compactMap(\.scoreOverall).average()
            let avgConfidence = sessionLogs.compactMap(\.scoreConfidence).average()
            let avgEnergy = sessionLogs.compactMap(\.scoreEnergy).average()
            let avgCharisma = sessionLogs.compactMap(\.scoreCharisma).average()
            let slot = CircadianSlot(
                hourRange: def.range,
                avgOverall: avgOverall,
                avgConfidence: avgConfidence,
                avgEnergy: avgEnergy,
                avgCharisma: avgCharisma,
                sessionCount: sessionLogs.count,
                isOptimal: false
            )
            slots.append(slot)

            if best == nil || avgOverall > best!.1 { best = (def.range, avgOverall) }
            if worst == nil || avgOverall < worst!.1 { worst = (def.range, avgOverall) }
        }

        let marked = slots.map {
            CircadianSlot(
                hourRange: $0.hourRange,
                avgOverall: $0.avgOverall,
                avgConfidence: $0.avgConfidence,
                avgEnergy: $0.avgEnergy,
                avgCharisma: $0.avgCharisma,
                sessionCount: $0.sessionCount,
                isOptimal: $0.hourRange == best?.0
            )
        }

        let hasEnoughSlots = marked.filter { $0.sessionCount >= minSessionsPerSlot }.count >= 3
        return CircadianProfile(
            slots: marked,
            optimalHourRange: hasEnoughSlots ? best?.0 : nil,
            worstHourRange: hasEnoughSlots ? worst?.0 : nil,
            totalSessionsAnalyzed: logs.count,
            isReady: hasEnoughSlots
        )
    }
}

private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
