import Foundation

struct VoiceInsight: Codable {
    let title: String
    let body: String
    let quadrant: String
    let metric: String
    let value: Float
    let benchmark: String
    let isStrength: Bool
    let sessionNumber: Int
}

enum SubFeatureType {
    case pausen
    case stimmstabilitaet
}

final class DiscoveryStateManager {
    static let shared = DiscoveryStateManager()

    private enum Keys {
        static let discoverySessionCount = "voiceDNA_discoverySessionCount"
        static let previousInsights = "voiceDNA_previousInsights"
        static let firstSessionDNA = "voiceDNA_firstSessionDNA"
        static let selectedQuadrant = "voiceDNA_selectedQuadrant"
    }

    private init() {}

    var discoverySessionCount: Int {
        get { UserDefaults.standard.integer(forKey: Keys.discoverySessionCount) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.discoverySessionCount) }
    }

    var isDiscoveryComplete: Bool {
        discoverySessionCount >= 7
    }

    var previousInsights: [String] {
        get { UserDefaults.standard.stringArray(forKey: Keys.previousInsights) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Keys.previousInsights) }
    }

    var selectedQuadrant: String? {
        get { UserDefaults.standard.string(forKey: Keys.selectedQuadrant) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.selectedQuadrant) }
    }

    func recordSession(dna: VoiceDNAProfile, shownQuadrant: String?) {
        discoverySessionCount += 1
        if discoverySessionCount == 1 {
            UserDefaults.standard.set([
                "authority": Double(dna.authority),
                "charisma": Double(dna.charisma),
                "warmth": Double(dna.warmth),
                "composure": Double(dna.composure),
            ], forKey: Keys.firstSessionDNA)
        }
        if let shownQuadrant, shownQuadrant != "all", !shownQuadrant.isEmpty {
            var history = previousInsights
            if !history.contains(shownQuadrant) {
                history.append(shownQuadrant)
                previousInsights = history
            }
        }
    }

    func getFirstSessionDNA() -> VoiceDNAProfile? {
        guard let dict = UserDefaults.standard.dictionary(forKey: Keys.firstSessionDNA) else { return nil }
        return VoiceDNAProfile(
            authority: Float(dict["authority"] as? Double ?? 0),
            charisma: Float(dict["charisma"] as? Double ?? 0),
            warmth: Float(dict["warmth"] as? Double ?? 0),
            composure: Float(dict["composure"] as? Double ?? 0)
        )
    }
}

enum InsightEngine {
    static func generateInsight(
        dna: VoiceDNAProfile,
        sessionCount: Int,
        previousInsights: [String],
        rawFeatures: [String: Double] = [:]
    ) -> VoiceInsight {
        let _ = previousInsights
        let discoverySession = min(max(sessionCount, 1), 7)
        switch discoverySession {
        case 1:
            return generateStrengthInsight(dna: dna, rank: 1)
        case 2:
            return generateGrowthInsight(dna: dna, rank: 1)
        case 3:
            return generateStrengthInsight(dna: dna, rank: 2)
        case 4:
            return generateSubFeatureInsight(dna: dna, rawFeatures: rawFeatures, type: .pausen, sessionNumber: 4)
        case 5:
            return generateSubFeatureInsight(dna: dna, rawFeatures: rawFeatures, type: .stimmstabilitaet, sessionNumber: 5)
        case 6:
            return generateTrendInsight(dna: dna)
        case 7:
            return generateProfileReveal(dna: dna)
        default:
            return generateSituativeInsight(dna: dna)
        }
    }

