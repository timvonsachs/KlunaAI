import Foundation

struct MelodicContourAnalysis: Codable {
    let hatPatternCount: Int
    let hatPatternScore: Double
    let downstepPresent: Bool
    let downstepStrength: Double
    let finalLoweringPresent: Bool
    let finalLoweringStrength: Double
    let emphasisCorrelation: Double
    let emphasisCount: Int
    let emphasisRegularity: Double
    let intentionalityScore: Double

    var description: String {
        var parts: [String] = []
        if hatPatternCount >= 3 {
            parts.append("\(hatPatternCount) klare Betonungsmuster erkannt")
        } else if hatPatternCount >= 1 {
            parts.append("Wenige Betonungsmuster (\(hatPatternCount))")
        } else {
            parts.append("Keine klaren Betonungsmuster")
        }

        if finalLoweringPresent {
            parts.append("Stimme senkt sich am Ende (wirkt sicher)")
        } else {
            parts.append("Stimme bleibt am Ende oben (wirkt fragend)")
        }

        if emphasisCorrelation > 0.3 {
            parts.append("Betonungen sind bewusst und kontrolliert")
        } else if emphasisCorrelation < 0 {
            parts.append("Tonhöhe und Lautstärke arbeiten gegeneinander")
        }

        return parts.joined(separator: ". ") + "."
    }
}

final class MelodicContourAnalyzer {
    static func analyze(
        f0Contour: [Double],
        loudnessContour: [Double],
        frameDuration: Double = 0.010
    ) -> MelodicContourAnalysis {
        let frameCount = min(f0Contour.count, loudnessContour.count)
        guard frameCount >= 50 else {
            return MelodicContourAnalysis(
                hatPatternCount: 0, hatPatternScore: 0,
                downstepPresent: false, downstepStrength: 0,
                finalLoweringPresent: false, finalLoweringStrength: 0,
                emphasisCorrelation: 0, emphasisCount: 0, emphasisRegularity: 0,
                intentionalityScore: 20
            )
        }

        let f0 = Array(f0Contour.prefix(frameCount))
        let loudness = Array(loudnessContour.prefix(frameCount))
        let voicedF0 = f0.filter { $0 > 0 }
        guard !voicedF0.isEmpty else {
            return MelodicContourAnalysis(
                hatPatternCount: 0, hatPatternScore: 0,
                downstepPresent: false, downstepStrength: 0,
                finalLoweringPresent: false, finalLoweringStrength: 0,
                emphasisCorrelation: 0, emphasisCount: 0, emphasisRegularity: 0,
                intentionalityScore: 10
            )
        }

        let meanF0 = voicedF0.reduce(0, +) / Double(voicedF0.count)
        let hatResult = detectHatPatterns(f0: f0, meanF0: meanF0, frameDuration: frameDuration)
        let downstepResult = detectDownstep(f0: f0)
        let finalResult = detectFinalLowering(f0: f0, meanF0: meanF0)
        let emphasisResult = detectEmphasis(f0: f0, loudness: loudness, frameDuration: frameDuration)

        let intentionality = calculateIntentionality(
            hatScore: hatResult.score,
            downstepStrength: downstepResult.strength,
            finalLoweringStrength: finalResult.strength,
            emphasisCorrelation: emphasisResult.correlation,
            emphasisRegularity: emphasisResult.regularity
        )

        return MelodicContourAnalysis(
            hatPatternCount: hatResult.count,
            hatPatternScore: hatResult.score,
            downstepPresent: downstepResult.present,
            downstepStrength: downstepResult.strength,
            finalLoweringPresent: finalResult.present,
            finalLoweringStrength: finalResult.strength,
            emphasisCorrelation: emphasisResult.correlation,
            emphasisCount: emphasisResult.count,
            emphasisRegularity: emphasisResult.regularity,
            intentionalityScore: intentionality
        )
    }

