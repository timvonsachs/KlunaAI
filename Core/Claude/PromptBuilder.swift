import Foundation

/// Builds the two-layer system prompts for all Claude API calls.
/// Supports both German and English based on user language setting.
enum PromptBuilder {
    
    // MARK: - Quick Feedback Prompt
    
    static func buildQuickFeedbackPrompt(
        user: KlunaUser,
        scores: DimensionScores,
        pitchType: String,
        recentSessions: [SessionSummary],
        heatmapSummary: String,
        profileClassification: ProfileClassification? = nil,
        melodicAnalysis: MelodicContourAnalysis? = nil,
        spectralResult: SpectralBandResult? = nil,
        consistency: ConsistencyResult? = nil,
        prediction: ScorePrediction? = nil,
        predictionError: PredictionError? = nil,
        contextualInsights: String? = nil
    ) -> String {
        return """
        \(staticLayer(user: user))
        
        \(dynamicLayer(user: user, scores: scores, pitchType: pitchType, recentSessions: recentSessions, heatmapSummary: heatmapSummary, profileClassification: profileClassification, melodicAnalysis: melodicAnalysis, spectralResult: spectralResult, consistency: consistency, prediction: prediction, predictionError: predictionError, contextualInsights: contextualInsights))
        
        \(quickFeedbackInstructions(language: user.language))
        \(playbackCoachInstructions(language: user.language))
        """
    }
    
    // MARK: - Deep Coaching Prompt
    
    static func buildDeepCoachingPrompt(
        user: KlunaUser,
        scores: DimensionScores,
        pitchType: String,
        recentSessions: [SessionSummary],
        heatmapSummary: String,
        profileClassification: ProfileClassification? = nil,
        melodicAnalysis: MelodicContourAnalysis? = nil,
        spectralResult: SpectralBandResult? = nil,
        consistency: ConsistencyResult? = nil,
        prediction: ScorePrediction? = nil,
        predictionError: PredictionError? = nil,
        contextualInsights: String? = nil
    ) -> String {
        return """
        \(staticLayer(user: user))
        
        \(dynamicLayer(user: user, scores: scores, pitchType: pitchType, recentSessions: recentSessions, heatmapSummary: heatmapSummary, profileClassification: profileClassification, melodicAnalysis: melodicAnalysis, spectralResult: spectralResult, consistency: consistency, prediction: prediction, predictionError: predictionError, contextualInsights: contextualInsights))
        
        \(deepCoachingInstructions(language: user.language))
        """
    }
    
    // MARK: - Static Layer
    
    private static func staticLayer(user: KlunaUser) -> String {
        let lang = user.language
        
        if lang == "de" {
            return """
            Du bist ein direkter, motivierender Sprach-Coach für \(user.name).
            Du kennst \(user.name) seit \(user.daysSinceFirstSession) Tagen und \(user.totalSessions) Sessions.
            
            Sprache: Deutsch – IMMER auf Deutsch antworten.
            \(goalContext(for: user, language: "de"))
            
            Bekannte Stärken:
            \(user.strengths.map { "- \($0)" }.joined(separator: "\n"))
            
            Bekannte Schwächen:
            \(user.weaknesses.map { "- \($0)" }.joined(separator: "\n"))
            
            \(user.longTermProfile ?? "")
            
            Du bist kein Therapeut. Du bist ein Coach.
            Du pushst, du forderst, du respektierst.
            Antworte direkt, motivierend, konkret.
            Keine leeren Phrasen. Keine generischen Tipps.
            Jedes Feedback bezieht sich auf DIESEN User und DIESE Session.
            Keine Bullet Points. Fließender Text.
            """
        } else {
            return """
            You are a direct, motivating voice coach for \(user.name).
            You've known \(user.name) for \(user.daysSinceFirstSession) days and \(user.totalSessions) sessions.
            
            Language: English – ALWAYS respond in English.
            \(goalContext(for: user, language: "en"))
            
            Known strengths:
            \(user.strengths.map { "- \($0)" }.joined(separator: "\n"))
            
            Known weaknesses:
            \(user.weaknesses.map { "- \($0)" }.joined(separator: "\n"))
            
            \(user.longTermProfile ?? "")
            
            You are not a therapist. You are a coach.
            You push, you challenge, you respect.
            Respond directly, motivationally, concretely.
            No empty phrases. No generic tips.
            Every piece of feedback references THIS user and THIS session.
            No bullet points. Flowing text.
            """
        }
    }
    
