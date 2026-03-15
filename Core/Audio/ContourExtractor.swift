import Foundation
import Accelerate

final class ContourExtractor {
    static func extractLoudnessContour(
        from pcmData: Data,
        sampleRate: Double,
        frameDuration: Double = 0.025,
        hopDuration: Double = 0.010
    ) -> [Double] {
        let frameSize = Int(sampleRate * frameDuration)
        let hopSize = Int(sampleRate * hopDuration)
        var samples = pcm16ToFloat(pcmData)
        normalizeIfNeeded(&samples)
        guard frameSize > 0, hopSize > 0, samples.count >= frameSize else { return [] }

        var contour: [Double] = []
        var offset = 0
        while offset + frameSize <= samples.count {
            var rms: Float = 0
            samples.withUnsafeBufferPointer { buffer in
                vDSP_rmsqv(buffer.baseAddress!.advanced(by: offset), 1, &rms, vDSP_Length(frameSize))
            }
            contour.append(Double(rms))
            offset += hopSize
        }
        return contour
    }

    static func extractF0Contour(
        from pcmData: Data,
        sampleRate: Double,
        frameDuration: Double = 0.025,
        hopDuration: Double = 0.010
    ) -> [Double] {
        let frameSize = Int(sampleRate * frameDuration)
        let hopSize = Int(sampleRate * hopDuration)
        let minF0 = 60.0
        let maxF0 = 400.0
        var samples = pcm16ToFloat(pcmData)
        normalizeIfNeeded(&samples)
        guard frameSize > 0, hopSize > 0, samples.count >= frameSize else { return [] }

        let minLag = max(1, Int(sampleRate / maxF0))
        let maxLag = min(Int(sampleRate / minF0), frameSize - 1)
        guard minLag < maxLag else { return [] }

        var contour: [Double] = []
        var offset = 0
        while offset + frameSize <= samples.count {
            let frame = Array(samples[offset..<(offset + frameSize)])
            let energy = frame.reduce(0 as Float) { $0 + $1 * $1 }
            if energy <= 1e-4 {
                contour.append(0)
                offset += hopSize
                continue
            }

            var bestLag = 0
            var bestCorr: Float = 0
            for lag in minLag...maxLag {
                var corr: Float = 0
                for i in 0..<(frameSize - lag) {
                    corr += frame[i] * frame[i + lag]
                }
                corr /= energy
                if corr > bestCorr {
                    bestCorr = corr
                    bestLag = lag
                }
            }

            if bestCorr > 0.3, bestLag > 0 {
                contour.append(sampleRate / Double(bestLag))
            } else {
                contour.append(0)
            }
            offset += hopSize
        }
        return contour
    }

    private static func pcm16ToFloat(_ pcmData: Data) -> [Float] {
        let count = pcmData.count / 2
        var samples = [Float](repeating: 0, count: count)
        pcmData.withUnsafeBytes { rawBuffer in
            let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<count {
                samples[i] = Float(int16Buffer[i]) / 32768.0
            }
        }
        return samples
    }

    private static func normalizeIfNeeded(_ samples: inout [Float]) {
        guard let maxAmp = samples.map({ abs($0) }).max(), maxAmp > 0.0001, maxAmp < 0.05 else { return }
        let gain = min(Float(20.0), Float(0.5) / maxAmp)
        for i in 0..<samples.count {
            samples[i] *= gain
        }
    }
}
