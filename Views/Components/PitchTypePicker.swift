import SwiftUI

struct PitchTypePicker: View {
    @Binding var selected: PitchType
    let pitchTypes: [PitchType]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KlunaSpacing.sm) {
                ForEach(pitchTypes) { pitchType in
                    PitchPill(
                        name: pitchType.name,
                        timeLimit: pitchType.timeLimit,
                        isSelected: pitchType.id == selected.id
                    )
                    .onTapGesture {
                        withAnimation(KlunaAnimation.springFast) {
                            selected = pitchType
                        }
                        SoundManager.againHaptic()
                    }
                }
            }
            .padding(.horizontal, KlunaSpacing.md)
        }
    }
}

struct PitchPill: View {
    let name: String
    let timeLimit: Int?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(name)
                .font(KlunaFont.caption(13))
                .foregroundColor(isSelected ? .white : .klunaSecondary)
                .lineLimit(1)

            if let limit = timeLimit {
                Text("\(limit)s")
                    .font(KlunaFont.caption(10))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .klunaMuted)
            }
        }
        .padding(.horizontal, KlunaSpacing.md)
        .padding(.vertical, KlunaSpacing.sm)
        .background(isSelected ? Color.klunaAccent : Color.klunaSurface)
        .cornerRadius(KlunaRadius.pill)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.pill)
                .stroke(isSelected ? Color.clear : Color.klunaBorder, lineWidth: 1)
        )
    }
}

