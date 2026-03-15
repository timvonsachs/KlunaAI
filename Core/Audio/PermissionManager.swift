import AVFoundation
import Speech

enum PermissionManager {
    static func isMicrophonePermissionGranted() -> Bool {
        if #available(iOS 17.0, *) {
            return AVAudioApplication.shared.recordPermission == .granted
        }
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    static func isSpeechRecognitionPermissionGranted() -> Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    static func requestSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    static func requestAllAudioPermissions(completion: @escaping (Bool) -> Void) {
        requestMicrophonePermission { mic in
            guard mic else { completion(false); return }
            requestSpeechRecognitionPermission { speech in
                completion(speech)
            }
        }
    }
}
