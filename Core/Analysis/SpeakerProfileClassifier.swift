import Foundation

enum SpeakerProfile: String, CaseIterable, Codable {
    case nervous = "Der Nervöse"
    case reserved = "Der Zurückhaltende"
    case everyday = "Der Alltagssprecher"
    case structured = "Der Strukturierte"
    case engaged = "Der Engagierte"
    case professional = "Der Professionelle"
    case persuader = "Der Überzeuger"
    case charismatic = "Der Charismatische"

    var rank: Int {
        switch self {
        case .nervous: return 1
        case .reserved: return 2
        case .everyday: return 3
        case .structured: return 4
        case .engaged: return 5
        case .professional: return 6
        case .persuader: return 7
        case .charismatic: return 8
        }
    }

    var shortDescription: String {
        switch self {
        case .nervous:
            return "Hohes Tempo, wenig Pausen, Stimme angespannt. Typisch bei Nervosität oder Lampenfieber."
        case .reserved:
            return "Leise, gleichförmig, wenig Dynamik. Typisch bei Unsicherheit oder Müdigkeit."
        case .everyday:
            return "Solide Grundlage in allen Bereichen. Der natürliche Ausgangspunkt."
        case .structured:
            return "Gutes Tempo und klare Pausen, aber die Stimme braucht mehr Energie und Dynamik."
        case .engaged:
            return "Hohe Energie und Begeisterung, aber manchmal auf Kosten der Struktur."
        case .professional:
            return "Alle Dimensionen auf gutem Niveau. Klar, kontrolliert, kompetent."
        case .persuader:
            return "Bewusste Dynamik, strategische Pausen, die Stimme führt den Zuhörer."
        case .charismatic:
            return "Maximale bewusste Dynamik, perfektes Timing, volle stimmliche Bandbreite."
        }
    }

    var nextStepAdvice: String? {
        switch self {
        case .nervous:
            return "Atme vor dem Sprechen tief ein. Konzentriere dich auf bewusste Pausen nach jedem Satz."
        case .reserved:
            return "Sprich lauter. Nicht schreien – aber so als würde die hinterste Reihe dich hören müssen."
        case .everyday:
            return "Experimentiere mit Tonhöhen-Variation. Betone Schlüsselwörter bewusst höher und lauter."
        case .structured:
            return "Lass mehr Energie in deine Stimme. Stell dir vor du erzählst eine spannende Geschichte."
        case .engaged:
            return "Baue strategische Pausen ein. Die Stille nach einem wichtigen Punkt wirkt stärker als Worte."
        case .professional:
            return "Variiere deine Dynamik bewusster: leise → laut → Pause → leise. Das erzeugt Spannung."
        case .persuader:
            return "Arbeite an den letzten 5%: Timing der Pausen perfektionieren, Final Lowering verstärken."
        case .charismatic:
            return nil
        }
    }

    var nextProfile: SpeakerProfile? {
        let all = SpeakerProfile.allCases
        guard let idx = all.firstIndex(of: self), idx + 1 < all.count else { return nil }
        return all[idx + 1]
    }

    var icon: String {
        switch self {
        case .nervous: return "😰"
        case .reserved: return "🤫"
        case .everyday: return "🗣️"
        case .structured: return "📋"
        case .engaged: return "🔥"
        case .professional: return "💼"
        case .persuader: return "🎯"
        case .charismatic: return "⭐"
        }
    }

    var colorHex: String {
        switch self {
        case .nervous: return "#FF4444"
        case .reserved: return "#FF8844"
        case .everyday: return "#FFBB33"
        case .structured: return "#88CC44"
        case .engaged: return "#44BB88"
        case .professional: return "#4488CC"
        case .persuader: return "#7744CC"
        case .charismatic: return "#CC44BB"
        }
    }
}

struct NormalizedFeatureVector: Codable {
    let loudness: Double
    let loudnessDynamics: Double
    let f0Mean: Double
    let f0Range: Double
    let f0StdDev: Double
    let jitter: Double
    let shimmer: Double
    let hnr: Double
    let speechRate: Double
    let pauseRate: Double
    let pauseDuration: Double
    let formantDispersion: Double