    private struct HatPatternResult { let count: Int; let score: Double }
    private static func detectHatPatterns(f0: [Double], meanF0: Double, frameDuration: Double) -> HatPatternResult {
        let smoothed = movingAverage(f0, window: 5)
        let regions = findVoicedRegions(smoothed, minLength: 10)
        var count = 0
        var qualitySum = 0.0

        for region in regions {
            let segment = Array(smoothed[region])
            guard segment.count >= 5 else { continue }
            for i in 2..<(segment.count - 2) {
                guard segment[i] > 0 else { continue }
                let isPeak = segment[i] > segment[i - 1]
                    && segment[i] > segment[i - 2]
                    && segment[i] > segment[i + 1]
                    && segment[i] > segment[i + 2]
                let peakProminence = (segment[i] - meanF0) / max(1e-6, meanF0)
                if isPeak && peakProminence > 0.05 {
                    let hasRise = segment[i] > segment[max(0, i - 3)] * 1.03
                    let hasFall = segment[i] > segment[min(segment.count - 1, i + 3)] * 1.03
                    if hasRise && hasFall {
                        count += 1
                        qualitySum += min(1.0, peakProminence * 5.0)
                    }
                }
            }
        }

        let durationMinutes = Double(f0.count) * frameDuration / 60.0
        let ppm = durationMinutes > 0 ? Double(count) / durationMinutes : 0
        let countScore: Double
        if ppm >= 3 && ppm <= 8 {
            countScore = 80 + (1 - abs(ppm - 5.5) / 2.5) * 20
        } else if ppm >= 1 {
            countScore = 30 + min(50, ppm * 10)
        } else {
            countScore = 10
        }
        let qualityScore = count > 0 ? (qualitySum / Double(count)) * 100 : 0
        return HatPatternResult(count: count, score: min(100, countScore * 0.6 + qualityScore * 0.4))
    }

    private struct DownstepResult { let present: Bool; let strength: Double }
    private static func detectDownstep(f0: [Double]) -> DownstepResult {
        let phrases = findVoicedRegions(f0, minLength: 20)
        guard phrases.count >= 3 else { return DownstepResult(present: false, strength: 0) }
        var starts: [Double] = []
        for phrase in phrases {
            let values = Array(f0[phrase]).prefix(5).filter { $0 > 0 }
            if !values.isEmpty {
                starts.append(values.reduce(0, +) / Double(values.count))
            }
        }
        guard starts.count >= 3 else { return DownstepResult(present: false, strength: 0) }
        let slope = linearRegressionSlope(starts)
        let strength: Double
        if slope < -2 { strength = 90 }
        else if slope < -1 { strength = 70 }
        else if slope < -0.5 { strength = 50 }
        else if slope < 0 { strength = 25 }
        else { strength = 0 }
        return DownstepResult(present: slope < -0.5, strength: strength)
    }

    private struct FinalLoweringResult { let present: Bool; let strength: Double }
    private static func detectFinalLowering(f0: [Double], meanF0: Double) -> FinalLoweringResult {
        guard f0.count >= 30 else { return FinalLoweringResult(present: false, strength: 0) }
        let third = f0.count / 3
        let middle = Array(f0[third..<(third * 2)]).filter { $0 > 0 }
        let last = Array(f0[(third * 2)...]).filter { $0 > 0 }
        guard !middle.isEmpty && !last.isEmpty else { return FinalLoweringResult(present: false, strength: 0) }
        let middleMean = middle.reduce(0, +) / Double(middle.count)
        let lastMean = last.reduce(0, +) / Double(last.count)
        let percentDrop = (middleMean - lastMean) / max(1e-6, meanF0) * 100
        let isPresent = percentDrop > 1.0
        var strength: Double
        if percentDrop > 5 { strength = 90 }
        else if percentDrop > 3 { strength = 70 }
        else if percentDrop > 1 { strength = 50 }
        else if percentDrop > 0 { strength = 20 }
        else { strength = 0 }

        let tailCount = min(50, last.count)
        if tailCount >= 5 {
            let veryLast = Array(last.suffix(tailCount))
            let veryLastMean = veryLast.reduce(0, +) / Double(veryLast.count)
            if veryLastMean < lastMean * 0.97 {
                return FinalLoweringResult(present: true, strength: min(100, strength + 15))
            }
        }
        return FinalLoweringResult(present: isPresent, strength: strength)
    }

