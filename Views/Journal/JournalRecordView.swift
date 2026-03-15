import SwiftUI

struct JournalRecordView: View {
    @ObservedObject var viewModel: JournalViewModel
    @ObservedObject private var promptManager = PromptManager.shared
    let language: String
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            KlunaWarm.background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()

                Text(promptManager.currentPrompt)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                OrganicAudioVisualizer(level: CGFloat(viewModel.audioLevel))
                    .frame(height: 210)

                Text(timeString)
                    .font(.system(size: 56, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
                    .monospacedDigit()

                if let error = viewModel.recordingError {
                    VStack(spacing: 10) {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        Button("Erneut versuchen") {
                            if !viewModel.isRecording && !viewModel.isProcessing {
                                viewModel.startRecording()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(KlunaWarm.warmAccent)
                    }
                }

                Spacer()

                Button {
                    viewModel.stopRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(KlunaWarm.warmAccent)
                            .frame(width: 74, height: 74)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .disabled(!viewModel.isRecording || viewModel.isProcessing)

                Text(viewModel.isProcessing ? "Kluna hört nach..." : "Tippe zum Beenden")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlunaWarm.secondary)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            if !viewModel.isRecording && !viewModel.isProcessing {
                viewModel.startRecording()
            }
        }
        .onChange(of: viewModel.latestSavedEntry?.id) { _, newValue in
            if newValue != nil { onComplete() }
        }
        .onChange(of: viewModel.elapsedTime) { _, newValue in
            if viewModel.isRecording, newValue >= 20 {
                viewModel.stopRecording()
            }
        }
    }

    private var timeString: String {
        let remaining = max(0, 20 - Int(viewModel.elapsedTime))
        return "0:\(String(format: "%02d", remaining))"
    }
}

struct OrganicAudioVisualizer: View {
    let level: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { ring in
                Circle()
                    .stroke(KlunaWarm.warmAccent.opacity(0.15 - (Double(ring) * 0.03)), lineWidth: 2)
                    .scaleEffect(0.8 + level * CGFloat(ring + 1) * 0.25)
                    .animation(.easeInOut(duration: 0.3), value: level)
            }
            Circle()
                .fill(KlunaWarm.warmAccent.opacity(0.16 + level * 0.12))
                .scaleEffect(0.3 + level * 0.45)
                .animation(.easeInOut(duration: 0.22), value: level)
        }
        .padding(26)
    }
}