    func distance(to other: NormalizedFeatureVector) -> Double {
        let diffs: [Double] = [
            loudness - other.loudness,
            loudnessDynamics - other.loudnessDynamics,
            f0Mean - other.f0Mean,
            f0Range - other.f0Range,
            f0StdDev - other.f0StdDev,
            jitter - other.jitter,
            shimmer - other.shimmer,
            hnr - other.hnr,
            speechRate - other.speechRate,
            pauseRate - other.pauseRate,
            pauseDuration - other.pauseDuration,
            formantDispersion - other.formantDispersion
        ]
        return sqrt(diffs.reduce(0) { $0 + $1 * $1 })
    }

    var asDictionary: [String: Double] {
        [
            "loudness": loudness,
            "loudnessDynamics": loudnessDynamics,
            "f0Mean": f0Mean,
            "f0Range": f0Range,
            "f0StdDev": f0StdDev,
            "jitter": jitter,
            "shimmer": shimmer,
            "hnr": hnr,
            "speechRate": speechRate,
            "pauseRate": pauseRate,
            "pauseDuration": pauseDuration,
            "formantDispersion": formantDispersion
        ]
    }
}

struct ProfileCentroids {
    static let nervous = NormalizedFeatureVector(
        loudness: 0.45, loudnessDynamics: 0.20, f0Mean: 0.70, f0Range: 0.30, f0StdDev: 0.40,
        jitter: 0.25, shimmer: 0.30, hnr: 0.35,
        speechRate: 0.80, pauseRate: 0.15, pauseDuration: 0.10, formantDispersion: 0.40
    )

    static let reserved = NormalizedFeatureVector(
        loudness: 0.15, loudnessDynamics: 0.10, f0Mean: 0.35, f0Range: 0.10, f0StdDev: 0.10,
        jitter: 0.70, shimmer: 0.60, hnr: 0.50,
        speechRate: 0.30, pauseRate: 0.25, pauseDuration: 0.50, formantDispersion: 0.30
    )

    static let everyday = NormalizedFeatureVector(
        loudness: 0.45, loudnessDynamics: 0.35, f0Mean: 0.45, f0Range: 0.35, f0StdDev: 0.35,
        jitter: 0.55, shimmer: 0.55, hnr: 0.55,
        speechRate: 0.50, pauseRate: 0.40, pauseDuration: 0.40, formantDispersion: 0.50
    )

    static let structured = NormalizedFeatureVector(
        loudness: 0.40, loudnessDynamics: 0.25, f0Mean: 0.45, f0Range: 0.30, f0StdDev: 0.30,
        jitter: 0.65, shimmer: 0.65, hnr: 0.65,
        speechRate: 0.50, pauseRate: 0.65, pauseDuration: 0.55, formantDispersion: 0.50
    )

    static let engaged = NormalizedFeatureVector(
        loudness: 0.70, loudnessDynamics: 0.55, f0Mean: 0.60, f0Range: 0.55, f0StdDev: 0.55,
        jitter: 0.45, shimmer: 0.45, hnr: 0.50,
        speechRate: 0.65, pauseRate: 0.30, pauseDuration: 0.25, formantDispersion: 0.60
    )

    static let professional = NormalizedFeatureVector(
        loudness: 0.60, loudnessDynamics: 0.55, f0Mean: 0.50, f0Range: 0.55, f0StdDev: 0.55,
        jitter: 0.70, shimmer: 0.70, hnr: 0.70,
        speechRate: 0.55, pauseRate: 0.60, pauseDuration: 0.55, formantDispersion: 0.65
    )

    static let persuader = NormalizedFeatureVector(
        loudness: 0.65, loudnessDynamics: 0.75, f0Mean: 0.50, f0Range: 0.75, f0StdDev: 0.70,
        jitter: 0.70, shimmer: 0.70, hnr: 0.70,
        speechRate: 0.50, pauseRate: 0.75, pauseDuration: 0.65, formantDispersion: 0.70
    )

    static let charismatic = NormalizedFeatureVector(
        loudness: 0.70, loudnessDynamics: 0.85, f0Mean: 0.55, f0Range: 0.85, f0StdDev: 0.80,
        jitter: 0.75, shimmer: 0.75, hnr: 0.75,
        speechRate: 0.55, pauseRate: 0.80, pauseDuration: 0.70, formantDispersion: 0.75
    )

