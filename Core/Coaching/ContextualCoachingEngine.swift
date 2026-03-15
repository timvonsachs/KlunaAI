import Foundation

enum ContextualCoachingEngine {
    static func buildPrompt(
        scores: DimensionScores,
        bridgeFeatures: [String: Double],
        vocalState: VocalStateResult,
        efficiency: VocalEfficiencyResult,
        spectral: SpectralBandResult,
        profile: SpeakerProfile?,
        prediction: ScorePrediction?,
        circadian: CircadianProfile?,
        patterns: [DetectedPattern],
        consistency: ConsistencyResult?,
        sessionCount: Int,
        recentScores: [Double],
        transcription: String
    ) -> String {
        let recentTrend: String = {
            guard recentScores.count >= 3 else { return "unklar" }
            let lhs = recentScores.suffix(3).reduce(0, +) / 3.0
            let rhs = recentScores.prefix(3).reduce(0, +) / 3.0
            if lhs > rhs + 2 { return "verbessert sich" }
            if lhs < rhs - 2 { return "faellt leicht" }
            return "stabil"
        }()

        var text = """
        VOICE-INTELLIGENCE-KONTEXT:
        Aktuelle Session: Overall \(Int(scores.overall))/100, Confidence \(Int(scores.confidence)), Energy \(Int(scores.energy)), Tempo \(Int(scores.tempo)), Gelassenheit \(Int(scores.stability)), Charisma \(Int(scores.charisma))
        Stimmzustand: \(vocalState.primaryState.rawValue) (\(Int(vocalState.confidence * 100))% sicher). Hinweis: \(vocalState.primaryState.coachingHint)
        Effizienz: \(efficiency.category.rawValue) (\(Int(efficiency.efficiencyScore))/100). Tipp: \(efficiency.category.tip)
        Stimmklang: Waerme \(Int(spectral.warmthScore))/100, Praesenz \(Int(spectral.presenceScore))/100, Koerper \(Int(spectral.bodyScore))/100, Brillanz \(Int(spectral.airScore))/100
        Verlauf letzter Scores: \(recentTrend)
        """

        if let secondary = vocalState.secondaryState {
            text += "\nSekundaere State-Tendenz: \(secondary.rawValue)"
        }

        if let profile {
            text += "\nSprecherprofil: \(profile.rawValue) (Rang \(profile.rank)/8)"
        }

        if let prediction {
            let error = prediction.predictionError(actualScore: scores.overall)
            text += "\nVorhersage: erwartet \(Int(prediction.expectedScore)), erreicht \(Int(scores.overall)) (\(error.deltaString))"
        }

        if let circadian, circadian.isReady, let recommendation = circadian.recommendation {
            text += "\nTageszeit-Profil: \(recommendation)"
        }

        if !patterns.isEmpty {
            let patternText = patterns.prefix(2).map { $0.description }.joined(separator: " | ")
            text += "\nErkannte Muster: \(patternText)"
        }

        if let consistency, consistency.totalSessions >= 5 {
            text += "\nKonsistenz: \(consistency.masteryLevel.title), Score \(Int(consistency.overallConsistency))/100, Streak \(consistency.currentStreak)"
        }

        if sessionCount <= 3 {
            text += "\nUser ist neu: ermutigend und einfach formulieren."
        }

        let trimmedTranscription = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTranscription.isEmpty {
            text += """

            TRANSKRIPTION:
            "\(trimmedTranscription)"
            Hinweise fuer Coaching:
            - Auf Inhalt nur eingehen, wenn es das Coaching verbessert.
            - Keine Grammatik- oder Wortkorrekturen.
            - Fokus bleibt auf Stimme, Wirkung, Delivery.
            """
        }

        let jitter = bridgeFeatures[FeatureKeys.jitter] ?? bridgeFeatures["Jitter"] ?? 0
        text += "\nJitter aktuell: \(String(format: "%.4f", jitter)) (nicht als Zahl ausgeben, nur fuer Tonalitaet)."
        text += "\nRegel: Keine technischen Begriffe in der finalen Coach-Antwort."
        return text
    }
}
