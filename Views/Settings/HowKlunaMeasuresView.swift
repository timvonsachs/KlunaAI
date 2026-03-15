import SwiftUI

struct HowKlunaMeasuresView: View {
    let language: String
    @State private var expandedDimension: PerformanceDimension?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: KlunaSpacing.lg) {
                VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
                    Text(language == "de"
                        ? "Kluna hört nicht was du sagst. Kluna hört wie du klingst."
                        : "Kluna doesn't hear what you say. Kluna hears how you sound."
                    )
                    .font(KlunaFont.heading(18))
                    .foregroundColor(.klunaPrimary)

                    Text(language == "de"
                        ? "Deine Stimme wird in 14 akustische Merkmale zerlegt. Diese Marker korrelieren in der Forschung mit Charisma, Überzeugungskraft und Vertrauen. Es werden keine Inhalte ausgewertet, sondern nur der Klang."
                        : "Your voice is broken down into 14 acoustic features. Research links these markers to charisma, persuasiveness, and trust. Content is not evaluated, only the sound."
                    )
                    .font(KlunaFont.body(14))
                    .foregroundColor(.klunaSecondary)
                    .lineSpacing(3)
                }
                .padding(.horizontal, KlunaSpacing.md)

                ForEach(dimensionExplanations, id: \.dimension) { explanation in
                    DimensionExplanationCard(
                        explanation: explanation,
                        language: language,
                        isExpanded: expandedDimension == explanation.dimension,
                        onTap: {
                            withAnimation(KlunaAnimation.spring) {
                                expandedDimension = expandedDimension == explanation.dimension ? nil : explanation.dimension
                            }
                        }
                    )
                }

                VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
                    Text(language == "de" ? "Dein Overall Score" : "Your Overall Score")
                        .font(KlunaFont.heading(16))
                        .foregroundColor(.klunaPrimary)

                    Text(language == "de"
                        ? "Der Overall Score kombiniert alle 6 Dimensionen. 60% kommen aus wissenschaftlichen Benchmarks (objektive Qualität), 40% aus deiner persönlichen Baseline (dein Fortschritt gegenüber dir selbst). Mit jeder Session wird die Bewertung persönlicher."
                        : "The overall score combines all 6 dimensions. 60% comes from scientific benchmarks (objective quality), 40% from your personal baseline (progress vs yourself). With every session, the score becomes more personal."
                    )
                    .font(KlunaFont.body(14))
                    .foregroundColor(.klunaSecondary)
                    .lineSpacing(3)
                }
                .padding(KlunaSpacing.md)
                .background(Color.klunaSurface)
                .cornerRadius(KlunaRadius.card)
                .padding(.horizontal, KlunaSpacing.md)

                VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
                    HStack(spacing: KlunaSpacing.sm) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.klunaAccent)
                        Text(language == "de" ? "Wissenschaftliche Basis" : "Scientific Basis")
                            .font(KlunaFont.heading(15))
                            .foregroundColor(.klunaAccent)
                    }

                    Text(language == "de"
                        ? "Klunas Scoring basiert auf peer-reviewed Forschung zu Prosodie, Stimmstabilität und Überzeugungskraft. Der Fokus: trainierbare Biomarker statt subjektiver Gefühle."
                        : "Kluna's scoring is based on peer-reviewed research on prosody, voice stability, and persuasiveness. The focus: trainable biomarkers instead of subjective impressions."
                    )
                    .font(KlunaFont.body(13))
                    .foregroundColor(.klunaMuted)
                    .lineSpacing(3)
                }
                .padding(KlunaSpacing.md)
                .background(Color.klunaSurface)
                .cornerRadius(KlunaRadius.card)
                .padding(.horizontal, KlunaSpacing.md)
            }
            .padding(.top, KlunaSpacing.md)
        }
        .background(Color.klunaBackground.ignoresSafeArea())
        .navigationTitle(language == "de" ? "Wie Kluna misst" : "How Kluna measures")
        .navigationBarTitleDisplayMode(.large)
    }

    var dimensionExplanations: [DimensionExplanation] {
        [
            DimensionExplanation(
                dimension: .confidence,
                icon: "shield.fill",
                whatItMeasuresDE: "Wie sicher und klar deine Stimme klingt.",
                whatItMeasuresEN: "How confident and clear your voice sounds.",
                howItWorksDE: "Kluna misst Jitter und das Ende deiner Satzmelodie. Wenig Jitter plus stabile Endungen steigern die Confidence.",
                howItWorksEN: "Kluna measures jitter and your sentence-end melody. Low jitter plus stable endings increase confidence.",
                biomarkers: ["Jitter", "F0 contour", "HNR"],
                tipDE: "Senke die Stimme am Satzende bewusst leicht ab.",
                tipEN: "Slightly lower your voice at sentence endings.",
                color: .klunaGreen
            ),
            DimensionExplanation(
                dimension: .energy,
                icon: "bolt.fill",
                whatItMeasuresDE: "Wie viel Kraft und Präsenz in deiner Stimme steckt.",
                whatItMeasuresEN: "How much power and presence your voice carries.",
                howItWorksDE: "Kluna bewertet Lautstärke und Dynamik. Nicht nur laut zählt, sondern der Wechsel zwischen ruhig und kraftvoll.",
                howItWorksEN: "Kluna evaluates loudness and dynamics. Not only loud matters, but the shift between calm and powerful.",
                biomarkers: ["Loudness", "Loudness variance", "Dynamic range"],
                tipDE: "Nutze mehr Luft und setze ein klares, kräftiges Finale.",
                tipEN: "Use more breath support and finish with clear projection.",
                color: .klunaOrange
            ),
            DimensionExplanation(
                dimension: .tempo,
                icon: "metronome.fill",
                whatItMeasuresDE: "Ob dein Sprechtempo passend ist und ob du Pausen setzt.",
                whatItMeasuresEN: "Whether your speaking pace is optimal and if you use pauses.",
                howItWorksDE: "Kluna misst Sprechrate plus Pausenverteilung. Ziel ist ein kontrolliertes Tempo mit bewussten Spannungs-Pausen.",
                howItWorksEN: "Kluna measures speech rate plus pause distribution. The goal is controlled pace with intentional pauses.",
                biomarkers: ["Speech rate", "Pause duration", "Pause distribution"],
                tipDE: "Nach Kernsätzen 1-2 Sekunden Stille stehen lassen.",
                tipEN: "Leave 1-2 seconds of silence after key statements.",
                color: .klunaAccent
            ),
            DimensionExplanation(
                dimension: .stability,
                icon: "waveform.path.ecg",
                whatItMeasuresDE: "Wie ruhig und kontrolliert deine Stimme wirkt.",
                whatItMeasuresEN: "How calm and controlled your voice sounds.",
                howItWorksDE: "Kluna kombiniert Stimmbandsignale, Pausen, Wärme und Körper-Anteil zu einem Gelassenheits-Score.",
                howItWorksEN: "Kluna combines vocal fold stability, pauses, warmth and body resonance into a calmness score.",
                biomarkers: ["Jitter", "Shimmer", "Warmth", "Body", "Pause duration"],
                tipDE: "Atme tiefer und lass nach Kernaussagen bewusst Ruhe stehen.",
                tipEN: "Breathe lower and keep deliberate pauses after key statements.",
                color: .klunaRed
            ),
            DimensionExplanation(
                dimension: .charisma,
                icon: "sparkles",
                whatItMeasuresDE: "Wie dynamisch und fesselnd dein Sprechstil wirkt.",
                whatItMeasuresEN: "How dynamic and captivating your speaking style feels.",
                howItWorksDE: "Kluna kombiniert F0-Range, Energie-Wechsel, Timing und Artikulation zu einem Charisma-Signal.",
                howItWorksEN: "Kluna combines F0 range, energy shifts, timing, and articulation into a charisma signal.",
                biomarkers: ["F0 range", "F0 variance", "Energy phases", "Pause timing"],
                tipDE: "Vermeide Monotonie: ruhig -> stark -> Pause -> ruhig.",
                tipEN: "Avoid monotony: calm -> strong -> pause -> calm.",
                color: .klunaAccent
            ),
        ]
    }
}

