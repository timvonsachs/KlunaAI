import Foundation

struct VoiceDNAProfile: Codable {
    let authority: Float
    let charisma: Float
    let warmth: Float
    let composure: Float

    var dominantQuadrant: String {
        let scores: [(String, Float)] = [
            ("Authority", authority),
            ("Charisma", charisma),
            ("Warmth", warmth),
            ("Composure", composure),
        ]
        return scores.max(by: { $0.1 < $1.1 })?.0 ?? "Balanced"
    }

    var growthQuadrant: String {
        let scores: [(String, Float)] = [
            ("Authority", authority),
            ("Charisma", charisma),
            ("Warmth", warmth),
            ("Composure", composure),
        ]
        return scores.min(by: { $0.1 < $1.1 })?.0 ?? "Balanced"
    }

    func description() -> String {
        let dominantText: String
        switch dominantQuadrant {
        case "Authority":
            dominantText = "Du wirkst souveraen und bestimmt."
        case "Charisma":
            dominantText = "Du wirkst lebendig und mitreissend."
        case "Warmth":
            dominantText = "Du wirkst warm und einladend."
        case "Composure":
            dominantText = "Du wirkst ruhig und kontrolliert."
        default:
            dominantText = "Du hast ein ausgewogenes Stimmprofil."
        }

        let growthText: String
        switch growthQuadrant {
        case "Authority":
            growthText = "Wachstum: Mehr Pausenfuehrung und ruhige Bestimmtheit trainieren."
        case "Charisma":
            growthText = "Wachstum: Mehr Dynamik und praesente Energie in den Satzboegen."
        case "Warmth":
            growthText = "Wachstum: Mehr resonante Waerme und koerperreiche Klangfarbe."
        case "Composure":
            growthText = "Wachstum: Mehr Stimmruhe unter Druck durch stabile Atmung."
        default:
            growthText = "Wachstum: Profil ist aktuell gut ausbalanciert."
        }
        return "\(dominantText) \(growthText)"
    }
}

enum VoiceDNA {
    static func calculateProfile(
        jitterScore: Float,
        shimmerScore: Float,
        hnrScore: Float,
        presenceScore: Float,
        airScore: Float,
        bodyScore: Float,
        warmthScore: Float,
        loudnessScore: Float,
        dynamicRangeScore: Float,
        f0RangeScore: Float,
        loudnessVariationScore: Float,
        speechRateScore: Float,
        pauseDurScore: Float,
        pauseRateScore: Float,
        articulationScore: Float,
        qualityGate: Float
    ) -> VoiceDNAProfile {
        let _ = airScore
        let _ = pauseRateScore
        let _ = articulationScore

        let authority = clamp(
            pauseDurScore * 0.25
                + speechRateScore * 0.20
                + hnrScore * 0.20
                + jitterScore * 0.15
                + dynamicRangeScore * 0.20
        )

        let charismaRaw = clamp(
            dynamicRangeScore * 0.25
                + loudnessVariationScore * 0.25
                + f0RangeScore * 0.25
                + presenceScore * 0.25
        )
        let charisma = clamp(charismaRaw * qualityGate)

        let warmth = clamp(
            warmthScore * 0.30
                + bodyScore * 0.20
                + hnrScore * 0.25
                + speechRateScore * 0.25
        )

        let composure = clamp(
            jitterScore * 0.30
                + shimmerScore * 0.25
                + hnrScore * 0.25
                + loudnessScore * 0.20
        )

        return VoiceDNAProfile(
            authority: authority,
            charisma: charisma,
            warmth: warmth,
            composure: composure
        )
    }

    private static func clamp(_ value: Float) -> Float {
        min(100, max(0, value))
    }
}