    // MARK: - Dynamic Layer
    
    private static func dynamicLayer(
        user: KlunaUser,
        scores: DimensionScores,
        pitchType: String,
        recentSessions: [SessionSummary],
        heatmapSummary: String,
        profileClassification: ProfileClassification?,
        melodicAnalysis: MelodicContourAnalysis?,
        spectralResult: SpectralBandResult?,
        consistency: ConsistencyResult?,
        prediction: ScorePrediction?,
        predictionError: PredictionError?,
        contextualInsights: String?
    ) -> String {
        let firstSessionContext: String
        if user.totalSessions == 0 {
            firstSessionContext = """
            FIRST SESSION CONTEXT:
            This is the first session for this user.
            Name one clear strength and one clear weakness based on voice behavior.
            Make the user curious for session 2 by naming one pattern to validate.
            """
        } else {
            firstSessionContext = ""
        }

        let profileBlock: String
        if let profileClassification {
            let trendText = profileClassification.secondaryProfile.map { "Tendenz: \($0.rawValue)" } ?? ""
            profileBlock = """
            ERKANNTES PROFIL: \(profileClassification.profile.rawValue) (Rang \(profileClassification.profile.rank)/8)
            \(trendText)
            Profil-Beschreibung: \(profileClassification.profile.shortDescription)

            WICHTIG: Nenne das Profil beim Namen in deiner Antwort. Gib EINEN konkreten Tipp der zum nächsten Profil führt.
            """
        } else {
            profileBlock = ""
        }

        let melodicBlock: String
        if let melodicAnalysis {
            melodicBlock = """
            MELODIE-ANALYSE:
            - Betonungsmuster (Hat Patterns): \(melodicAnalysis.hatPatternCount) erkannt
            - Satzende-Absenkung (Final Lowering): \(melodicAnalysis.finalLoweringPresent ? "Ja (\(Int(melodicAnalysis.finalLoweringStrength))%)" : "Nein")
            - Bewusste Betonung (F0-Loudness Korrelation): \(String(format: "%.2f", melodicAnalysis.emphasisCorrelation))
            - Autorität (Downstep): \(melodicAnalysis.downstepPresent ? "Ja" : "Nein")
            - Intentionality-Score: \(Int(melodicAnalysis.intentionalityScore))/100

            WICHTIG: Wenn der Intentionality-Score unter 40 liegt, gib einen konkreten Tipp zur Melodie.
            Wenn Final Lowering fehlt, erwähne dass die Stimme am Ende abgesenkt werden sollte.
            """
        } else {
            melodicBlock = ""
        }

        let predictionBlock: String
        if let prediction, let predictionError {
            let relation: String
            switch predictionError.category {
            case .strongPositive, .positive:
                relation = "über"
            case .neutral:
                relation = "im Bereich der"
            case .negative, .strongNegative:
                relation = "unter"
            }
            predictionBlock = """
            SCORE-VORHERSAGE:
            Erwarteter Score: \(Int(prediction.expectedScore))
            Erreichter Score: \(Int(scores.overall))
            Differenz: \(predictionError.deltaString) (\(relation) Erwartung)
            Trend: \(prediction.trend.rawValue)

            WICHTIG: Erwähne die Vorhersage in deinem Feedback.
            Bei positivem Delta: Feiere den Fortschritt.
            Bei negativem Delta: Formuliere konstruktiv, nie als Versagen.
            """
        } else {
            predictionBlock = ""
        }

        let spectralBlock: String
        if let spectralResult {
            spectralBlock = """
            STIMMKLANG-ANALYSE:
            - Wärme: \(Int(spectralResult.warmthScore))/100
            - Körper: \(Int(spectralResult.bodyScore))/100
            - Präsenz: \(Int(spectralResult.presenceScore))/100
            - Brillanz: \(Int(spectralResult.airScore))/100
            - Gesamt-Klang: \(Int(spectralResult.overallTimbreScore))/100

            WICHTIG: Sprich über den subjektiven Klangeindruck, ohne Frequenzbegriffe.
            Wenn Präsenz unter 50 liegt: Mund weiter öffnen, Konsonanten deutlicher.
            Wenn Wärme unter 40 liegt: Stimme klingt dünn, tiefer und entspannter sprechen.
            Wenn Körper unter 40 liegt: mehr aus der Brust sprechen.
            """
        } else {
            spectralBlock = ""
        }

        let consistencyBlock: String
        if let consistency {
            if consistency.totalSessions >= 5 {
                let trendText = consistency.consistencyTrend > 5
                    ? "wird konsistenter"
                    : (consistency.consistencyTrend < -5 ? "mehr Variation in letzter Zeit" : "stabil")
                consistencyBlock = """
                KONSISTENZ-DATEN:
                Mastery-Level: \(consistency.masteryLevel.title) (\(consistency.totalSessions) Sessions)
                Konsistenz-Score: \(Int(consistency.overallConsistency))/100
                Streak: \(consistency.currentStreak) Tage
                \(consistency.mostConsistent.map { "Stabilste Dimension: \(displayDimensionName($0))" } ?? "")
                \(consistency.leastConsistent.map { "Variabelste Dimension: \(displayDimensionName($0))" } ?? "")
                Trend: \(trendText)

                WICHTIG: Wenn Streak > 3, erwähne den Streak lobend.
                Wenn Konsistenz > 60, betone die Verlässlichkeit.
                Wenn eine Dimension besonders inkonsistent ist, gib einen Tipp dafür.
                Wenn Mastery-Level gestiegen ist, feiere das.
                """
            } else {
                consistencyBlock = """
                KONSISTENZ: Noch \(max(0, 5 - consistency.totalSessions)) Sessions bis zur Konsistenz-Analyse.
                Ermutige den User dranzubleiben.
                """
            }
        } else {
            consistencyBlock = ""
        }

        let contextualBlock = (contextualInsights?.isEmpty == false) ? """
        VOICE-INTELLIGENCE-ENGINE:
        \(contextualInsights ?? "")
        """ : ""

        return """
        Session context:
        Pitch type: \(pitchType)
        
        Scores today (0-100):
        Overall: \(String(format: "%.0f", scores.overall))
        - Confidence: \(String(format: "%.0f", scores.confidence))
        - Energy: \(String(format: "%.0f", scores.energy))
        - Tempo: \(String(format: "%.0f", scores.tempo))
        - Gelassenheit: \(String(format: "%.0f", scores.stability))
        - Charisma: \(String(format: "%.0f", scores.charisma))

        Die 5 Dimensionen heißen: Confidence, Energy, Tempo, Gelassenheit, Charisma.
        Verwende IMMER diese Namen. Sage nie "Stability" oder "Clarity" als Dimension.
        
        Weakest dimension: \(displayDimensionName(weakestDimension(scores)))
        
        Heatmap:
        \(heatmapSummary)
        
        Last sessions:
        \(recentSessions.map { "- \($0.date): \($0.pitchType), Overall \(String(format: "%.0f", $0.overallScore)), Weakness: \($0.weakestDimension.rawValue)" }.joined(separator: "\n"))
        
        \(firstSessionContext)
        
        \(profileBlock)
        
        \(melodicBlock)

        \(spectralBlock)

        \(consistencyBlock)
        
        \(predictionBlock)

        \(contextualBlock)
        """
    }
    