struct DimensionExplanation {
    let dimension: PerformanceDimension
    let icon: String
    let whatItMeasuresDE: String
    let whatItMeasuresEN: String
    let howItWorksDE: String
    let howItWorksEN: String
    let biomarkers: [String]
    let tipDE: String
    let tipEN: String
    let color: Color

    func whatItMeasures(language: String) -> String { language == "de" ? whatItMeasuresDE : whatItMeasuresEN }
    func howItWorks(language: String) -> String { language == "de" ? howItWorksDE : howItWorksEN }
    func tip(language: String) -> String { language == "de" ? tipDE : tipEN }
}

struct DimensionExplanationCard: View {
    let explanation: DimensionExplanation
    let language: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            Button(action: onTap) {
                HStack(spacing: KlunaSpacing.sm) {
                    Image(systemName: explanation.icon)
                        .font(.system(size: 16))
                        .foregroundColor(explanation.color)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(explanation.dimension.localizedName(language: language))
                            .font(KlunaFont.heading(16))
                            .foregroundColor(.klunaPrimary)

                        Text(explanation.whatItMeasures(language: language))
                            .font(KlunaFont.body(13))
                            .foregroundColor(.klunaSecondary)
                    }

                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.klunaMuted)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: KlunaSpacing.md) {
                    VStack(alignment: .leading, spacing: KlunaSpacing.xs) {
                        Text(language == "de" ? "Wie es funktioniert" : "How it works")
                            .font(KlunaFont.caption(11))
                            .foregroundColor(.klunaMuted)
                            .textCase(.uppercase)
                        Text(explanation.howItWorks(language: language))
                            .font(KlunaFont.body(14))
                            .foregroundColor(.klunaSecondary)
                            .lineSpacing(3)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: KlunaSpacing.xs) {
                        Text(language == "de" ? "Gemessene Biomarker" : "Measured biomarkers")
                            .font(KlunaFont.caption(11))
                            .foregroundColor(.klunaMuted)
                            .textCase(.uppercase)

                        FlowLayout(spacing: 6) {
                            ForEach(explanation.biomarkers, id: \.self) { biomarker in
                                Text(biomarker)
                                    .font(KlunaFont.caption(11))
                                    .foregroundColor(explanation.color)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(explanation.color.opacity(0.1))
                                    .cornerRadius(KlunaRadius.pill)
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: KlunaSpacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.klunaAmber)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(language == "de" ? "Tipp zum Verbessern" : "Tip to improve")
                                .font(KlunaFont.caption(11))
                                .foregroundColor(.klunaMuted)
                            Text(explanation.tip(language: language))
                                .font(KlunaFont.body(13))
                                .foregroundColor(.klunaPrimary)
                                .lineSpacing(2)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(KlunaSpacing.sm)
                    .background(Color.klunaAmber.opacity(0.06))
                    .cornerRadius(KlunaRadius.button)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(isExpanded ? explanation.color.opacity(0.3) : Color.klunaBorder, lineWidth: 1)
        )
        .padding(.horizontal, KlunaSpacing.md)
    }
}

