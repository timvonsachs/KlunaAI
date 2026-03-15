import SwiftUI
import UIKit

struct RecordingView: View {
    @StateObject private var viewModel = SessionViewModel()
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var spinnerRotation = 0.0
    @State private var showWarmup = false
    @State private var userLanguage = "de"
    @State private var showPaywall = false
    @State private var paywallTrigger: PaywallTrigger = .general
    @AppStorage("lastWarmupDate") private var lastWarmupDate = ""

    var body: some View {
        ZStack {
            Color.klunaBackground.ignoresSafeArea()

            VStack(spacing: KlunaSpacing.lg) {
                PitchTypePicker(selected: $viewModel.selectedPitchType, pitchTypes: viewModel.pitchTypes)

                Spacer()

                RecordingTimer(duration: viewModel.recordingDuration, timeLimit: viewModel.selectedPitchType.timeLimit)

                if let prompt = viewModel.selectedPitchType.challengePrompt {
                    VStack(spacing: KlunaSpacing.sm) {
                        Text(L10n.yourChallenge)
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaAccent)
                        Text(prompt)
                            .font(KlunaFont.heading(16))
                            .foregroundColor(.klunaPrimary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, KlunaSpacing.lg)
                    }
                    .padding(.vertical, KlunaSpacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if viewModel.isProcessing {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.klunaAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(Angle(degrees: spinnerRotation))
                            .onAppear {
                                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                    spinnerRotation = 360
                                }
                            }

                        Text(L10n.analyzing)
                            .font(KlunaFont.caption(14))
                            .foregroundColor(.klunaMuted)
                            .offset(y: 60)
                    }
                    .frame(width: 220, height: 220)
                } else {
                    BreathingRecordCircle(
                        isRecording: viewModel.isRecording,
                        audioLevel: CGFloat(viewModel.audioLevel)
                    )
                    .onTapGesture {
                        guard subscriptionManager.canStartSession else {
                            paywallTrigger = .sessionLimit
                            showPaywall = true
                            return
                        }
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    }
                }

                Text(viewModel.isRecording ? L10n.listening : L10n.tapToRecord)
                    .font(KlunaFont.body(16))
                    .foregroundColor(.klunaMuted)

                if lastWarmupDate != todayKey(), !viewModel.isRecording, !viewModel.isProcessing {
                    Button(action: { showWarmup = true }) {
                        HStack(spacing: KlunaSpacing.sm) {
                            Image(systemName: "waveform.path")
                                .font(.system(size: 14))
                            Text(L10n.warmUpFirst)
                                .font(KlunaFont.caption(13))
                        }
                        .foregroundColor(.klunaAccent)
                        .padding(.horizontal, KlunaSpacing.md)
                        .padding(.vertical, KlunaSpacing.sm)
                        .background(Color.klunaAccent.opacity(0.1))
                        .cornerRadius(KlunaRadius.pill)
                    }
                }

                if !viewModel.liveTranscription.isEmpty {
                    Text(viewModel.liveTranscription)
                        .font(KlunaFont.body(14))
                        .foregroundColor(.klunaSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(KlunaSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(Color.klunaSurface)
                        .cornerRadius(KlunaRadius.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: KlunaRadius.card)
                                .stroke(Color.klunaBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, KlunaSpacing.md)
                }

                if !subscriptionManager.isProUser {
                    HStack(spacing: 6) {
                        ForEach(0..<subscriptionManager.freeSessionLimit, id: \.self) { i in
                            Circle()
                                .fill(i < subscriptionManager.sessionsThisWeek ? Color.klunaAccent : Color.klunaSurface)
                                .frame(width: 8, height: 8)
                        }
                        Text("\(subscriptionManager.freeSessionsRemaining) \(L10n.sessionsThisWeekRemaining)")
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                    }
                    .padding(.vertical, KlunaSpacing.xs)
                } else {
                    Text("\(subscriptionManager.sessionsThisWeek)/\(memoryWeeklyGoal()) \(L10n.sessionsThisWeek)")
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                }

                Spacer()
            }
            .padding(.vertical, KlunaSpacing.md)
        }
        .fullScreenCover(isPresented: $viewModel.showScoreScreen) {
            ScoreRevealContainerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: paywallTrigger, language: userLanguage, subscriptionManager: subscriptionManager)
        }
        .sheet(isPresented: $showWarmup) {
            VocalWarmupView(
                onComplete: {
                    showWarmup = false
                    lastWarmupDate = todayKey()
                },
                onSkip: { showWarmup = false },
                language: userLanguage
            )
        }
        .onAppear {
            userLanguage = MemoryManager(context: PersistenceController.shared.container.viewContext).loadUser().language
            applyPendingChallengeIfNeeded()
            applyPendingProgressiveChallengeIfNeeded()
        }
        .alert(L10n.hint, isPresented: $viewModel.showErrorAlert) {
            if viewModel.errorMessage.contains("Einstellungen"),
               let url = URL(string: UIApplication.openSettingsURLString) {
                Button(L10n.openSettings) {
                    UIApplication.shared.open(url)
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private func memoryWeeklyGoal() -> Int {
        let mm = MemoryManager(context: PersistenceController.shared.container.viewContext)
        return mm.loadUser().weeklyGoal
    }

    private func applyPendingChallengeIfNeeded() {
        let defaults = UserDefaults.standard
        guard let prompt = defaults.string(forKey: "pending_daily_challenge_prompt"), !prompt.isEmpty else { return }
        let timeLimit = defaults.integer(forKey: "pending_daily_challenge_time_limit")
        viewModel.selectedPitchType = PitchType(
            id: UUID(),
            name: L10n.dailyChallenge,
            description: "Daily challenge",
            timeLimit: timeLimit > 0 ? timeLimit : nil,
            challengePrompt: prompt,
            isCustom: true,
            isDefault: false
        )
        defaults.removeObject(forKey: "pending_daily_challenge_prompt")
        defaults.removeObject(forKey: "pending_daily_challenge_time_limit")
        defaults.removeObject(forKey: "pending_daily_challenge_id")
    }

    private func applyPendingProgressiveChallengeIfNeeded() {
        let defaults = UserDefaults.standard
        guard let challengeId = defaults.string(forKey: "pending_progressive_challenge_id"),
              let prompt = defaults.string(forKey: "pending_progressive_challenge_prompt"),
              !prompt.isEmpty
        else { return }

        let provider = ProgressiveChallengeProvider.shared
        let challenge = provider.levels.first(where: { $0.id == challengeId }) ?? provider.currentChallenge()
        let name = defaults.string(forKey: "pending_progressive_challenge_name") ?? challenge.title(language: userLanguage)
        let timeLimit = defaults.integer(forKey: "pending_progressive_challenge_time_limit")

        viewModel.selectedPitchType = PitchType(
            id: UUID(),
            name: name,
            description: "Progressive challenge",
            timeLimit: timeLimit > 0 ? timeLimit : challenge.timeLimit,
            challengePrompt: prompt,
            isCustom: true,
            isDefault: false
        )
        viewModel.activeProgressiveChallenge = challenge

        defaults.removeObject(forKey: "pending_progressive_challenge_id")
        defaults.removeObject(forKey: "pending_progressive_challenge_name")
        defaults.removeObject(forKey: "pending_progressive_challenge_prompt")
        defaults.removeObject(forKey: "pending_progressive_challenge_time_limit")
    }

    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

struct RecordingTimer: View {
    let duration: TimeInterval
    let timeLimit: Int?

    var body: some View {
        let displayTime = timeLimit != nil ? max(0, TimeInterval(timeLimit ?? 0) - duration) : duration
        let isUrgent = timeLimit != nil && displayTime < 10
        Text(formatTime(displayTime))
            .font(KlunaFont.scoreLight(48))
            .foregroundColor(isUrgent ? .klunaRed : .klunaSecondary)
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VocalWarmupView: View {
    @State private var currentStep = 0
    @State private var isActive = false
    @State private var secondsRemaining = 0
    @State private var timer: Timer?

    let onComplete: () -> Void
    let onSkip: () -> Void
    let language: String

    private let warmupSteps: [WarmupStep] = [
        WarmupStep(
            titleDe: "Tief atmen",
            titleEn: "Deep Breathing",
            instructionDe: "Atme 4 Sekunden ein, halte 4 Sekunden, atme 4 Sekunden aus.",
            instructionEn: "Breathe in for 4 seconds, hold for 4 seconds, breathe out for 4 seconds.",
            duration: 12
        ),
        WarmupStep(
            titleDe: "Summen",
            titleEn: "Humming",
            instructionDe: "Summe auf Mmmm. Lass den Ton lauter und leiser werden.",
            instructionEn: "Hum on Mmmm. Let the tone grow louder and softer.",
            duration: 10
        ),
        WarmupStep(
            titleDe: "Vokale oeffnen",
            titleEn: "Open Vowels",
            instructionDe: "Sprich langsam: AAAA, EEEE, IIII, OOOO, UUUU.",
            instructionEn: "Speak slowly: AAAA, EEEE, IIII, OOOO, UUUU.",
            duration: 10
        )
    ]

    var body: some View {
        VStack(spacing: KlunaSpacing.lg) {
            HStack {
                VStack(alignment: .leading) {
                    Text(L10n.vocalWarmup)
                        .font(KlunaFont.heading(22))
                        .foregroundColor(.klunaPrimary)
                    Text(L10n.warmupSubtitle)
                        .font(KlunaFont.caption(13))
                        .foregroundColor(.klunaMuted)
                }
                Spacer()
                Button(L10n.skip, action: onSkip)
                    .font(KlunaFont.caption(14))
                    .foregroundColor(.klunaMuted)
            }

            Spacer()

            VStack(spacing: KlunaSpacing.md) {
                HStack(spacing: KlunaSpacing.sm) {
                    ForEach(0..<warmupSteps.count, id: \.self) { i in
                        Circle()
                            .fill(i <= currentStep ? Color.klunaAccent : Color.klunaSurfaceLight)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(warmupSteps[currentStep].title(language: language))
                    .font(KlunaFont.heading(20))
                    .foregroundColor(.klunaPrimary)
                    .multilineTextAlignment(.center)

                Text(warmupSteps[currentStep].instruction(language: language))
                    .font(KlunaFont.body(16))
                    .foregroundColor(.klunaSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, KlunaSpacing.lg)

                if isActive {
                    ZStack {
                        Circle()
                            .stroke(Color.klunaSurfaceLight, lineWidth: 6)
                            .frame(width: 100, height: 100)
                        Circle()
                            .trim(from: 0, to: CGFloat(secondsRemaining) / CGFloat(warmupSteps[currentStep].duration))
                            .stroke(Color.klunaAccent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: secondsRemaining)
                        Text("\(secondsRemaining)")
                            .font(KlunaFont.scoreDisplay(36))
                            .foregroundColor(.klunaPrimary)
                            .contentTransition(.numericText())
                    }
                }
            }

            Spacer()

            if !isActive {
                Button(action: startCurrentStep) {
                    Text(currentStep == 0 ? L10n.startWarmup : L10n.next)
                        .font(KlunaFont.heading(17))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KlunaSpacing.md)
                        .background(Color.klunaAccent)
                        .cornerRadius(KlunaRadius.button)
                }
            }
        }
        .padding(KlunaSpacing.lg)
        .background(Color.klunaBackground.ignoresSafeArea())
    }

    private func startCurrentStep() {
        isActive = true
        secondsRemaining = warmupSteps[currentStep].duration
        SoundManager.againHaptic()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                timer?.invalidate()
                isActive = false
                SoundManager.scoreHaptic()
                if currentStep < warmupSteps.count - 1 {
                    withAnimation(KlunaAnimation.spring) {
                        currentStep += 1
                    }
                } else {
                    onComplete()
                }
            }
        }
    }
}

struct WarmupStep {
    let titleDe: String
    let titleEn: String
    let instructionDe: String
    let instructionEn: String
    let duration: Int

    func title(language: String) -> String { language == "de" ? titleDe : titleEn }
    func instruction(language: String) -> String { language == "de" ? instructionDe : instructionEn }
}
