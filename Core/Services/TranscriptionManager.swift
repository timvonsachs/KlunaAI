import Foundation
import Speech

final class TranscriptionManager {
    static let shared = TranscriptionManager()

    enum TranscriptionSource: String, Codable {
        case whisper = "whisper"
        case onDevice = "on_device"
        case failed = "failed"
    }

    struct TranscriptionResult {
        let text: String
        let source: TranscriptionSource
        let segments: [WhisperSegment]?
        let language: String?
        let confidence: Double
    }

    func transcribe(audioURL: URL, language: String = "de") async -> TranscriptionResult {
        if NetworkMonitor.shared.isConnected {
            do {
                let response = try await WhisperService.shared.transcribe(
                    audioURL: audioURL,
                    language: language,
                    includeSegments: true
                )
                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && text.count > 3 {
                    let probs = response.segments?.compactMap(\.no_speech_prob) ?? []
                    let avgNoSpeech = probs.isEmpty ? 0.5 : probs.reduce(0, +) / Double(probs.count)
                    let confidence = max(0, min(1, 1.0 - avgNoSpeech))
                    return TranscriptionResult(
                        text: text,
                        source: .whisper,
                        segments: response.segments,
                        language: response.language ?? language,
                        confidence: confidence
                    )
                }
            } catch {
                print("⚠️ Whisper failed: \(error.localizedDescription)")
            }
        }

        do {
            let text = try await transcribeOnDevice(audioURL: audioURL, language: language)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return TranscriptionResult(
                    text: text,
                    source: .onDevice,
                    segments: nil,
                    language: language,
                    confidence: 0.5
                )
            }
        } catch {
            print("⚠️ On-device fallback failed: \(error.localizedDescription)")
        }

        return TranscriptionResult(
            text: "",
            source: .failed,
            segments: nil,
            language: language,
            confidence: 0
        )
    }

    private func transcribeOnDevice(audioURL: URL, language: String) async throws -> String {
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { auth in
                    continuation.resume(returning: auth == .authorized)
                }
            }
            guard granted else { return "" }
        } else if status != .authorized {
            return ""
        }

        return try await withCheckedThrowingContinuation { continuation in
            let locale = language == "de" ? Locale(identifier: "de-DE") : Locale(identifier: "en-US")
            guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                continuation.resume(returning: "")
                return
            }
            let request = SFSpeechURLRecognitionRequest(url: audioURL)
            request.shouldReportPartialResults = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
