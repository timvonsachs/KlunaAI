import SwiftUI

struct InsightsView: View {
    let patterns: [DetectedPattern]
    let sessionCount: Int

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if patterns.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundColor(.klunaSecondary)
                        Text("Kluna lernt noch")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.klunaPrimary)
                        Text("Nach \(max(0, 15 - sessionCount)) weiteren Sessions erscheinen hier persönliche Erkenntnisse über deine Stimme.")
                            .font(.system(size: 14))
                            .foregroundColor(.klunaSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 40)
                } else {
                    ForEach(patterns, id: \.id) { pattern in
                        PatternCard(pattern: pattern)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .background(NoiseBackground())
    }
}

private struct PatternCard: View {
    let pattern: DetectedPattern
    @State private var showTip = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: categoryIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(categoryColor)
                Text(pattern.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.klunaPrimary)
                    .lineSpacing(3)
                Spacer()
            }
            HStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(categoryColor.opacity(0.5))
                            .frame(width: geo.size.width * pattern.confidence)
                    }
                }
                .frame(width: 60, height: 4)
                Text("\(Int(pattern.confidence * 100))% sicher")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.klunaMuted)
            }
            Button(action: { withAnimation(KlunaAnimation.spring) { showTip.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.klunaAmber.opacity(0.6))
                    Text(showTip ? "Tipp ausblenden" : "Tipp anzeigen")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.klunaSecondary)
                }
            }
            if showTip {
                Text(pattern.recommendation)
                    .font(.system(size: 13))
                    .foregroundColor(.klunaSecondary)
                    .lineSpacing(3)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(categoryColor.opacity(0.10), lineWidth: 1))
    }

    private var categoryIcon: String {
        switch pattern.category {
        case .warning: return "exclamationmark.triangle.fill"
        case .positive: return "chart.line.uptrend.xyaxis"
        case .insight: return "lightbulb.fill"
        }
    }
    private var categoryColor: Color {
        switch pattern.category {
        case .warning: return .stateTense
        case .positive: return .stateEnergized
        case .insight: return .stateFocused
        }
    }
}
