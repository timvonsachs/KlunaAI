#import "OpenSMILEBridge.h"
#import <Accelerate/Accelerate.h>
#include <algorithm>
#include <cmath>
#include <numeric>
#include <vector>

namespace AudioFeatures {

static constexpr float kPi = 3.14159265358979323846f;

static std::vector<float> pcm16ToFloat(const NSData *pcmData) {
    const auto sampleCount = pcmData.length / sizeof(int16_t);
    std::vector<float> samples(sampleCount, 0.0f);
    if (sampleCount == 0) { return samples; }
    const auto *raw = static_cast<const int16_t *>(pcmData.bytes);
    int maxSample = 0;
    for (NSUInteger i = 0; i < sampleCount; i++) {
        maxSample = std::max(maxSample, std::abs(static_cast<int>(raw[i])));
        samples[i] = static_cast<float>(raw[i]) / 32768.0f;
    }
    NSLog(@"🔬 PCM Debug: bytes=%lu, int16Samples=%lu, maxInt16=%d", (unsigned long)pcmData.length, (unsigned long)sampleCount, maxSample);

    if (maxSample < 100 && pcmData.length >= sizeof(float)) {
        const auto floatCount = pcmData.length / sizeof(float);
        const auto *floatRaw = static_cast<const float *>(pcmData.bytes);
        float maxFloat = 0.0f;
        for (NSUInteger i = 0; i < floatCount; i++) {
            maxFloat = std::max(maxFloat, std::fabs(floatRaw[i]));
        }
        NSLog(@"🔬 PCM Debug Float32 probe: samples=%lu, maxFloat=%.6f", (unsigned long)floatCount, maxFloat);
        if (maxFloat > 0.01f && maxFloat <= 1.5f) {
            NSLog(@"✅ Audio payload appears Float32. Using float interpretation.");
            std::vector<float> floatSamples(floatCount, 0.0f);
            for (NSUInteger i = 0; i < floatCount; i++) {
                floatSamples[i] = floatRaw[i];
            }
            return floatSamples;
        }
    }
    return samples;
}

static float computeRMS(const float *data, size_t length) {
    if (length == 0) { return 0.0f; }
    float sumSq = 0.0f;
    vDSP_svesq(data, 1, &sumSq, vDSP_Length(length));
    return std::sqrt(sumSq / static_cast<float>(length));
}

static float computeMean(const std::vector<float> &data) {
    if (data.empty()) { return 0.0f; }
    float sum = 0.0f;
    vDSP_sve(data.data(), 1, &sum, vDSP_Length(data.size()));
    return sum / static_cast<float>(data.size());
}

static float computeStdDev(const std::vector<float> &data) {
    if (data.size() < 2) { return 0.0f; }
    const float mean = computeMean(data);
    float sumSq = 0.0f;
    for (float value : data) {
        const float d = value - mean;
        sumSq += d * d;
    }
    return std::sqrt(sumSq / static_cast<float>(data.size() - 1));
}

static float hzToSemitones(float hz, float refHz = 1.0f) {
    if (hz <= 0.0f || refHz <= 0.0f) { return 0.0f; }
    return 12.0f * std::log2(hz / refHz);
}

struct F0Result {
    float meanF0 = 0.0f;
    float stdDevF0 = 0.0f;
    float rangeF0ST = 0.0f;
    std::vector<float> contour;
    std::vector<float> voicedFlags;
    std::vector<float> voicedF0;
};

static void filterIsolatedVoiced(std::vector<float> &f0Contour, std::vector<float> &voicedFlags, int minRun = 3) {
    if (f0Contour.empty() || voicedFlags.empty()) { return; }
    int runLength = 0;
    int runStart = 0;
    for (size_t i = 0; i <= voicedFlags.size(); i++) {
        const bool isVoiced = i < voicedFlags.size() && voicedFlags[i] > 0.5f && f0Contour[i] > 0.0f;
        if (isVoiced) {
            if (runLength == 0) { runStart = static_cast<int>(i); }
            runLength++;
            continue;
        }
        if (runLength > 0 && runLength < minRun) {
            for (int j = runStart; j < runStart + runLength; j++) {
                f0Contour[static_cast<size_t>(j)] = 0.0f;
                voicedFlags[static_cast<size_t>(j)] = 0.0f;
            }
        }
        runLength = 0;
    }
}

static void filterOctaveJumps(std::vector<float> &f0Contour, std::vector<float> &voicedFlags) {
    if (f0Contour.size() < 3 || voicedFlags.size() != f0Contour.size()) { return; }
    std::vector<float> voiced;
    voiced.reserve(f0Contour.size());
    for (size_t i = 0; i < f0Contour.size(); i++) {
        if (voicedFlags[i] > 0.5f && f0Contour[i] > 0.0f) {
            voiced.push_back(f0Contour[i]);
        }
    }
    if (voiced.empty()) { return; }
    std::sort(voiced.begin(), voiced.end());
    const float median = voiced[voiced.size() / 2];
    int corrected = 0;
    for (size_t i = 0; i < f0Contour.size(); i++) {
        if (voicedFlags[i] < 0.5f || f0Contour[i] <= 0.0f || median <= 0.0f) { continue; }
        const float ratio = f0Contour[i] / median;
        if (ratio > 1.7f && ratio < 2.3f) {
            f0Contour[i] *= 0.5f;
            corrected++;
        } else if (ratio > 0.35f && ratio < 0.6f) {
            f0Contour[i] *= 2.0f;
            corrected++;
        } else if (ratio > 1.35f && ratio < 1.65f) {
            // 3:2 confusion is a common weak-signal error.
            f0Contour[i] /= 1.5f;
            corrected++;
        } else if (ratio > 2.5f || ratio < 0.35f) {
            f0Contour[i] = 0.0f;
            voicedFlags[i] = 0.0f;
            corrected++;
        }
    }
    NSLog(@"🔬 F0 Octave Filter: median=%.1f Hz, corrected=%d", median, corrected);
}

static void medianSmoothF0(std::vector<float> &f0Contour, std::vector<float> &voicedFlags, int windowSize = 5) {
    if (f0Contour.size() < 3 || voicedFlags.size() != f0Contour.size()) { return; }
    const int halfWindow = windowSize / 2;
    std::vector<float> smoothed = f0Contour;
    for (size_t i = 0; i < f0Contour.size(); i++) {
        if (voicedFlags[i] < 0.5f || f0Contour[i] <= 0.0f) { continue; }
        std::vector<float> window;
        for (int j = -halfWindow; j <= halfWindow; j++) {
            const int idx = static_cast<int>(i) + j;
            if (idx >= 0 &&
                idx < static_cast<int>(f0Contour.size()) &&
                voicedFlags[static_cast<size_t>(idx)] > 0.5f &&
                f0Contour[static_cast<size_t>(idx)] > 0.0f) {
                window.push_back(f0Contour[static_cast<size_t>(idx)]);
            }
        }
        if (!window.empty()) {
            std::sort(window.begin(), window.end());
            smoothed[i] = window[window.size() / 2];
        }
    }
    f0Contour = smoothed;
}

static F0Result extractF0(const std::vector<float> &samples, float sampleRate) {
    F0Result result;
    const int frameSize = static_cast<int>(sampleRate * 0.025f); // 25ms
    const int hopSize = static_cast<int>(sampleRate * 0.010f); // 10ms
    const float minF0 = 60.0f;
    const float maxF0 = 500.0f;
    const float yinThreshold = 0.15f;
    const int minLag = static_cast<int>(sampleRate / maxF0);
    const int maxLag = static_cast<int>(sampleRate / minF0);

    if (frameSize <= 0 || hopSize <= 0 || maxLag >= frameSize || samples.size() < static_cast<size_t>(frameSize)) {
        return result;
    }

    for (size_t start = 0; start + static_cast<size_t>(frameSize) <= samples.size(); start += static_cast<size_t>(hopSize)) {
        const float *frame = &samples[start];
        std::vector<float> diff(maxLag + 1, 0.0f);

        for (int tau = 1; tau <= maxLag; tau++) {
            float sum = 0.0f;
            for (int j = 0; j < frameSize - maxLag; j++) {
                const float d = frame[j] - frame[j + tau];
                sum += d * d;
            }
            diff[tau] = sum;
        }

        std::vector<float> cmndf(maxLag + 1, 1.0f);
        float runningSum = 0.0f;
        for (int tau = 1; tau <= maxLag; tau++) {
            runningSum += diff[tau];
            if (runningSum > 0.0f) {
                cmndf[tau] = diff[tau] * static_cast<float>(tau) / runningSum;
            }
        }

        int bestLag = 0;
        float bestVal = 1.0f;
        for (int tau = minLag; tau <= maxLag; tau++) {
            if (cmndf[tau] < yinThreshold) {
                while (tau + 1 <= maxLag && cmndf[tau + 1] < cmndf[tau]) {
                    tau++;
                }
                bestLag = tau;
                bestVal = cmndf[tau];
                break;
            }
        }
        if (bestLag == 0) {
            for (int tau = minLag; tau <= maxLag; tau++) {
                if (cmndf[tau] < bestVal) {
                    bestVal = cmndf[tau];
                    bestLag = tau;
                }
            }
        }

        if (bestLag > 0 && bestVal < 0.5f) {
            const float f0 = sampleRate / static_cast<float>(bestLag);
            result.contour.push_back(f0);
            result.voicedFlags.push_back((f0 > minF0 && f0 < maxF0) ? 1.0f : 0.0f);
        } else {
            result.contour.push_back(0.0f);
            result.voicedFlags.push_back(0.0f);
        }
    }

    filterIsolatedVoiced(result.contour, result.voicedFlags, 3);
    filterOctaveJumps(result.contour, result.voicedFlags);
    medianSmoothF0(result.contour, result.voicedFlags, 5);

    result.voicedF0.clear();
    result.voicedF0.reserve(result.contour.size());
    for (size_t i = 0; i < result.contour.size(); i++) {
        const float f0 = result.contour[i];
        if (result.voicedFlags[i] > 0.5f && f0 > minF0 && f0 < maxF0) {
            result.voicedF0.push_back(f0);
        }
    }
    if (result.voicedF0.empty()) { return result; }

    result.meanF0 = computeMean(result.voicedF0);
    result.stdDevF0 = computeStdDev(result.voicedF0);
    std::vector<float> sortedF0 = result.voicedF0;
    std::sort(sortedF0.begin(), sortedF0.end());
    const size_t p5 = std::min(sortedF0.size() - 1, (sortedF0.size() * 5) / 100);
    const size_t p95 = std::min(sortedF0.size() - 1, (sortedF0.size() * 95) / 100);
    const float minPitch = sortedF0[p5];
    const float maxPitch = sortedF0[p95];
    result.rangeF0ST = hzToSemitones(maxPitch) - hzToSemitones(minPitch);
    NSLog(@"🔬 F0 Result: mean=%.1f Hz, range=%.1f ST (%.1f-%.1f Hz), voiced=%zu",
          result.meanF0, result.rangeF0ST, minPitch, maxPitch, result.voicedF0.size());
    return result;
}

static float computeJitter(const std::vector<float> &voicedF0) {
    if (voicedF0.size() < 2) { return 0.03f; }
    std::vector<float> periods;
    periods.reserve(voicedF0.size());
    for (float f0 : voicedF0) {
        if (f0 > 0.0f) { periods.push_back(1.0f / f0); }
    }
    if (periods.size() < 2) { return 0.03f; }
    float sumDiff = 0.0f;
    for (size_t i = 1; i < periods.size(); i++) {
        sumDiff += std::fabs(periods[i] - periods[i - 1]);
    }
    const float meanPeriod = computeMean(periods);
    if (meanPeriod <= 0.0f) { return 0.03f; }
    return (sumDiff / static_cast<float>(periods.size() - 1)) / meanPeriod;
}

static float computeShimmer(const std::vector<float> &samples, const std::vector<float> &f0Contour, float sampleRate) {
    if (f0Contour.size() < 2) { return 0.05f; }
    const int hopSize = static_cast<int>(sampleRate * 0.010f);
    std::vector<float> amplitudes;
    amplitudes.reserve(f0Contour.size());

    for (size_t i = 0; i < f0Contour.size(); i++) {
        const float f0 = f0Contour[i];
        if (f0 <= 0.0f) { continue; }
        const size_t center = i * static_cast<size_t>(hopSize);
        if (center >= samples.size()) { break; }
        const int period = static_cast<int>(sampleRate / f0);
        const int halfPeriod = std::max(1, period / 2);
        const size_t start = (center > static_cast<size_t>(halfPeriod)) ? center - static_cast<size_t>(halfPeriod) : 0;
        const size_t end = std::min(samples.size(), center + static_cast<size_t>(halfPeriod));
        float maxAmp = 0.0f;
        for (size_t j = start; j < end; j++) {
            maxAmp = std::max(maxAmp, std::fabs(samples[j]));
        }
        amplitudes.push_back(maxAmp);
    }

    if (amplitudes.size() < 2) { return 0.05f; }
    float sumDiff = 0.0f;
    for (size_t i = 1; i < amplitudes.size(); i++) {
        sumDiff += std::fabs(amplitudes[i] - amplitudes[i - 1]);
    }
    const float meanAmp = computeMean(amplitudes);
    if (meanAmp <= 0.0f) { return 0.05f; }
    return (sumDiff / static_cast<float>(amplitudes.size() - 1)) / meanAmp;
}

static float computeHNR(const std::vector<float> &samples, float sampleRate) {
    const int frameSize = static_cast<int>(sampleRate * 0.040f);
    const int hopSize = static_cast<int>(sampleRate * 0.010f);
    const int minLag = static_cast<int>(sampleRate / 500.0f);
    const int maxLag = static_cast<int>(sampleRate / 60.0f);
    if (frameSize <= 0 || hopSize <= 0 || maxLag >= frameSize || samples.size() < static_cast<size_t>(frameSize)) {
        return 10.0f;
    }

    std::vector<float> hnrValues;
    for (size_t start = 0; start + static_cast<size_t>(frameSize) <= samples.size(); start += static_cast<size_t>(hopSize)) {
        const float *frame = &samples[start];
        float energy = 0.0f;
        vDSP_svesq(frame, 1, &energy, vDSP_Length(frameSize));
        if (energy < 1e-8f) { continue; }

        float maxCorr = 0.0f;
        for (int lag = minLag; lag <= maxLag; lag++) {
            float corr = 0.0f;
            for (int i = 0; i < frameSize - lag; i++) {
                corr += frame[i] * frame[i + lag];
            }
            maxCorr = std::max(maxCorr, corr);
        }
        if (energy > maxCorr && maxCorr > 0.0f) {
            const float noise = energy - maxCorr;
            if (noise > 1e-8f) {
                const float hnr = 10.0f * std::log10(maxCorr / noise);
                if (hnr > 0.0f && hnr < 50.0f) {
                    hnrValues.push_back(hnr);
                }
            }
        }
    }
    return hnrValues.empty() ? 10.0f : computeMean(hnrValues);
}

struct LoudnessResult {
    float meanRMS = 0.0f;
    float stdDevRMS = 0.0f;
    float dynamicRangeDB = 0.0f;
    std::vector<float> contour;
};

static LoudnessResult extractLoudness(const std::vector<float> &samples, float sampleRate) {
    LoudnessResult result;
    const int frameSize = static_cast<int>(sampleRate * 0.025f);
    const int hopSize = static_cast<int>(sampleRate * 0.010f);
    if (frameSize <= 0 || hopSize <= 0 || samples.size() < static_cast<size_t>(frameSize)) {
        return result;
    }

    for (size_t start = 0; start + static_cast<size_t>(frameSize) <= samples.size(); start += static_cast<size_t>(hopSize)) {
        result.contour.push_back(computeRMS(&samples[start], static_cast<size_t>(frameSize)));
    }
    if (result.contour.empty()) { return result; }
    result.meanRMS = computeMean(result.contour);
    result.stdDevRMS = computeStdDev(result.contour);

    std::vector<float> sorted = result.contour;
    std::sort(sorted.begin(), sorted.end());
    const size_t lowIdx = std::min(sorted.size() - 1, (sorted.size() * 10) / 100);
    const size_t highIdx = std::min(sorted.size() - 1, (sorted.size() * 95) / 100);
    if (highIdx > lowIdx) {
        const float lowRMS = std::max(1e-8f, sorted[lowIdx]);
        const float highRMS = sorted[highIdx];
        result.dynamicRangeDB = 20.0f * std::log10(highRMS / lowRMS);
    }
    return result;
}

struct RhythmResult {
    float speechRate = 0.0f;
    float articulationRate = 0.0f;
    float pauseRate = 0.0f;
    float meanPauseDuration = 0.0f;
};

static RhythmResult extractRhythm(const std::vector<float> &samples, float sampleRate, const LoudnessResult &loudness) {
    RhythmResult result;
    const float totalDuration = static_cast<float>(samples.size()) / sampleRate;
    if (totalDuration < 1.0f || loudness.contour.empty()) { return result; }

    const float hopDuration = 0.010f;
    const float minPauseDuration = 0.20f;
    std::vector<float> pauseDurations;
    bool inPause = false;
    float pauseStart = 0.0f;
    float speechDuration = 0.0f;

    std::vector<float> sortedRMS = loudness.contour;
    std::sort(sortedRMS.begin(), sortedRMS.end());
    const size_t p20 = std::min(sortedRMS.size() - 1, (sortedRMS.size() * 20) / 100);
    const size_t p80 = std::min(sortedRMS.size() - 1, (sortedRMS.size() * 80) / 100);
    const float quietLevel = sortedRMS[p20];
    const float loudLevel = sortedRMS[p80];
    const float medianRMS = sortedRMS[sortedRMS.size() / 2];
    const float pauseThreshold = std::max((quietLevel + loudLevel) * 0.25f, medianRMS * 0.30f);
    NSLog(@"🔬 Pause detection: quiet=%.6f, loud=%.6f, median=%.6f, threshold=%.6f",
          quietLevel, loudLevel, medianRMS, pauseThreshold);

    for (size_t i = 0; i < loudness.contour.size(); i++) {
        const float t = static_cast<float>(i) * hopDuration;
        const bool silent = loudness.contour[i] < pauseThreshold;
        if (silent && !inPause) {
            inPause = true;
            pauseStart = t;
        } else if (!silent && inPause) {
            const float dur = t - pauseStart;
            if (dur >= minPauseDuration && dur < 10.0f) {
                pauseDurations.push_back(dur);
            }
            inPause = false;
        }
        if (!silent) {
            speechDuration += hopDuration;
        }
    }
    if (inPause) {
        const float dur = totalDuration - pauseStart;
        if (dur >= minPauseDuration && dur < totalDuration * 0.3f) { pauseDurations.push_back(dur); }
    }

    if (speechDuration < totalDuration * 0.3f) {
        NSLog(@"⚠️ Speech duration too low (%.2fs / %.2fs). Applying rhythm fallback.", speechDuration, totalDuration);
        speechDuration = totalDuration * 0.5f;
        pauseDurations.clear();
        result.pauseRate = 3.0f;
        result.meanPauseDuration = 0.5f;
    } else {
        result.pauseRate = totalDuration > 0.0f ? static_cast<float>(pauseDurations.size()) / (totalDuration / 60.0f) : 0.0f;
        result.meanPauseDuration = pauseDurations.empty()
            ? 0.0f
            : std::accumulate(pauseDurations.begin(), pauseDurations.end(), 0.0f) / static_cast<float>(pauseDurations.size());
    }

    const int smoothWindow = 5;
    std::vector<float> envelope(loudness.contour.size(), 0.0f);
    for (size_t i = 0; i < loudness.contour.size(); i++) {
        float sum = 0.0f;
        int count = 0;
        for (int j = -(smoothWindow / 2); j <= (smoothWindow / 2); j++) {
            const int idx = static_cast<int>(i) + j;
            if (idx >= 0 && idx < static_cast<int>(loudness.contour.size())) {
                sum += loudness.contour[static_cast<size_t>(idx)];
                count++;
            }
        }
        envelope[i] = count > 0 ? sum / static_cast<float>(count) : 0.0f;
    }

    const float peakThreshold = medianRMS * 0.5f;
    const int minPeakDistance = std::max(1, static_cast<int>(0.12f / hopDuration));
    int lastPeak = -minPeakDistance;
    int syllables = 0;
    for (size_t i = 1; i + 1 < envelope.size(); i++) {
        const bool isPeak = envelope[i] > envelope[i - 1] && envelope[i] > envelope[i + 1] && envelope[i] > peakThreshold;
        if (isPeak && (static_cast<int>(i) - lastPeak) >= minPeakDistance) {
            syllables++;
            lastPeak = static_cast<int>(i);
        }
    }

    result.speechRate = totalDuration > 0.0f ? static_cast<float>(syllables) / totalDuration : 0.0f;
    result.articulationRate = speechDuration > 0.0f ? static_cast<float>(syllables) / speechDuration : 0.0f;
    if (result.articulationRate > 8.0f) {
        NSLog(@"⚠️ Articulation rate too high: %.2f -> clamp 8.0", result.articulationRate);
        result.articulationRate = 8.0f;
    } else if (result.articulationRate < 2.0f && syllables > 5) {
        NSLog(@"⚠️ Articulation rate too low: %.2f -> raise 2.5", result.articulationRate);
        result.articulationRate = 2.5f;
    }
    NSLog(@"🔬 Rhythm: speechRate=%.2f, articulation=%.2f, pauseRate=%.2f/min, pauseDur=%.2fs, syllables=%d, speechDur=%.2fs",
          result.speechRate, result.articulationRate, result.pauseRate, result.meanPauseDuration, syllables, speechDuration);
    return result;
}

struct FormantResult {
    float f1 = 500.0f;
    float f2 = 1500.0f;
    float f3 = 2500.0f;
    float f4 = 3500.0f;
    float dispersion = 1000.0f;
};

static FormantResult extractFormants(const std::vector<float> &samples, float sampleRate) {
    FormantResult result;
    const int frameSize = static_cast<int>(sampleRate * 0.025f);
    const int order = 12;
    if (frameSize <= 0 || samples.size() < static_cast<size_t>(frameSize)) { return result; }

    const size_t midStart = (samples.size() / 2 > static_cast<size_t>(frameSize / 2))
        ? (samples.size() / 2 - static_cast<size_t>(frameSize / 2))
        : 0;
    std::vector<float> frame(static_cast<size_t>(frameSize), 0.0f);
    frame[0] = samples[midStart];
    for (int i = 1; i < frameSize; i++) {
        frame[static_cast<size_t>(i)] = samples[midStart + static_cast<size_t>(i)] - 0.97f * samples[midStart + static_cast<size_t>(i) - 1];
    }
    for (int i = 0; i < frameSize; i++) {
        frame[static_cast<size_t>(i)] *= 0.54f - 0.46f * std::cos(2.0f * kPi * static_cast<float>(i) / static_cast<float>(frameSize - 1));
    }

    std::vector<float> R(static_cast<size_t>(order + 1), 0.0f);
    for (int i = 0; i <= order; i++) {
        for (int j = 0; j < frameSize - i; j++) {
            R[static_cast<size_t>(i)] += frame[static_cast<size_t>(j)] * frame[static_cast<size_t>(j + i)];
        }
    }
    if (R[0] < 1e-10f) { return result; }

    std::vector<float> a(static_cast<size_t>(order + 1), 0.0f);
    std::vector<float> temp(static_cast<size_t>(order + 1), 0.0f);
    float error = R[0];
    for (int i = 1; i <= order; i++) {
        float lambda = 0.0f;
        for (int j = 1; j < i; j++) {
            lambda += a[static_cast<size_t>(j)] * R[static_cast<size_t>(i - j)];
        }
        lambda = (R[static_cast<size_t>(i)] - lambda) / error;
        temp[static_cast<size_t>(i)] = lambda;
        for (int j = 1; j < i; j++) {
            temp[static_cast<size_t>(j)] = a[static_cast<size_t>(j)] - lambda * a[static_cast<size_t>(i - j)];
        }
        for (int j = 1; j <= i; j++) {
            a[static_cast<size_t>(j)] = temp[static_cast<size_t>(j)];
        }
        error *= (1.0f - lambda * lambda);
        if (error < 1e-10f) { break; }
    }

    const int nfft = 1024;
    std::vector<float> spectrum(static_cast<size_t>(nfft), 0.0f);
    for (int k = 0; k < nfft; k++) {
        const float freq = (static_cast<float>(k) / static_cast<float>(nfft)) * sampleRate;
        if (freq > sampleRate * 0.5f) { break; }
        float realPart = 1.0f;
        float imagPart = 0.0f;
        for (int i = 1; i <= order; i++) {
            const float angle = 2.0f * kPi * freq * static_cast<float>(i) / sampleRate;
            realPart -= a[static_cast<size_t>(i)] * std::cos(angle);
            imagPart -= a[static_cast<size_t>(i)] * std::sin(angle);
        }
        const float mag = std::sqrt(realPart * realPart + imagPart * imagPart);
        spectrum[static_cast<size_t>(k)] = mag > 0.0f ? 1.0f / mag : 0.0f;
    }

    std::vector<float> peaks;
    const int minBin = static_cast<int>((200.0f * static_cast<float>(nfft)) / sampleRate);
    const int maxBin = std::min(nfft - 2, static_cast<int>((5500.0f * static_cast<float>(nfft)) / sampleRate));
    for (int k = std::max(1, minBin); k <= maxBin; k++) {
        if (spectrum[static_cast<size_t>(k)] > spectrum[static_cast<size_t>(k - 1)] &&
            spectrum[static_cast<size_t>(k)] > spectrum[static_cast<size_t>(k + 1)]) {
            peaks.push_back((static_cast<float>(k) / static_cast<float>(nfft)) * sampleRate);
            if (peaks.size() >= 4) { break; }
        }
    }

    if (peaks.size() >= 1) { result.f1 = peaks[0]; }
    if (peaks.size() >= 2) { result.f2 = peaks[1]; }
    if (peaks.size() >= 3) { result.f3 = peaks[2]; }
    if (peaks.size() >= 4) { result.f4 = peaks[3]; }
    result.dispersion = (result.f4 - result.f1) / 3.0f;
    return result;
}

struct AllFeatures {
    float f0Mean = 0.0f;
    float f0StdDev = 0.0f;
    float f0RangeST = 0.0f;
    float jitter = 0.03f;
    float shimmer = 0.05f;
    float hnr = 10.0f;
    float loudnessRMS = 0.0f;
    float loudnessStdDev = 0.0f;
    float loudnessDynamicRange = 0.0f;
    float loudnessRMSOriginal = 0.0f;
    float loudnessStdDevOriginal = 0.0f;
    float loudnessDynamicRangeOriginal = 0.0f;
    float speechRate = 0.0f;
    float articulationRate = 0.0f;
    float pauseRate = 0.0f;
    float meanPauseDuration = 0.0f;
    float f1 = 500.0f;
    float f2 = 1500.0f;
    float f3 = 2500.0f;
    float f4 = 3500.0f;
    float formantDispersion = 1000.0f;
};

static AllFeatures extractAll(const std::vector<float> &samples, float sampleRate) {
    AllFeatures features;
    if (samples.empty() || sampleRate <= 0.0f) { return features; }
    float maxAmp = 0.0f;
    for (float sample : samples) {
        maxAmp = std::max(maxAmp, std::fabs(sample));
    }
    NSLog(@"🔬 extractAll: samples=%zu, sampleRate=%.0f, maxAmp=%.6f", samples.size(), sampleRate, maxAmp);

    std::vector<float> normalizedSamples = samples;
    float appliedGain = 1.0f;
    if (maxAmp <= 0.0001f) {
        NSLog(@"⚠️ Signal is silence (maxAmp=%.6f). Returning defaults.", maxAmp);
        return features;
    }
    if (maxAmp < 0.05f) {
        // Bring quiet sessions to a stable DSP range.
        appliedGain = std::min(20.0f, 0.5f / maxAmp);
        NSLog(@"⚠️ Signal too quiet (maxAmp=%.6f). Applying gain: %.2fx", maxAmp, appliedGain);
        for (float &sample : normalizedSamples) {
            sample = std::max(-1.0f, std::min(1.0f, sample * appliedGain));
        }
    }

    const LoudnessResult loudOriginal = extractLoudness(samples, sampleRate);
    const LoudnessResult loudNormalized = extractLoudness(normalizedSamples, sampleRate);
    const F0Result f0 = extractF0(normalizedSamples, sampleRate);
    const RhythmResult rhythm = extractRhythm(normalizedSamples, sampleRate, loudNormalized);
    const FormantResult formants = extractFormants(normalizedSamples, sampleRate);

    features.f0Mean = f0.meanF0;
    features.f0StdDev = f0.stdDevF0;
    features.f0RangeST = f0.rangeF0ST;
    features.jitter = computeJitter(f0.voicedF0);
    features.shimmer = computeShimmer(normalizedSamples, f0.contour, sampleRate);
    features.hnr = computeHNR(normalizedSamples, sampleRate);
    // Normalized loudness drives scoring.
    features.loudnessRMS = loudNormalized.meanRMS;
    features.loudnessStdDev = loudNormalized.stdDevRMS;
    features.loudnessDynamicRange = loudNormalized.dynamicRangeDB;
    // Original loudness remains available for debug/inspection.
    features.loudnessRMSOriginal = loudOriginal.meanRMS;
    features.loudnessStdDevOriginal = loudOriginal.stdDevRMS;
    features.loudnessDynamicRangeOriginal = loudOriginal.dynamicRangeDB;
    features.speechRate = rhythm.speechRate;
    features.articulationRate = rhythm.articulationRate;
    features.pauseRate = rhythm.pauseRate;
    features.meanPauseDuration = rhythm.meanPauseDuration;
    features.f1 = formants.f1;
    features.f2 = formants.f2;
    features.f3 = formants.f3;
    features.f4 = formants.f4;
    features.formantDispersion = formants.dispersion;
    NSLog(@"🔬 Applied gain: %.2fx | Loudness original=%.6f | normalized=%.6f",
          appliedGain, features.loudnessRMSOriginal, features.loudnessRMS);
    return features;
}

} // namespace AudioFeatures

