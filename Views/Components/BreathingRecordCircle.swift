import SwiftUI

struct BreathingRecordCircle: View {
    let isRecording: Bool
    let audioLevel: CGFloat

    @State private var breatheScale: CGFloat = 1.0
    @State private var outerBreathScale: CGFloat = 1.0

    private let circleSize: CGFloat = 180
    private let outerSize: CGFloat = 220

    var body: some View {
        ZStack {
            Circle()
                .fill(isRecording ? Color.klunaAccent.opacity(0.08) : Color.klunaAccent.opacity(0.05))
                .frame(width: outerSize, height: outerSize)
                .scaleEffect(isRecording ? 1.0 + (audioLevel * 0.15) : outerBreathScale)
                .animation(isRecording ? .easeOut(duration: 0.1) : nil, value: audioLevel)

            Circle()
                .fill(Color.klunaAccentGlow)
                .frame(width: circleSize + 20, height: circleSize + 20)
                .scaleEffect(isRecording ? 1.0 + (audioLevel * 0.08) : breatheScale * 0.98)
                .blur(radius: 8)

            Circle()
                .fill(
                    isRecording
                        ? LinearGradient(colors: [.klunaAccent, .klunaAccentLight], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [.klunaAccent, .klunaAccentDark], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: circleSize, height: circleSize)
                .scaleEffect(isRecording ? 1.0 + (audioLevel * 0.06) : breatheScale)
                .shadow(color: .klunaAccentGlow, radius: isRecording ? 20 : 10)

            Image(systemName: isRecording ? "waveform" : "mic.fill")
                .font(.system(size: isRecording ? 36 : 40, weight: .medium))
                .foregroundColor(.white)
                .symbolEffect(.variableColor.iterative, isActive: isRecording)
        }
        .onAppear {
            withAnimation(KlunaAnimation.breathe) {
                breatheScale = 1.04
            }
            withAnimation(KlunaAnimation.breathe.delay(0.3)) {
                outerBreathScale = 1.06
            }
        }
        .accessibilityLabel(isRecording ? L10n.stopRecording : L10n.startRecording)
        .accessibilityHint(L10n.doubleTapToToggle)
    }
}

