import SwiftUI

struct ProfileBadgeView: View {
    let classification: ProfileClassification
    let overallScore: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(classification.profile.icon)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(overallScore) – \(classification.displayText)")
                        .font(.headline)
                        .foregroundColor(.white)

                    if let next = classification.profile.nextProfile {
                        Text("Nächstes Ziel: \(next.rawValue)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: classification.profile.colorHex).opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: classification.profile.colorHex).opacity(0.3), lineWidth: 1)
                    )
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(classification.profile.shortDescription)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    if let advice = classification.profile.nextStepAdvice {
                        Divider().background(Color.white.opacity(0.2))
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(advice)
                                .font(.subheadline)
                                .foregroundColor(.yellow.opacity(0.9))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
    }
}
