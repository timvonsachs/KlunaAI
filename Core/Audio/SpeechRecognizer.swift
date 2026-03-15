import AVFoundation
import Foundation

final class SpeechRecognizer: ObservableObject {
    @Published var transcription: String = ""

    init(language: String) {
        _ = language
    }

    func startTranscription() {
        transcription = ""
    }

    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        _ = buffer
    }

    func stopTranscription() -> String {
        transcription
    }

    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        completion(false)
    }
}