@implementation OpenSMILEBridge {
    NSString *_configPath;
}

- (instancetype)init {
    return [self initWithConfig:@""];
}

- (instancetype)initWithConfig:(NSString *)configPath {
    self = [super init];
    if (self) {
        _configPath = configPath ?: @"";
    }
    return self;
}

- (NSDictionary<NSString *, NSNumber *> *)extractFeaturesFromPCMData:(NSData *)pcmData
                                                          sampleRate:(double)sampleRate {
    return [self extractFeaturesFromPCMData:pcmData sampleRate:sampleRate startTime:0 endTime:0];
}

- (NSDictionary<NSString *, NSNumber *> *)extractFeaturesFromPCMData:(NSData *)pcmData
                                                          sampleRate:(double)sampleRate
                                                           startTime:(double)startTime
                                                             endTime:(double)endTime {
    auto allSamples = AudioFeatures::pcm16ToFloat(pcmData);
    if (allSamples.empty()) { return @{}; }

    const size_t startIdx = std::max<size_t>(0, std::min(static_cast<size_t>(std::max(0.0, startTime * sampleRate)), allSamples.size()));
    size_t endIdx = allSamples.size();
    if (endTime > 0) {
        endIdx = std::max(startIdx, std::min(static_cast<size_t>(endTime * sampleRate), allSamples.size()));
    }
    if (startIdx >= endIdx) { return @{}; }
    std::vector<float> segment(allSamples.begin() + static_cast<long>(startIdx), allSamples.begin() + static_cast<long>(endIdx));

    const auto f = AudioFeatures::extractAll(segment, static_cast<float>(sampleRate));
    return @{
        // Legacy keys
        @"F0Mean": @(f.f0Mean),
        @"F0Range": @(f.f0RangeST),
        @"F0Var": @(f.f0StdDev),
        @"Jitter": @(f.jitter),
        @"Shimmer": @(f.shimmer),
        @"HNR": @(f.hnr),
        @"Energy": @(f.loudnessRMS),
        @"SpeechRate": @(f.speechRate),
        @"PauseDist": @(f.pauseRate),
        @"PauseDur": @(f.meanPauseDuration),
        @"F1": @(f.f1),
        @"F2": @(f.f2),
        @"F3": @(f.f3),
        @"F4": @(f.f4),

        // Extended keys
        @"f0RangeST": @(f.f0RangeST),
        @"f0StdDev": @(f.f0StdDev),
        @"loudnessRMS": @(f.loudnessRMS),
        @"loudnessStdDev": @(f.loudnessStdDev),
        @"loudnessDynamicRange": @(f.loudnessDynamicRange),
        @"loudnessRMSOriginal": @(f.loudnessRMSOriginal),
        @"loudnessStdDevOriginal": @(f.loudnessStdDevOriginal),
        @"loudnessDynamicRangeOriginal": @(f.loudnessDynamicRangeOriginal),
        @"pauseRate": @(f.pauseRate),
        @"meanPauseDuration": @(f.meanPauseDuration),
        @"formantDispersion": @(f.formantDispersion),
        @"articulationRate": @(f.articulationRate),
    };
}

@end