    // MARK: - Mode-Specific Instructions
    
    private static func quickFeedbackInstructions(language: String) -> String {
        if language == "de" {
            return """
            MODUS: Quick Feedback.
            Du sprichst mit dem User direkt nach einer Übungssession.
            REGELN:
            - Exakt 2-4 Sätze. Kein Wort mehr.
            - Starte immer mit dem, was sich verändert hat (besser/schlechter) oder benenne bei erster Session stärksten Bereich und größten Hebel.
            - Danach genau ein konkreter Tipp für den nächsten Versuch.
            - Beziehe dich auf die Transkription, wenn möglich.
            - Keine Frage am Ende.
            - Kein generisches Lob.
            """
        } else {
            return """
            MODE: Quick Feedback.
            You're talking to the user right after practice.
            RULES:
            - Exactly 2-4 sentences. Not a word more.
            - Start with what changed (better/worse) or for first session: strongest area + biggest lever.
            - Then give exactly one concrete tip for the next attempt.
            - Reference transcription when possible.
            - No question at the end.
            - No generic praise.
            """
        }
    }
    
    private static func deepCoachingInstructions(language: String) -> String {
        if language == "de" {
            return """
            MODUS: Deep Coaching.
            Regeln:
            - 2-3 Absätze, ausführlich aber fokussiert
            - Alle 6 Dimensionen adressieren, Schwerpunkt auf Schwächen
            - Vergleich mit letzten 5 Sessions
            - 2-3 konkrete Übungen die sofort umsetzbar sind
            - Muster benennen wenn erkannt
            - Eine motivierende Frage am Ende
            - Keine Bullet Points – fließender Text
            """
        } else {
            return """
            MODE: Deep Coaching.
            Rules:
            - 2-3 paragraphs, detailed but focused
            - Address all 6 dimensions, emphasis on weaknesses
            - Compare with last 5 sessions
            - 2-3 concrete exercises that can be applied immediately
            - Name patterns when detected
            - One motivating question at the end
            - No bullet points – flowing text
            """
        }
    }

