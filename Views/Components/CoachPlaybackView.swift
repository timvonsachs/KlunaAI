import SwiftUI

struct CoachPlaybackView: View {
    let comments: [TimestampedComment]
    let segments: [HeatmapSegment]
    let duration: TimeInterval
    @Binding var playbackProgress: Double
    let isPlaying: Bool
    let onTogglePlayback: () -> Void
    let language: String

    var activeComment: TimestampedComment? {
        guard isPlaying || playbackProgress > 0 else { return nil }
        return comments.last(where: { $0.position <= playbackProgress + 0.05 })
    }

    var body: some View {
        VStack(spacing: KlunaSpacing.md) {
            HStack {
                Image(systemName: "person.fill.checkmark")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaAccent)
                Text(language == "de" ? "Coach-Modus" : "Coach Mode")
                    .font(KlunaFont.heading(15))
                    .foregroundColor(.klunaPrimary)
                Spacer()
                Button(action: onTogglePlayback) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.klunaAccent)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { idx, segment in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.forScore(segment.scores.overall))
                                .opacity(isActiveSegment(idx) ? 1.0 : 0.4)
                        }
                    }
                    .frame(height: 32)

                    ForEach(comments) { comment in
                        Circle()
                            .fill(comment.type.color)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .offset(x: geo.size.width * comment.position - 5, y: -8)
                    }

                    if isPlaying || playbackProgress > 0 {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 48)
                            .offset(x: geo.size.width * playbackProgress, y: -8)
                            .animation(.linear(duration: 1.0 / 30.0), value: playbackProgress)
                    }
                }
            }
            .frame(height: 40)

            if let comment = activeComment {
                HStack(alignment: .top, spacing: KlunaSpacing.sm) {
                    Image(systemName: comment.type.icon)
                        .font(.system(size: 16))
                        .foregroundColor(comment.type.color)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatTime(comment.position * duration))
                            .font(KlunaFont.caption(10))
                            .foregroundColor(.klunaMuted)
                        Text(comment.text)
                            .font(KlunaFont.body(14))
                            .foregroundColor(.klunaPrimary)
                            .lineSpacing(2)
                    }
                }
                .padding(KlunaSpacing.sm)
                .background(comment.type.color.opacity(0.08))
                .cornerRadius(KlunaRadius.button)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(KlunaAnimation.spring, value: activeComment?.id)
            }

            if !isPlaying && playbackProgress == 0 {
                VStack(spacing: KlunaSpacing.xs) {
                    ForEach(comments) { comment in
                        HStack(alignment: .top, spacing: KlunaSpacing.sm) {
                            Text(formatTime(comment.position * duration))
                                .font(KlunaFont.scoreDisplay(12))
                                .foregroundColor(.klunaMuted)
                                .frame(width: 36, alignment: .trailing)
                            Image(systemName: comment.type.icon)
                                .font(.system(size: 12))
                                .foregroundColor(comment.type.color)
                            Text(comment.text)
                                .font(KlunaFont.body(13))
                                .foregroundColor(.klunaSecondary)
                                .lineSpacing(2)
                        }
                    }
                }
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(RoundedRectangle(cornerRadius: KlunaRadius.card).stroke(Color.klunaBorder, lineWidth: 1))
    }

    private func isActiveSegment(_ index: Int) -> Bool {
        guard isPlaying else { return true }
        let start = Double(index) / Double(segments.count)
        let end = Double(index + 1) / Double(segments.count)
        return playbackProgress >= start && playbackProgress < end
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let s = Int(time)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private extension TimestampedComment.CommentType {
    var icon: String {
        switch self {
        case .positive: return "checkmark.circle.fill"
        case .negative: return "exclamationmark.circle.fill"
        case .tip: return "lightbulb.fill"
        }
    }

    var color: Color {
        switch self {
        case .positive: return .klunaGreen
        case .negative: return .klunaAmber
        case .tip: return .klunaAccent
        }
    }
}