    static func generateStrengthInsight(dna: VoiceDNAProfile, rank: Int) -> VoiceInsight {
        let sorted = quadrants(dna: dna).sorted { $0.1 > $1.1 }
        let index = max(0, min(sorted.count - 1, rank - 1))
        let (quadrant, score) = sorted[index]

        let title: String
        let body: String
        switch quadrant {
        case "Authority":
            title = "Natuerliche Autoritaet"
            body = "Deine Stimme hat etwas das die meisten Menschen trainieren muessen: natuerliche Autoritaet. Dein Tempo, deine Pausen und deine Stimmkontrolle signalisieren Souveraenitaet. Authority-Score: \(Int(score))/100."
        case "Charisma":
            title = "Magnetische Energie"
            body = "Deine Stimme ist lebendig. Du nutzt Dynamik-Kontraste, Tempo-Wechsel und Tonhoehen-Variation auf einem Niveau das Zuhoerer fesselt. Charisma-Score: \(Int(score))/100."
        case "Warmth":
            title = "Einladende Waerme"
            body = "Deine Stimme hat eine Qualitaet die Menschen dazu bringt sich zu oeffnen. Resonanz, Klangfarbe und Tempo erzeugen Vertrauen. Warmth-Score: \(Int(score))/100."
        case "Composure":
            title = "Innere Ruhe"
            body = "Deine Stimme ist ungewoehnlich stabil. Wenig Tremor, gleichmaessige Lautstaerke, sauberer Klang. Das signalisiert: dieser Mensch ist bei sich. Composure-Score: \(Int(score))/100."
        default:
            title = "Dein Stimmprofil"
            body = "Deine Stimme zeigt ein ausgewogenes Profil."
        }

        return VoiceInsight(
            title: title,
            body: body,
            quadrant: quadrant,
            metric: "",
            value: score,
            benchmark: "ueberdurchschnittlich",
            isStrength: true,
            sessionNumber: rank == 1 ? 1 : 3
        )
    }

    static func generateGrowthInsight(dna: VoiceDNAProfile, rank: Int) -> VoiceInsight {
        let sorted = quadrants(dna: dna).sorted { $0.1 < $1.1 }
        let index = max(0, min(sorted.count - 1, rank - 1))
        let (quadrant, score) = sorted[index]

        let title: String
        let body: String
        switch quadrant {
        case "Authority":
            title = "Wachstumsfeld: Autoritaet"
            body = "Deine Stimme hat Potenzial fuer mehr Praesenz. Laengere Pausen, ein ruhigeres Tempo und bewusste Betonung koennen deine natuerliche Autoritaet staerken. Aktuell: \(Int(score))/100."
        case "Charisma":
            title = "Wachstumsfeld: Charisma"
            body = "Deine Stimme ist kontrolliert - aber sie koennte mehr Kontraste vertragen. Mehr Dynamik, mehr Variation, mehr Ueberraschung. Das ist trainierbar. Aktuell: \(Int(score))/100."
        case "Warmth":
            title = "Wachstumsfeld: Waerme"
            body = "Deine Stimme ist klar und praezise, aber sie koennte waermer klingen. Mehr Resonanz im Brustton, ein etwas langsameres Tempo bei emotionalen Momenten. Aktuell: \(Int(score))/100."
        case "Composure":
            title = "Wachstumsfeld: Gelassenheit"
            body = "Deine Stimme zeigt Energie - aber auch Anspannung. Mehr Stimmkontrolle und Gleichmaessigkeit wuerden deine Wirkung verstaerken. Aktuell: \(Int(score))/100."
        default:
            title = "Dein Wachstumsfeld"
            body = "Jeder Bereich hat Potenzial."
        }

        return VoiceInsight(
            title: title,
            body: body,
            quadrant: quadrant,
            metric: "",
            value: score,
            benchmark: "Wachstumspotenzial",
            isStrength: false,
            sessionNumber: 2
        )
    }