    private static func playbackCoachInstructions(language: String) -> String {
        if language == "de" {
            return """
            Zusaetzlich zum Quick Feedback, gib 3-5 zeitstempelbasierte Kommentare.
            Format EXAKT so (eine Zeile pro Kommentar):

            [TIMESTAMP:0.25|POSITIVE] Hier klingt deine Stimme sehr klar und ueberzeugend.
            [TIMESTAMP:0.50|NEGATIVE] Ab hier wirst du leiser - da geht Energie verloren.
            [TIMESTAMP:0.80|TIP] Versuche im Schlussteil lauter zu werden statt leiser.

            Regeln:
            - TIMESTAMP ist eine Zahl zwischen 0.0 und 1.0
            - Typ: POSITIVE, NEGATIVE oder TIP
            - Maximal 5 Kommentare, zeitlich sortiert
            - Jeder Kommentar in einer eigenen Zeile
            - Beziehe dich auf die Heatmap-Daten
            """
        }
        return """
        Additionally, provide 3-5 timestamped comments.
        Format EXACTLY like this (one line per comment):

        [TIMESTAMP:0.25|POSITIVE] Your voice sounds very clear and convincing here.
        [TIMESTAMP:0.50|NEGATIVE] You're getting quieter here - losing energy.
        [TIMESTAMP:0.80|TIP] Try to get louder in the final part instead of quieter.

        Rules:
        - TIMESTAMP is a number between 0.0 and 1.0
        - Type: POSITIVE, NEGATIVE, TIP
        - Maximum 5 comments, sorted by time
        - Each comment on its own line
        """
    }
    
    // MARK: - Strengths/Weaknesses Prompt
    
    static func strengthsWeaknessesPrompt(
        scores: DimensionScores,
        recentSessions: [SessionSummary]
    ) -> String {
        return """
        Based on this session (Overall: \(String(format: "%.0f", scores.overall)), \
        Confidence: \(String(format: "%.0f", scores.confidence)), \
        Energy: \(String(format: "%.0f", scores.energy)), \
        Tempo: \(String(format: "%.0f", scores.tempo)), \
        Gelassenheit: \(String(format: "%.0f", scores.stability)), \
        Charisma: \(String(format: "%.0f", scores.charisma)))
        
        And the last 5 sessions:
        \(recentSessions.map { "\($0.date): Overall \(String(format: "%.0f", $0.overallScore)), Weakness: \($0.weakestDimension.rawValue)" }.joined(separator: "\n"))
        
        Update strengths and weaknesses.
        Respond ONLY in this format:
        STRENGTHS:
        - {Strength 1}
        - {Strength 2}
        WEAKNESSES:
        - {Weakness 1}
        - {Weakness 2}
        Maximum 3 each. Specific, not generic.
        """
    }
    
    // MARK: - Profile Generation Prompt
    
