import AVFoundation
import Combine
import Foundation
import UIKit

final class AudioRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var recordingDuration: TimeInterval = 0

    private let targetSampleRate: Double = 16_000
    private let targetChannels: AVAudioChannelCount = 1

    private var audioEngine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?
    private var pcmBufferData = Data()
    private var appendQueue = DispatchQueue(label: "kluna.audio.pcm.append")

    private var startTime: Date?
    private var durationTimer: DispatchSourceTimer?
    private var onBufferCallback: ((AVAudioPCMBuffer) -> Void)?
    private var onForcedStop: ((Data) -> Void)?
    private var observersInstalled = false

    func startRecording(
        onBuffer: @escaping (AVAudioPCMBuffer) -> Void,
        onForcedStop: ((Data) -> Void)? = nil
    ) -> Bool {
        guard !isRecording else { return false }
        onBufferCallback = onBuffer
        self.onForcedStop = onForcedStop
        pcmBufferData.removeAll(keepingCapacity: true)
        audioLevel = 0
        recordingDuration = 0

        let session = AVAudioSession.sharedInstance()
        guard microphonePermissionGranted() else { return false }
        guard !(session.availableInputs ?? []).isEmpty else { return false }

        do {
            try configureAudioSession()
        } catch {
            print("🎙️ ERROR configuring audio session: \(error)")
            return false
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        print("🎙️ Input format: sampleRate=\(inputFormat.sampleRate), channels=\(inputFormat.channelCount), commonFormat=\(inputFormat.commonFormat.rawValue), interleaved=\(inputFormat.isInterleaved)")
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                               sampleRate: targetSampleRate,
                                               channels: targetChannels,
                                               interleaved: true) else { return false }
        print("🎙️ Target format: sampleRate=\(targetFormat.sampleRate), channels=\(targetFormat.channelCount), commonFormat=\(targetFormat.commonFormat.rawValue), interleaved=\(targetFormat.isInterleaved)")

        self.audioEngine = engine
        self.targetFormat = targetFormat
        self.converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        self.startTime = Date()
        installDurationTimer()
        installNotificationObservers()

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            self.onBufferCallback?(buffer)
            self.updateAudioLevel(from: buffer)
            if let pcm = self.convertBufferToPCM16(buffer) {
                self.appendQueue.async { self.pcmBufferData.append(pcm) }
            }
        }

        do {
            try engine.start()
            DispatchQueue.main.async { self.isRecording = true }
            return true
        } catch {
            stopInternal()
            return false
        }
    }

    func stopRecording() -> Data? {
        guard isRecording else { return nil }
        stopInternal()
        var result: Data?
        appendQueue.sync {
            result = self.pcmBufferData
            self.pcmBufferData.removeAll(keepingCapacity: false)
        }
        return result
    }

    internal func convertBufferToPCM16(_ inputBuffer: AVAudioPCMBuffer) -> Data? {
        let targetFormat: AVAudioFormat
        if let configured = self.targetFormat {
            targetFormat = configured
        } else {
            guard let fallback = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                               sampleRate: targetSampleRate,
                                               channels: targetChannels,
                                               interleaved: true) else { return nil }
            targetFormat = fallback
        }

        let converter = self.converter ?? AVAudioConverter(from: inputBuffer.format, to: targetFormat)
        guard let converter else { return nil }

        let inFrames = Double(inputBuffer.frameLength)
        let ratio = targetFormat.sampleRate / inputBuffer.format.sampleRate
        let outFrames = AVAudioFrameCount(max(1, Int(ceil(inFrames * ratio)) + 8))
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrames) else { return nil }

        var didProvideInput = false
        var error: NSError?
        let status = converter.convert(to: outBuffer, error: &error) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            outStatus.pointee = .haveData
            return inputBuffer
        }
        guard status == .haveData || status == .inputRanDry else { return nil }
        guard let channelData = outBuffer.int16ChannelData else { return nil }
        let byteCount = Int(outBuffer.frameLength) * MemoryLayout<Int16>.size * Int(targetChannels)
        return Data(bytes: channelData[0], count: byteCount)
    }

    private func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        var sum: Float = 0
        if let floatData = buffer.floatChannelData {
            let channel = floatData[0]
            for i in 0..<frameLength {
                sum += channel[i] * channel[i]
            }
        } else if let int16Data = buffer.int16ChannelData {
            let channel = int16Data[0]
            for i in 0..<frameLength {
                let v = Float(channel[i]) / 32768.0
                sum += v * v
            }
        }
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(max(rms, 0.000_001))
        let minDb: Float = -50
        let normalized = max(0, min(1, (db - minDb) / -minDb))
        DispatchQueue.main.async {
            self.audioLevel = (0.3 * normalized) + (0.7 * self.audioLevel)
        }
    }

    private func installDurationTimer() {
        durationTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in
            guard let self, let start = self.startTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            DispatchQueue.main.async { self.recordingDuration = elapsed }
        }
        durationTimer = timer
        timer.resume()
    }

    private func stopInternal() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine?.reset()
        audioEngine = nil
        converter = nil
        targetFormat = nil
        onBufferCallback = nil
        onForcedStop = nil
        durationTimer?.cancel()
        durationTimer = nil
        startTime = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.audioLevel = 0
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        // Some devices reject specific category/option combinations with OSStatus -50.
        // Use a resilient fallback chain so recording can still start.
        let configurations: [(AVAudioSession.Category, AVAudioSession.Mode, AVAudioSession.CategoryOptions)] = [
            (.playAndRecord, .measurement, [.defaultToSpeaker, .allowBluetooth]),
            (.record, .measurement, []),
            (.record, .default, []),
        ]

        var lastError: Error?
        for (category, mode, options) in configurations {
            do {
                try session.setCategory(category, mode: mode, options: options)
                try session.setPreferredSampleRate(targetSampleRate)

                let supportsRequestedChannels = session.maximumInputNumberOfChannels >= Int(targetChannels)
                if supportsRequestedChannels {
                    try session.setPreferredInputNumberOfChannels(Int(targetChannels))
                } else {
                    print("🎙️ Device supports max \(session.maximumInputNumberOfChannels) input channels; skipping preferred channel setup")
                }

                try session.setActive(true, options: .notifyOthersOnDeactivation)
                if session.isInputGainSettable {
                    do {
                        try session.setInputGain(1.0)
                        print("🎙️ Input gain set to max: \(session.inputGain)")
                    } catch {
                        print("⚠️ Could not set input gain: \(error)")
                    }
                } else {
                    print("🎙️ Input gain not settable - using default")
                }
                print("🎙️ Current input gain: \(session.inputGain)")
                let dataSources = session.inputDataSources?.map { $0.dataSourceName } ?? ["none"]
                print("🎙️ Input data sources: \(dataSources)")
                print("🎙️ Audio session ready (category: \(category.rawValue), mode: \(mode.rawValue), options: \(options.rawValue))")
                return
            } catch {
                lastError = error
                print("🎙️ Audio session config failed (category: \(category.rawValue), mode: \(mode.rawValue), options: \(options.rawValue)): \(error)")
            }
        }

        if let lastError {
            throw lastError
        }
    }

    private func installNotificationObservers() {
        guard !observersInstalled else { return }
        observersInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue),
            type == .began
        else { return }
        stopAndForwardIfNeeded()
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard
            let info = notification.userInfo,
            let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }
        if reason == .oldDeviceUnavailable {
            stopAndForwardIfNeeded()
        }
    }

    @objc private func handleAppBackground() {
        stopAndForwardIfNeeded()
    }

    private func stopAndForwardIfNeeded() {
        guard isRecording else { return }
        let data = stopRecording()
        if let data, !data.isEmpty {
            onForcedStop?(data)
        }
    }

    private func microphonePermissionGranted() -> Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    // MARK: - Playback Storage

    static func saveRecordingForPlayback(pcmData: Data, sessionId: UUID, sampleRate: Int = 16_000, channels: Int = 1) -> URL? {
        guard !pcmData.isEmpty else { return nil }
        let fileManager = FileManager.default
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let recordingsDir = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        do {
            try fileManager.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
            let destinationURL = recordingsDir.appendingPathComponent("\(sessionId.uuidString).wav")
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            let wavData = buildWavData(fromPCM16: pcmData, sampleRate: sampleRate, channels: channels)
            try wavData.write(to: destinationURL, options: .atomic)
            return destinationURL
        } catch {
            print("❌ Failed to save recording: \(error)")
            return nil
        }
    }

    static func recordingURL(for sessionId: UUID) -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = documentsPath.appendingPathComponent("Recordings", isDirectory: true).appendingPathComponent("\(sessionId.uuidString).wav")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func cleanupOldRecordings(keepLast: Int = 50) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let recordingsDir = documentsPath.appendingPathComponent("Recordings", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: recordingsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }
        let sorted = files.sorted { lhs, rhs in
            let d1 = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let d2 = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return d1 > d2
        }
        if sorted.count > keepLast {
            for file in sorted.dropFirst(keepLast) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    private static func buildWavData(fromPCM16 pcmData: Data, sampleRate: Int, channels: Int) -> Data {
        let bitsPerSample = 16
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let subChunk2Size = pcmData.count
        let chunkSize = 36 + subChunk2Size

        var data = Data()
        data.append("RIFF".data(using: .ascii)!)
        data.append(UInt32(chunkSize).littleEndianData)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(UInt32(16).littleEndianData)
        data.append(UInt16(1).littleEndianData)
        data.append(UInt16(channels).littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(UInt32(byteRate).littleEndianData)
        data.append(UInt16(blockAlign).littleEndianData)
        data.append(UInt16(bitsPerSample).littleEndianData)
        data.append("data".data(using: .ascii)!)
        data.append(UInt32(subChunk2Size).littleEndianData)
        data.append(pcmData)
        return data
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
