import SwiftUI

struct BaselineProgress {
    let totalSessions: Int
    let requiredSessions: Int
    let phase: BaselinePhase
    let percentage: Double
    let isEstablished: Bool

    init(totalSessions: Int, requiredSessions: Int = 21) {
        self.totalSessions = min(totalSessions, requiredSessions)
        self.requiredSessions = requiredSessions
        self.percentage = Double(min(totalSessions, requiredSessions)) / Double(requiredSessions)
        self.isEstablished = totalSessions >= requiredSessions

        if totalSessions >= requiredSessions {
            self.phase = .established
        } else if totalSessions >= 15 {
            self.phase = .advanced
        } else if totalSessions >= 8 {
            self.phase = .intermediate
        } else {
            self.phase = .learning
        }
    }
}

enum BaselinePhase: String {
    case learning
    case intermediate
    case advanced
    case established

    func title(language: String) -> String {
        switch self {
        case .learning:
            return language == "de" ? "Kluna lernt deine Stimme" : "Kluna is learning your voice"
        case .intermediate:
            return language == "de" ? "Kluna versteht dich" : "Kluna understands you"
        case .advanced:
            return language == "de" ? "Kluna kennt dich" : "Kluna knows you"
        case .established:
            return language == "de" ? "Persönlich kalibriert" : "Personally calibrated"
        }
    }

    func description(language: String) -> String {
        switch self {
        case .learning:
            return language == "de"
            ? "Sprich weiter - mit jeder Session wird Kluna präziser."
            : "Keep speaking - with every session Kluna gets more precise."
        case .intermediate:
            return language == "de"
            ? "Deine Scores werden persönlicher. Kluna erkennt deine Muster."
            : "Your scores are becoming personal. Kluna recognizes your patterns."
        case .advanced:
            return language == "de"
            ? "Fast da! Noch wenige Sessions bis zur vollen Kalibrierung."
            : "Almost there! A few more sessions until full calibration."
        case .established:
            return language == "de"
            ? "Deine Scores basieren auf deiner Stimme, nicht auf einem Durchschnitt."
            : "Your scores are based on your voice, not on an average."
        }
    }

    var accentColor: Color {
        switch self {
        case .learning: return .klunaAccent
        case .intermediate: return .klunaAccent
        case .advanced: return .klunaGreen
        case .established: return .klunaGold
        }
    }
}

struct BaselineToast: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
}