    static func profileGenerationPrompt(sessions: [SessionSummary]) -> String {
        return """
        Based on 30 sessions, create a coaching profile for this user.
        Describe in 5-8 sentences:
        - Typical strengths and where they come from
        - Recurring weaknesses and their triggers
        - Which pitch types work best
        - Greatest progress since start
        - Next big lever for improvement
        
        Sessions:
        \(sessions.map { "\($0.date): \($0.pitchType), Overall \(String(format: "%.0f", $0.overallScore)), Weakness: \($0.weakestDimension.rawValue)" }.joined(separator: "\n"))
        """
    }

    static func weeklyReportPrompt(
        sessions: [SessionSummary],
        user: KlunaUser,
        currentAverage: DimensionScores,
        previousWeekAverage: DimensionScores?
    ) -> String {
        let previousBlock: String
        if let previousWeekAverage {
            previousBlock = """
            Previous week overall: \(String(format: "%.0f", previousWeekAverage.overall))
            Delta overall: \(String(format: "%+.0f", currentAverage.overall - previousWeekAverage.overall))
            """
        } else {
            previousBlock = "No previous week data available."
        }

        let languageRule = user.language == "de"
            ? "WICHTIG: Antworte ausschließlich auf Deutsch. Verwende 'du' und sprich den User mit Vornamen an."
            : "IMPORTANT: Respond only in English and address the user by first name."

        return """
        MODE: Weekly Coaching Report.
        \(languageRule)
        User: \(user.name)
        Goal: \(user.goal.rawValue)
        Sessions this week: \(sessions.count)
        Current week averages:
        Overall: \(String(format: "%.0f", currentAverage.overall))
        Confidence: \(String(format: "%.0f", currentAverage.confidence))
        Energy: \(String(format: "%.0f", currentAverage.energy))
        Tempo: \(String(format: "%.0f", currentAverage.tempo))
        Gelassenheit: \(String(format: "%.0f", currentAverage.stability))
        Charisma: \(String(format: "%.0f", currentAverage.charisma))

        \(previousBlock)

        Sessions:
        \(sessions.map { "\($0.date): \($0.pitchType), overall \(String(format: "%.0f", $0.overallScore)), weakest \($0.weakestDimension.rawValue)" }.joined(separator: "\n"))

        Write MAX 3-4 short sentences and no more than ~60 words:
        1) strongest dimension with a concrete number,
        2) biggest improvement potential with one concrete tip,
        3) motivating close.
        No generic praise. Flowing text only.
        """
    }
    
    // MARK: - Helpers
    
    private static func weakestDimension(_ scores: DimensionScores) -> String {
        let all: [(PerformanceDimension, Double)] = [
            (.confidence, scores.confidence),
            (.energy, scores.energy),
            (.tempo, scores.tempo),
            (.stability, scores.stability),
            (.charisma, scores.charisma),
        ]
        return all.min(by: { $0.1 < $1.1 })?.0.rawValue ?? "unknown"
    }

    private static func displayDimensionName(_ key: String) -> String {
        switch key.lowercased() {
        case "confidence": return "Confidence"
        case "energy": return "Energy"
        case "tempo": return "Tempo"
        case "stability": return "Gelassenheit"
        case "charisma": return "Charisma"
        case "clarity": return "Praesenz"
        default: return key
        }
    }

    private static func goalContext(for user: KlunaUser, language: String) -> String {
        if language == "de" {
            switch user.goal {
            case .pitches:
                return "Zielkontext: Fokus auf Überzeugungskraft, Confidence und starkes Finish für Pitches."
            case .content:
                return "Zielkontext: Fokus auf Energie, Variation und Zuhörer-Bindung für Content/Podcast."
            case .interviews:
                return "Zielkontext: Fokus auf Glaubwürdigkeit, ruhiges Tempo und Gelassenheit für Interviews."
            case .confidence:
                return "Zielkontext: Fokus auf Gelassenheit, Confidence und natürliches Tempo im Alltag."
            }
        }
        switch user.goal {
        case .pitches:
            return "Goal context: prioritize persuasion, confidence and strong endings for pitches."
        case .content:
            return "Goal context: prioritize energy, variation and listener retention for content."
        case .interviews:
            return "Goal context: prioritize credibility, calm tempo and clear articulation for interviews."
        case .confidence:
            return "Goal context: prioritize calmness, confidence and natural tempo for everyday speaking."
        }
    }
}
