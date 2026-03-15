import AVFoundation
import Foundation

enum WhisperError: Error, LocalizedError {
    case noAPIKey
    case noAudioData
    case networkError(Error)
    case apiError(String)
    case decodingError
    case timeout

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "OpenAI API Key nicht konfiguriert"
        case .noAudioData: return "Keine Audiodaten verfügbar"
        case .networkError(let err): return "Netzwerkfehler: \(err.localizedDescription)"
        case .apiError(let msg): return "Whisper API: \(msg)"
        case .decodingError: return "Antwort konnte nicht gelesen werden"
        case .timeout: return "Zeitüberschreitung"
        }
    }
}

struct WhisperResponse: Codable {
    let text: String
    let language: String?
    let duration: Double?
    let segments: [WhisperSegment]?
}

struct WhisperSegment: Codable {
    let id: Int
    let start: Double
    let end: Double
    let text: String
    let tokens: [Int]?
    let temperature: Double?
    let avg_logprob: Double?
    let no_speech_prob: Double?
}

final class WhisperService {
    static let shared = WhisperService()

    private let endpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let model = "whisper-1"
    private let timeoutSeconds: TimeInterval = 30

    private var apiKey: String? {
        if !Config.openAIAPIKey.isEmpty {
            return Config.openAIAPIKey
        }
        if let key = UserDefaults.standard.string(forKey: "openai_api_key"), !key.isEmpty {
            return key
        }
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String, !key.isEmpty {
            return key
        }
        return nil
    }

    func transcribe(
        audioURL: URL,
        language: String = "de",
        includeSegments: Bool = true
    ) async throws -> WhisperResponse {
        guard let apiKey else { throw WhisperError.noAPIKey }
        let uploadURL = try await whisperUploadURL(from: audioURL)
        defer {
            if uploadURL != audioURL {
                try? FileManager.default.removeItem(at: uploadURL)
            }
        }
        guard let audioData = try? Data(contentsOf: uploadURL), !audioData.isEmpty else {
            throw WhisperError.noAudioData
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutSeconds

        var body = Data()
        let filename = uploadURL.lastPathComponent
        let mimeType = mimeTypeForExtension(uploadURL.pathExtension)
        body.appendMultipart(boundary: boundary, name: "file", filename: filename, mimeType: mimeType, data: audioData)
        body.appendMultipart(boundary: boundary, name: "model", value: model)
        body.appendMultipart(boundary: boundary, name: "language", value: language)
        body.appendMultipart(boundary: boundary, name: "response_format", value: "verbose_json")
        if includeSegments {
            body.appendMultipart(boundary: boundary, name: "timestamp_granularities[]", value: "segment")
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                throw WhisperError.timeout
            }
            throw WhisperError.networkError(error)
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorBody = String(data: data, encoding: .utf8) {
                throw WhisperError.apiError("Status \(httpResponse.statusCode): \(errorBody)")
            }
            throw WhisperError.apiError("Status \(httpResponse.statusCode)")
        }

        do {
            return try JSONDecoder().decode(WhisperResponse.self, from: data)
        } catch {
            if let simple = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let text = simple["text"] as? String {
                return WhisperResponse(text: text, language: language, duration: nil, segments: nil)
            }
            throw WhisperError.decodingError
        }
    }

    func transcribe(
        audioData: Data,
        format: String = "wav",
        language: String = "de"
    ) async throws -> WhisperResponse {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("kluna_whisper_\(UUID().uuidString).\(format)")
        try audioData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try await transcribe(audioURL: tempURL, language: language)
    }

    private func mimeTypeForExtension(_ ext: String) -> String {
        switch ext.lowercased() {
        case "m4a": return "audio/m4a"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "mp4": return "audio/mp4"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        default: return "audio/wav"
        }
    }

    private func whisperUploadURL(from originalURL: URL) async throws -> URL {
        let ext = originalURL.pathExtension.lowercased()
        if ext == "m4a" { return originalURL }
        if ext == "wav", let converted = try await createWhisperOptimizedCopy(from: originalURL) {
            return converted
        }
        return originalURL
    }

    private func createWhisperOptimizedCopy(from originalURL: URL) async throws -> URL? {
        let asset = AVURLAsset(url: originalURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            return nil
        }
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_\(UUID().uuidString).m4a")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        return try await withCheckedThrowingContinuation { continuation in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume(returning: outputURL)
                case .failed:
                    continuation.resume(throwing: exportSession.error ?? WhisperError.apiError("Audio-Konvertierung fehlgeschlagen"))
                case .cancelled:
                    continuation.resume(returning: nil)
                default:
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
