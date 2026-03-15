import SwiftUI

struct QuadrantSelectionView: View {
    let profile: VoiceDNAProfile
    let onSelect: (String) -> Void

    private var items: [(String, Float, String)] {
        [
            ("Authority", profile.authority, "Souveraen"),
            ("Charisma", profile.charisma, "Dynamisch"),
            ("Warmth", profile.warmth, "Einladend"),
            ("Composure", profile.composure, "Gelassen"),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Wie willst du wirken?")
                    .font(KlunaFonts.headline(22))
                    .foregroundColor(KlunaColors.textPrimary)

                ForEach(items, id: \.0) { item in
                    Button {
                        onSelect(item.0)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.0)
                                    .font(KlunaFonts.label(14))
                                    .foregroundColor(KlunaColors.textPrimary)
                                Text("\(Int(item.1))/100 · \(item.2)")
                                    .font(KlunaFonts.body(12))
                                    .foregroundColor(KlunaColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(KlunaColors.textMuted)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(NoiseBackground().ignoresSafeArea())
    }
}
