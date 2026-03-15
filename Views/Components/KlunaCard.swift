import SwiftUI

struct KlunaCard<Content: View>: View {
    let accentColor: Color?
    let level: CardLevel
    let content: () -> Content

    enum CardLevel {
        case standard
        case elevated
        case highlighted
    }

    init(
        accent: Color? = nil,
        level: CardLevel = .standard,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.accentColor = accent
        self.level = level
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(backgroundColor)

                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.06), Color.white.opacity(0.01), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )

                    if let accent = accentColor {
                        VStack {
                            Spacer()
                            accent.opacity(0.06)
                                .frame(height: 60)
                                .blur(radius: 30)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
            )
    }

    private var backgroundColor: Color {
        switch level {
        case .standard: return KlunaColors.bgElevated
        case .elevated: return KlunaColors.bgElevated2
        case .highlighted: return KlunaColors.bgElevated3
        }
    }
}
