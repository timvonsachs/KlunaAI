import SwiftUI

struct QuickFeedbackCard: View {
    let feedback: String?

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            HStack(spacing: KlunaSpacing.sm) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaAccent)
                Text(L10n.yourCoachSays)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaAccent)
            }

            if let feedback, !feedback.isEmpty {
                Text(feedback)
                    .font(KlunaFont.body(15))
                    .foregroundColor(.klunaPrimary)
                    .lineSpacing(4)
                    .transition(.opacity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonLine(width: 0.95)
                    SkeletonLine(width: 0.8)
                    SkeletonLine(width: 0.6)
                }
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }
}

struct SkeletonLine: View {
    let width: CGFloat
    @State private var shimmer = false

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.klunaSurfaceLight)
                .frame(width: geo.size.width * width, height: 14)
                .opacity(shimmer ? 0.4 : 0.7)
        }
        .frame(height: 14)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