struct DimensionDetailSheet: View {
    let explanation: DimensionExplanation
    let currentScore: Double
    let bestScore: Double?
    let language: String

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.md) {
            HStack {
                VStack(alignment: .leading) {
                    Text(language == "de" ? "Aktuell" : "Current")
                        .font(KlunaFont.caption(11))
                        .foregroundColor(.klunaMuted)
                    Text("\(Int(currentScore))")
                        .font(KlunaFont.scoreDisplay(36))
                        .foregroundColor(.forScore(currentScore))
                }

                Spacer()

                if let best = bestScore {
                    VStack(alignment: .trailing) {
                        Text("Personal Best")
                            .font(KlunaFont.caption(11))
                            .foregroundColor(.klunaMuted)
                        Text("\(Int(best))")
                            .font(KlunaFont.scoreDisplay(36))
                            .foregroundColor(.klunaGold)
                    }
                }
            }
            .padding(.horizontal, KlunaSpacing.md)

            Divider().foregroundColor(.klunaBorder)

            Text(explanation.whatItMeasures(language: language))
                .font(KlunaFont.body(15))
                .foregroundColor(.klunaPrimary)
                .padding(.horizontal, KlunaSpacing.md)

            Text(explanation.howItWorks(language: language))
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaSecondary)
                .lineSpacing(3)
                .padding(.horizontal, KlunaSpacing.md)

            HStack(alignment: .top, spacing: KlunaSpacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.klunaAmber)
                Text(explanation.tip(language: language))
                    .font(KlunaFont.body(14))
                    .foregroundColor(.klunaPrimary)
                    .lineSpacing(2)
            }
            .padding(KlunaSpacing.md)
            .background(Color.klunaAmber.opacity(0.06))
            .cornerRadius(KlunaRadius.card)
            .padding(.horizontal, KlunaSpacing.md)

            Spacer()
        }
        .padding(.top, KlunaSpacing.md)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

private extension PerformanceDimension {
    func localizedName(language: String) -> String {
        switch self {
        case .confidence: return language == "de" ? "Confidence" : "Confidence"
        case .energy: return language == "de" ? "Energy" : "Energy"
        case .tempo: return language == "de" ? "Tempo" : "Tempo"
        case .clarity: return language == "de" ? "Präsenz" : "Presence"
        case .stability: return language == "de" ? "Gelassenheit" : "Calmness"
        case .charisma: return language == "de" ? "Charisma" : "Charisma"
        }
    }
}