    private struct EmphasisResult { let correlation: Double; let count: Int; let regularity: Double }
    private static func detectEmphasis(f0: [Double], loudness: [Double], frameDuration: Double) -> EmphasisResult {
        let frameCount = min(f0.count, loudness.count)
        var f0v: [Double] = []
        var lv: [Double] = []
        for i in 0..<frameCount where f0[i] > 0 && loudness[i] > 0 {
            f0v.append(f0[i]); lv.append(loudness[i])
        }
        guard f0v.count >= 20 else { return EmphasisResult(correlation: 0, count: 0, regularity: 0) }
        let corr = pearsonCorrelation(f0v, lv)

        let f0Smooth = movingAverage(f0, window: 15)
        let loudSmooth = movingAverage(loudness, window: 15)
        let minPeakDistance = Int(0.3 / frameDuration)
        var lastPeak = -minPeakDistance
        var peaks: [Int] = []
        for i in 0..<frameCount where f0[i] > 0 && loudness[i] > 0 {
            let f0Above = f0[i] > f0Smooth[i] * 1.05
            let lAbove = loudness[i] > loudSmooth[i] * 1.08
            if f0Above && lAbove && (i - lastPeak) >= minPeakDistance {
                peaks.append(i)
                lastPeak = i
            }
        }
        return EmphasisResult(correlation: corr, count: peaks.count, regularity: calculatePeakRegularity(peaks: peaks))
    }

    private static func calculateIntentionality(
        hatScore: Double,
        downstepStrength: Double,
        finalLoweringStrength: Double,
        emphasisCorrelation: Double,
        emphasisRegularity: Double
    ) -> Double {
        let correlationScore: Double
        if emphasisCorrelation > 0.4 { correlationScore = 80 + (emphasisCorrelation - 0.4) * 33.3 }
        else if emphasisCorrelation > 0.2 { correlationScore = 50 + (emphasisCorrelation - 0.2) * 150 }
        else if emphasisCorrelation > 0 { correlationScore = 20 + emphasisCorrelation * 150 }
        else { correlationScore = max(0, 20 + emphasisCorrelation * 40) }

        let total = hatScore * 0.25
            + correlationScore * 0.25
            + emphasisRegularity * 0.15
            + downstepStrength * 0.15
            + finalLoweringStrength * 0.20
        return min(100, max(0, total))
    }

    private static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard values.count >= window else { return values }
        var result = [Double](repeating: 0, count: values.count)
        let half = window / 2
        for i in 0..<values.count {
            let start = max(0, i - half)
            let end = min(values.count - 1, i + half)
            var sum = 0.0
            var count = 0
            for j in start...end where values[j] > 0 {
                sum += values[j]
                count += 1
            }
            result[i] = count > 0 ? sum / Double(count) : 0
        }
        return result
    }

    private static func findVoicedRegions(_ f0: [Double], minLength: Int) -> [Range<Int>] {
        var regions: [Range<Int>] = []
        var start: Int?
        for i in 0..<f0.count {
            if f0[i] > 0 {
                if start == nil { start = i }
            } else if let s = start {
                if i - s >= minLength { regions.append(s..<i) }
                start = nil
            }
        }
        if let s = start, f0.count - s >= minLength { regions.append(s..<f0.count) }
        return regions
    }

    private static func pearsonCorrelation(_ x: [Double], _ y: [Double]) -> Double {
        let n = min(x.count, y.count)
        guard n > 1 else { return 0 }
        let nx = Double(n)
        let meanX = x.prefix(n).reduce(0, +) / nx
        let meanY = y.prefix(n).reduce(0, +) / nx
        var num = 0.0
        var denX = 0.0
        var denY = 0.0
        for i in 0..<n {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            num += dx * dy
            denX += dx * dx
            denY += dy * dy
        }
        let den = sqrt(denX * denY)
        return den > 0 ? num / den : 0
    }

    private static func calculatePeakRegularity(peaks: [Int]) -> Double {
        guard peaks.count >= 2 else { return 0 }
        var distances: [Double] = []
        for i in 1..<peaks.count {
            distances.append(Double(peaks[i] - peaks[i - 1]))
        }
        let mean = distances.reduce(0, +) / Double(distances.count)
        guard mean > 0 else { return 0 }
        let variance = distances.map { pow($0 - mean, 2) }.reduce(0, +) / Double(distances.count)
        let cv = sqrt(variance) / mean
        return max(0, min(100, (1 - cv) * 100))
    }

    private static func linearRegressionSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0 }
        var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0
        for i in 0..<values.count {
            let x = Double(i)
            let y = values[i]
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }
        let den = n * sumX2 - sumX * sumX
        guard den != 0 else { return 0 }
        return (n * sumXY - sumX * sumY) / den
    }
}
