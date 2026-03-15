import Foundation
import Accelerate

struct SpectralBandResult: Codable {
    let warmthEnergy: Float
    let bodyEnergy: Float
    let presenceEnergy: Float
    let airEnergy: Float

    let warmthToPresenceRatio: Float
    let bodyToTotalRatio: Float
    let presenceToTotalRatio: Float
    let spectralBalance: Float

    let warmthScore: Float
    let bodyScore: Float
    let presenceScore: Float
    let airScore: Float
    let overallTimbreScore: Float
}

extension SpectralBandResult {
    static var zero: SpectralBandResult {
        SpectralBandResult(
            warmthEnergy: -100,
            bodyEnergy: -100,
            presenceEnergy: -100,
            airEnergy: -100,
            warmthToPresenceRatio: 0,
            bodyToTotalRatio: 0,
            presenceToTotalRatio: 0,
            spectralBalance: 0,
            warmthScore: 0,
            bodyScore: 0,
            presenceScore: 0,
            airScore: 0,
            overallTimbreScore: 0
        )
    }

    static func mean(of results: [SpectralBandResult]) -> SpectralBandResult {
        guard !results.isEmpty else { return .zero }
        let n = Float(results.count)
        return SpectralBandResult(
            warmthEnergy: results.map(\.warmthEnergy).reduce(0, +) / n,
            bodyEnergy: results.map(\.bodyEnergy).reduce(0, +) / n,
            presenceEnergy: results.map(\.presenceEnergy).reduce(0, +) / n,
            airEnergy: results.map(\.airEnergy).reduce(0, +) / n,
            warmthToPresenceRatio: results.map(\.warmthToPresenceRatio).reduce(0, +) / n,
            bodyToTotalRatio: results.map(\.bodyToTotalRatio).reduce(0, +) / n,
            presenceToTotalRatio: results.map(\.presenceToTotalRatio).reduce(0, +) / n,
            spectralBalance: results.map(\.spectralBalance).reduce(0, +) / n,
            warmthScore: results.map(\.warmthScore).reduce(0, +) / n,
            bodyScore: results.map(\.bodyScore).reduce(0, +) / n,
            presenceScore: results.map(\.presenceScore).reduce(0, +) / n,
            airScore: results.map(\.airScore).reduce(0, +) / n,
            overallTimbreScore: results.map(\.overallTimbreScore).reduce(0, +) / n
        )
    }
}

final class SpectralBandAnalyzer {
    private let fftSize: Int = 2048
    private let hopSize: Int = 512

    private let bodyLow: Float = 80
    private let bodyHigh: Float = 200
    private let warmthLow: Float = 200
    private let warmthHigh: Float = 500
    private let presenceLow: Float = 2000
    private let presenceHigh: Float = 5000
    private let airLow: Float = 6000
    private let airHigh: Float = 7500

