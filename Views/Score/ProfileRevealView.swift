import SwiftUI

struct ProfileRevealView: View {
    let profile: VoiceDNAProfile
    let onSelectQuadrant: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("🧬 Deine Voice DNA")
                .font(KlunaFonts.headline(22))
                .foregroundColor(KlunaColors.textPrimary)

            VoiceDNARadarView(profile: profile)

            Text(summary)
                .font(KlunaFonts.body(13))
                .foregroundColor(KlunaColors.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onSelectQuadrant) {
                Text("Quadrant waehlen & trainieren")
                    .font(KlunaFonts.label(13))
                    .foregroundColor(KlunaColors.textPrimary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KlunaColors.accent.opacity(0.20))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var summary: String {
        "Du wirkst besonders stark in \(profile.dominantQuadrant). Dein groesstes Wachstumspotenzial liegt in \(profile.growthQuadrant)."
    }
}
