import AudioToolbox
import UIKit

enum SoundManager {
    static func playScoreReveal() {
        AudioServicesPlaySystemSound(1057)
    }

    static func playNewHighScore() {
        AudioServicesPlaySystemSound(1025)
    }

    static func scoreHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    static func againHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}