    static func centroid(for profile: SpeakerProfile) -> NormalizedFeatureVector {
        switch profile {
        case .nervous: return nervous
        case .reserved: return reserved
        case .everyday: return everyday
        case .structured: return structured
        case .engaged: return engaged
        case .professional: return professional
        case .persuader: return persuader
        case .charismatic: return charismatic
        }
    }
}

struct FeatureNormalizer {
    private static func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0.5 }
        return Swift.max(0, Swift.min(1, (value - min) / (max - min)))
    }

    static func normalize(features: [String: Double]) -> NormalizedFeatureVector {
        let loudnessRMS = features[FeatureKeys.loudnessRMS] ?? features[FeatureKeys.energy] ?? 0.3
        let loudnessStdDev = features[FeatureKeys.loudnessStdDev] ?? 0.05
        let f0Mean = features[FeatureKeys.f0Mean] ?? 120
        let f0RangeST = features[FeatureKeys.f0RangeST] ?? features[FeatureKeys.f0Range] ?? 10
        let f0StdDev = features[FeatureKeys.f0StdDev] ?? features[FeatureKeys.f0Variability] ?? 25
        let jitter = features[FeatureKeys.jitter] ?? 0.02
        let shimmer = features[FeatureKeys.shimmer] ?? 0.05
        let hnr = features[FeatureKeys.hnr] ?? 15
        let speechRate = features[FeatureKeys.speechRate] ?? 4.0
        let pauseRate = features[FeatureKeys.pauseRate] ?? features[FeatureKeys.pauseDistribution] ?? 3.0
        let pauseDuration = features[FeatureKeys.meanPauseDuration] ?? features[FeatureKeys.pauseDuration] ?? 0.5
        let formantDisp = features[FeatureKeys.formantDispersion] ?? 1000

        return NormalizedFeatureVector(
            loudness: normalize(loudnessRMS, min: 0.05, max: 0.60),
            loudnessDynamics: normalize(loudnessStdDev, min: 0.01, max: 0.20),
            f0Mean: normalize(f0Mean, min: 80, max: 200),
            f0Range: normalize(f0RangeST, min: 2, max: 22),
            f0StdDev: normalize(f0StdDev, min: 5, max: 55),
            jitter: 1.0 - normalize(jitter, min: 0.002, max: 0.06),
            shimmer: 1.0 - normalize(shimmer, min: 0.01, max: 0.15),
            hnr: normalize(hnr, min: 5, max: 25),
            speechRate: normalize(speechRate, min: 2.0, max: 6.0),
            pauseRate: normalize(pauseRate, min: 0, max: 8),
            pauseDuration: normalize(pauseDuration, min: 0.1, max: 2.5),
            formantDispersion: normalize(formantDisp, min: 500, max: 1400)
        )
    }
}

struct ProfileClassification: Codable {
    let profile: SpeakerProfile
    let confidence: Double
    let distance: Double
    let secondaryProfile: SpeakerProfile?

    var displayText: String {
        if let secondary = secondaryProfile, secondary.rank > profile.rank {
            return "\(profile.rawValue), Tendenz \(secondary.rawValue)"
        }
        return profile.rawValue
    }

    var coachingMessage: String {
        var message = profile.shortDescription
        if let advice = profile.nextStepAdvice, let next = profile.nextProfile {
            message += " Nächstes Ziel: \(next.rawValue). \(advice)"
        }
        return message
    }
}

final class SpeakerProfileClassifier {
    static func classify(features: [String: Double]) -> ProfileClassification {
        let normalized = FeatureNormalizer.normalize(features: features)

        var bestProfile: SpeakerProfile = .everyday
        var bestDistance: Double = .infinity
        var allDistances: [(SpeakerProfile, Double)] = []

        for profile in SpeakerProfile.allCases {
            let centroid = ProfileCentroids.centroid(for: profile)
            let distance = normalized.distance(to: centroid)
            allDistances.append((profile, distance))
            if distance < bestDistance {
                bestDistance = distance
                bestProfile = profile
            }
        }

        allDistances.sort { $0.1 < $1.1 }
        let confidence: Double = allDistances.count >= 2
            ? min(1.0, (allDistances[1].1 - allDistances[0].1) / 0.5)
            : 1.0
        let secondary = allDistances.count >= 2 ? allDistances[1].0 : nil

        return ProfileClassification(
            profile: bestProfile,
            confidence: confidence,
            distance: bestDistance,
            secondaryProfile: secondary
        )
    }
}
