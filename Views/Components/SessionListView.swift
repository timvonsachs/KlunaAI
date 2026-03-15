import SwiftUI

struct SessionListView: View {
    let sessions: [SessionSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            Text(L10n.allSessions)
                .font(KlunaFont.heading(15))
                .foregroundColor(.klunaPrimary)

            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.date.shortFormat)
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                        Text(session.pitchType)
                            .font(KlunaFont.body(14))
                            .foregroundColor(.klunaSecondary)
                    }

                    Spacer()

                    Text("\(Int(session.overallScore.rounded()))")
                        .font(KlunaFont.scoreDisplay(22))
                        .foregroundColor(.forScore(session.overallScore))
                }
                .padding(.vertical, KlunaSpacing.sm)

                if index < sessions.count - 1 {
                    Divider().background(Color.klunaBorder)
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