    static func generateSubFeatureInsight(
        dna: VoiceDNAProfile,
        rawFeatures: [String: Double],
        type: SubFeatureType,
        sessionNumber: Int
    ) -> VoiceInsight {
        switch type {
        case .pausen:
            let pauseDur = rawFeatures[FeatureKeys.meanPauseDuration] ?? rawFeatures[FeatureKeys.pauseDuration] ?? 0.0
            let pauseRate = rawFeatures[FeatureKeys.pauseRate] ?? 0.0
            let body = "Deine durchschnittliche Pause liegt bei \(String(format: "%.2f", pauseDur))s bei \(Int(pauseRate))/min. Bewusste Pausen geben deinen Aussagen Gewicht und steigern Authority."
            return VoiceInsight(
                title: "Die Macht deiner Pausen",
                body: body,
                quadrant: "Authority",
                metric: "PauseDur",
                value: dna.authority,
                benchmark: "signalisiert Kontrolle",
                isStrength: true,
                sessionNumber: sessionNumber
            )
        case .stimmstabilitaet:
            let hnr = rawFeatures[FeatureKeys.hnr] ?? 0.0
            let jitter = rawFeatures[FeatureKeys.jitter] ?? 0.0
            let body = "Dein Klang ist stabil: HNR \(String(format: "%.2f", hnr)), Jitter \(String(format: "%.3f", jitter)). Diese Kombination wirkt ruhig, praezise und glaubwuerdig."
            return VoiceInsight(
                title: "Stimmstabilitaet entdeckt",
                body: body,
                quadrant: "Composure",
                metric: "HNR/Jitter",
                value: dna.composure,
                benchmark: "solide Basis",
                isStrength: true,
                sessionNumber: sessionNumber
            )
        }
    }

    static func generateTrendInsight(dna: VoiceDNAProfile) -> VoiceInsight {
        let first = DiscoveryStateManager.shared.getFirstSessionDNA()
        guard let first else {
            return VoiceInsight(
                title: "Deine Entwicklung",
                body: "Dein Profil wird klarer. Noch eine Session bis zur vollstaendigen Voice DNA.",
                quadrant: dna.dominantQuadrant,
                metric: "Trend",
                value: max(dna.authority, dna.charisma, dna.warmth, dna.composure),
                benchmark: "aufwaerts",
                isStrength: true,
                sessionNumber: 6
            )
        }

        let deltas: [(String, Float)] = [
            ("Authority", dna.authority - first.authority),
            ("Charisma", dna.charisma - first.charisma),
            ("Warmth", dna.warmth - first.warmth),
            ("Composure", dna.composure - first.composure),
        ]
        let best = deltas.max(by: { $0.1 < $1.1 }) ?? ("Authority", 0)
        return VoiceInsight(
            title: "So hast du dich veraendert",
            body: "Seit deiner ersten Discovery-Session hat sich \(best.0) um \(Int(best.1)) Punkte verbessert. Du trainierst nicht nur - du veraenderst Wirkung.",
            quadrant: best.0,
            metric: "Delta",
            value: max(0, best.1),
            benchmark: "klarer Fortschritt",
            isStrength: true,
            sessionNumber: 6
        )
    }

    static func generateProfileReveal(dna: VoiceDNAProfile) -> VoiceInsight {
        let _ = dna
        return VoiceInsight(
            title: "Deine Voice DNA",
            body: "7 Tage. 7 Erkenntnisse. Hier ist dein vollstaendiges Stimmprofil.",
            quadrant: "all",
            metric: "",
            value: 0,
            benchmark: "",
            isStrength: true,
            sessionNumber: 7
        )
    }

    static func generateSituativeInsight(dna: VoiceDNAProfile) -> VoiceInsight {
        let dominant = dna.dominantQuadrant
        return VoiceInsight(
            title: "Dein aktueller Wirkmodus",
            body: "Heute dominiert \(dominant). Nutze diesen Modus bewusst je nach Situation - oder trainiere gezielt dein Wachstumsfeld.",
            quadrant: dominant,
            metric: "Mode",
            value: max(dna.authority, dna.charisma, dna.warmth, dna.composure),
            benchmark: "situativ",
            isStrength: true,
            sessionNumber: 8
        )
    }

    private static func quadrants(dna: VoiceDNAProfile) -> [(String, Float)] {
        [
            ("Authority", dna.authority),
            ("Charisma", dna.charisma),
            ("Warmth", dna.warmth),
            ("Composure", dna.composure),
        ]
    }
}
