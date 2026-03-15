import Combine
import Foundation

final class AudioPipelineManager: ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var liveTranscription: String = ""

    private let recorder: AudioRecorder
    private var cancellables = Set<AnyCancellable>()

    init(language: String) {
        recorder = AudioRecorder()
        _ = language
        bindStreams()
    }

    func startSession() {
        print("🎙️ Pipeline: startSession()")
        _ = recorder.startRecording { _ in }
        print("🎙️ Pipeline: recording + transcription started")
    }

    func stopSession() -> (audioData: Data?, transcription: String) {
        let audioData = recorder.stopRecording()
        return (audioData, "")
    }

    static func requestPermissions(completion: @escaping (Bool) -> Void) {
        PermissionManager.requestAllAudioPermissions(completion: completion)
    }

    private func bindStreams() {
        recorder.$isRecording.receive(on: DispatchQueue.main).assign(to: \.isRecording, on: self).store(in: &cancellables)
        recorder.$audioLevel.receive(on: DispatchQueue.main).assign(to: \.audioLevel, on: self).store(in: &cancellables)
        recorder.$recordingDuration.receive(on: DispatchQueue.main).assign(to: \.recordingDuration, on: self).store(in: &cancellables)
    }
}