    func analyze(samples: [Float], sampleRate: Float = 16000.0) -> SpectralBandResult {
        guard samples.count >= fftSize else { return emptyResult() }

        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return emptyResult()
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        let halfN = fftSize / 2
        let binResolution = sampleRate / Float(fftSize)

        let bodyBinLow = Int(bodyLow / binResolution)
        let bodyBinHigh = Int(bodyHigh / binResolution)
        let warmthBinLow = Int(warmthLow / binResolution)
        let warmthBinHigh = Int(warmthHigh / binResolution)
        let presenceBinLow = Int(presenceLow / binResolution)
        let presenceBinHigh = min(halfN - 1, Int(presenceHigh / binResolution))
        let airBinLow = Int(airLow / binResolution)
        let airBinHigh = min(halfN - 1, Int(airHigh / binResolution))

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var totalBodyEnergy: Double = 0
        var totalWarmthEnergy: Double = 0
        var totalPresenceEnergy: Double = 0
        var totalAirEnergy: Double = 0
        var totalEnergy: Double = 0
        var frameCount = 0

        var windowedFrame = [Float](repeating: 0, count: fftSize)
        var realp = [Float](repeating: 0, count: halfN)
        var imagp = [Float](repeating: 0, count: halfN)
        var magnitudes = [Float](repeating: 0, count: halfN)

        var offset = 0
        while offset + fftSize <= samples.count {
            let frame = Array(samples[offset..<(offset + fftSize)])
            vDSP_vmul(frame, 1, window, 1, &windowedFrame, 1, vDSP_Length(fftSize))

            windowedFrame.withUnsafeBufferPointer { bufferPtr in
                bufferPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                    var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfN))
                }
            }

            var scale = Float(1.0 / Float(fftSize * fftSize))
            vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfN))

            let bodyE = bandEnergy(magnitudes: magnitudes, fromBin: bodyBinLow, toBin: bodyBinHigh)
            let warmthE = bandEnergy(magnitudes: magnitudes, fromBin: warmthBinLow, toBin: warmthBinHigh)
            let presenceE = bandEnergy(magnitudes: magnitudes, fromBin: presenceBinLow, toBin: presenceBinHigh)
            let airE = bandEnergy(magnitudes: magnitudes, fromBin: airBinLow, toBin: airBinHigh)
            let fullE = bandEnergy(magnitudes: magnitudes, fromBin: 1, toBin: halfN - 1)

            if fullE > 1e-10 {
                totalBodyEnergy += Double(bodyE)
                totalWarmthEnergy += Double(warmthE)
                totalPresenceEnergy += Double(presenceE)
                totalAirEnergy += Double(airE)
                totalEnergy += Double(fullE)
                frameCount += 1
            }

            offset += hopSize
        }

        guard frameCount > 0, totalEnergy > 0 else { return emptyResult() }

        let avgBody = Float(totalBodyEnergy / Double(frameCount))
        let avgWarmth = Float(totalWarmthEnergy / Double(frameCount))
        let avgPresence = Float(totalPresenceEnergy / Double(frameCount))
        let avgAir = Float(totalAirEnergy / Double(frameCount))
        let avgTotal = Float(totalEnergy / Double(frameCount))

        let bodyDB = 10 * log10(max(avgBody, 1e-20))
        let warmthDB = 10 * log10(max(avgWarmth, 1e-20))
        let presenceDB = 10 * log10(max(avgPresence, 1e-20))
        let airDB = 10 * log10(max(avgAir, 1e-20))

        let warmthToPresence = avgWarmth / max(avgPresence, 1e-20)
        let bodyToTotal = avgBody / max(avgTotal, 1e-20)
        let presenceToTotal = avgPresence / max(avgTotal, 1e-20)

        let ratios = [bodyToTotal, avgWarmth / max(avgTotal, 1e-20), presenceToTotal, avgAir / max(avgTotal, 1e-20)]
        let idealRatio: Float = 0.25
        let deviation = ratios.map { abs($0 - idealRatio) }.reduce(0, +) / 4
        var balance = max(0, min(100, (1 - deviation * 4) * 100))

        let bodyRatio = avgBody / max(avgTotal, 1e-20)
        let warmthRatio = avgWarmth / max(avgTotal, 1e-20)
        let presenceRatio = avgPresence / max(avgTotal, 1e-20)
        let airRatio = avgAir / max(avgTotal, 1e-20)

        let spectralNoiseFloor: Float = 0.000015
        var warmthScore: Float
        var bodyScore: Float
        var presenceScore: Float
        var airScore: Float
        var timbreScore: Float

        if avgTotal < spectralNoiseFloor {
            let floorScore: Float = 8.0
            bodyScore = floorScore
            warmthScore = floorScore
            presenceScore = floorScore
            airScore = floorScore
            balance = floorScore
            timbreScore = floorScore
            print("🔬 NOISE FLOOR: totalEnergy=\(avgTotal)")
        } else {
            warmthScore = calculateWarmthScore(
                warmthEnergy: avgWarmth,
                presenceEnergy: avgPresence,
                totalEnergy: avgTotal
            )
            bodyScore = calculateBodyScore(
                bodyEnergy: avgBody,
                warmthEnergy: avgWarmth,
                presenceEnergy: avgPresence,
                airEnergy: avgAir,
                totalEnergy: avgTotal
            )
            presenceScore = calculatePresenceScore(presenceEnergy: avgPresence, totalEnergy: avgTotal)
            airScore = calculateAirScore(ratio: airRatio)
            timbreScore = warmthScore * 0.30 + presenceScore * 0.30 + bodyScore * 0.25 + airScore * 0.15
            print("🔬 Spectral OK: totalEnergy=\(avgTotal)")
        }

        #if DEBUG
        print("🔬 SPECTRAL RAW ENERGIES:")
        print("🔬   Total: \(avgTotal)")
        print("🔬   Body (80-200Hz): \(avgBody) -> ratio: \(String(format: "%.6f", bodyRatio))")
        print("🔬   Warmth (200-500Hz): \(avgWarmth) -> ratio: \(String(format: "%.6f", warmthRatio))")
        print("🔬   Presence (2-5kHz): \(avgPresence) -> ratio: \(String(format: "%.6f", presenceRatio))")
        print("🔬   Air (6-7.5kHz): \(avgAir) -> ratio: \(String(format: "%.6f", airRatio))")
        print("🔬   Presence ratio=\(String(format: "%.6f", presenceRatio)) -> mapToScore(min=0.003, max=0.12) = \(presenceScore)")
        #endif

        return SpectralBandResult(
            warmthEnergy: warmthDB,
            bodyEnergy: bodyDB,
            presenceEnergy: presenceDB,
            airEnergy: airDB,
            warmthToPresenceRatio: warmthToPresence,
            bodyToTotalRatio: bodyToTotal,
            presenceToTotalRatio: presenceToTotal,
            spectralBalance: balance,
            warmthScore: warmthScore,
            bodyScore: bodyScore,
            presenceScore: presenceScore,
            airScore: airScore,
            overallTimbreScore: timbreScore
        )
    }

    static func audioDataToFloatSamples(_ data: Data) -> [Float] {
        let int16Count = data.count / 2
        var samples = [Float](repeating: 0, count: int16Count)
        data.withUnsafeBytes { rawBuffer in
            let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<int16Count {
                samples[i] = Float(int16Buffer[i]) / 32768.0
            }
        }
        return samples
    }

    static func applyGainNormalization(_ samples: [Float], targetPeak: Float = 0.5) -> [Float] {
        guard !samples.isEmpty else { return samples }
        var maxAmp: Float = 0
        vDSP_maxmgv(samples, 1, &maxAmp, vDSP_Length(samples.count))
        guard maxAmp > 0.001 else { return samples }

        let gain = min(20.0, targetPeak / maxAmp)
        guard gain > 1.1 else { return samples }

        var result = [Float](repeating: 0, count: samples.count)
        var gainVar = gain
        vDSP_vsmul(samples, 1, &gainVar, &result, 1, vDSP_Length(samples.count))
        return result
    }

    private func bandEnergy(magnitudes: [Float], fromBin: Int, toBin: Int) -> Float {
        guard fromBin < toBin, fromBin >= 0, toBin < magnitudes.count else { return 0 }
        var sum: Float = 0
        vDSP_sve(Array(magnitudes[fromBin...toBin]), 1, &sum, vDSP_Length(toBin - fromBin + 1))
        return sum
    }

    private func calculateWarmthScore(
        warmthEnergy: Float,
        presenceEnergy: Float,
        totalEnergy: Float
    ) -> Float {
        guard totalEnergy > 0 else { return 0 }
        let warmthRatio = warmthEnergy / totalEnergy
        let presenceRatio = presenceEnergy / totalEnergy
        let rawWarmthScore = mapToScore(warmthRatio, min: 0.05, max: 0.70)
        let presenceFloor: Float = 0.05
        let presencePenalty: Float
        if presenceRatio < presenceFloor {
            presencePenalty = 0.5 + (presenceRatio / presenceFloor) * 0.5
        } else {
            presencePenalty = 1.0
        }
        return max(0, min(100, rawWarmthScore * presencePenalty))
    }

    private func calculateBodyScore(
        bodyEnergy: Float,
        warmthEnergy: Float,
        presenceEnergy: Float,
        airEnergy: Float,
        totalEnergy: Float
    ) -> Float {
        let _ = warmthEnergy
        let _ = airEnergy
        guard totalEnergy > 0 else { return 0 }
        let bodyRatio = bodyEnergy / totalEnergy
        let presenceRatio = presenceEnergy / totalEnergy
        let rawBodyScore = mapToScore(bodyRatio, min: 0.08, max: 0.45)
        let presenceFloor: Float = 0.05
        let presencePenalty: Float
        if presenceRatio < presenceFloor {
            presencePenalty = 0.3 + (presenceRatio / presenceFloor) * 0.7
        } else {
            presencePenalty = 1.0
        }
        return max(0, min(100, rawBodyScore * presencePenalty))
    }

    private func calculatePresenceScore(presenceEnergy: Float, totalEnergy: Float) -> Float {
        guard totalEnergy > 0 else { return 0 }
        let ratio = presenceEnergy / totalEnergy
        return mapToScore(ratio, min: 0.002, max: 0.018)
    }

    private func calculateAirScore(ratio: Float) -> Float {
        mapToScore(ratio, min: 0.000005, max: 0.0002)
    }

    private func mapToScore(_ value: Float, min: Float, max: Float) -> Float {
        guard max > min else { return 0 }
        let clamped = Swift.max(min, Swift.min(max, value))
        return ((clamped - min) / (max - min)) * 100
    }

    private func emptyResult() -> SpectralBandResult {
        .zero
    }
}
