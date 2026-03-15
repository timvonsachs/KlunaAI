import SwiftUI
import UIKit

struct JournalOnboardingView: View {
    @AppStorage("kluna_onboarding_complete") private var onboardingComplete = false
    @AppStorage("hasCompletedOnboarding") private var legacyOnboardingComplete = false

    var body: some View {
        LeanOnboardingFlow {
            onboardingComplete = true
            legacyOnboardingComplete = true
        }
    }
}

struct LeanOnboardingFlow: View {
    @StateObject private var viewModel = JournalViewModel()
    @State private var step = 0
    @State private var firstEntry: JournalEntry?
    @State private var firstCard: DailyCard?
    @State private var firstResponse: KlunaResponseViewData?
    @State private var transcript: String = ""
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            switch step {
            case 0:
                OnboardingWelcomeView {
                    withAnimation(.easeInOut(duration: 0.3)) { step = 1 }
                    KlunaAnalytics.shared.track("onboarding_start")
                }
                .transition(.opacity)
            case 1:
                OnboardingMicView {
                    withAnimation(.easeInOut(duration: 0.3)) { step = 2 }
                }
                .transition(.opacity)
            case 2:
                OnboardingRecordView(viewModel: viewModel) { entry, card, response in
                    firstEntry = entry
                    firstCard = card
                    firstResponse = response
                    transcript = entry.transcript
                    withAnimation(.easeInOut(duration: 0.3)) { step = 3 }
                }
                .transition(.opacity)
            case 3:
                if let card = firstCard, let response = firstResponse {
                    OnboardingPackOpening(
                        card: card,
                        transcript: transcript,
                        klunaResponse: response
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) { step = 4 }
                    }
                    .transition(.opacity)
                } else {
                    Color(hex: "FFF8F0").ignoresSafeArea()
                }
            case 4:
                OnboardingNameView {
                    KlunaAnalytics.shared.track("onboarding_complete")
                    onComplete()
                }
                .transition(.opacity)
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
}

struct OnboardingWelcomeView: View {
    @State private var phase = 0
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                if phase >= 0 {
                    Text("K")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "E8825C"))
                        .opacity(phase >= 0 ? 1 : 0)
                        .scaleEffect(phase >= 0 ? 1 : 0.5)
                }

                Spacer().frame(height: 20)

                if phase >= 1 {
                    VStack(spacing: 8) {
                        Text("Kluna")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "3D3229"))

                        Text(isGerman ? "Das Tagebuch das zuhört." : "The journal that listens.")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundColor(Color(hex: "3D3229").opacity(0.3))
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                if phase >= 2 {
                    Button(action: onContinue) {
                        Text(isGerman ? "Loslegen" : "Get started")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "E8825C"))
                                    .shadow(color: Color(hex: "E8825C").opacity(0.25), radius: 16, x: 0, y: 8)
                            )
                    }
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { phase = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeOut(duration: 0.5)) { phase = 1 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.4)) { phase = 2 }
            }
        }
    }

    private var isGerman: Bool {
        (Locale.current.language.languageCode?.identifier ?? "de") == "de"
    }
}

struct OnboardingMicView: View {
    @State private var appeared = false
    @State private var denied = false
    let onGranted: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                Color(hex: "E8825C").opacity(0.06 - Double(i) * 0.015),
                                lineWidth: 1.5
                            )
                            .frame(
                                width: CGFloat(60 + i * 32),
                                height: CGFloat(60 + i * 32)
                            )
                            .scaleEffect(appeared ? 1.0 + CGFloat(i) * 0.05 : 0.8)
                            .animation(
                                .easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.2),
                                value: appeared
                            )
                    }

                    ZStack {
                        Circle()
                            .fill(Color(hex: "E8825C").opacity(0.06))
                            .frame(width: 60, height: 60)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "E8825C").opacity(0.6))
                    }
                }
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.7)

                Spacer().frame(height: 40)

                Text(isGerman ? "Darf Kluna dir\nzuhören?" : "Can Kluna\nlisten to you?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "3D3229"))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 12)

                Text(isGerman ? "Alles bleibt auf deinem Gerät." : "Everything stays on your device.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(Color(hex: "3D3229").opacity(0.2))
                    .opacity(appeared ? 1 : 0)

                if denied {
                    Button(isGerman ? "Einstellungen öffnen" : "Open settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "3D3229").opacity(0.3))
                    .padding(.top, 12)
                }

                Spacer()

                Button(action: requestPermissions) {
                    Text(isGerman ? "Erlauben" : "Allow")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "E8825C"))
                        )
                }
                .padding(.horizontal, 40)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { appeared = true }
        }
    }

    private func requestPermissions() {
        PermissionManager.requestMicrophonePermission { micGranted in
            if micGranted {
                KlunaAnalytics.shared.track("onboarding_mic_granted")
                PermissionManager.requestSpeechRecognitionPermission { granted in
                    KlunaAnalytics.shared.track(granted ? "onboarding_speech_granted" : "onboarding_speech_denied")
                    onGranted()
                }
            } else {
                KlunaAnalytics.shared.track("onboarding_mic_denied")
                denied = true
            }
        }
    }

    private var isGerman: Bool {
        (Locale.current.language.languageCode?.identifier ?? "de") == "de"
    }
}

struct OnboardingRecordView: View {
    let viewModel: JournalViewModel
    let onRecordingComplete: (JournalEntry, DailyCard, KlunaResponseViewData) -> Void

    @State private var appeared = false
    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var didComplete = false

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                if !isRecording && !isProcessing {
                    VStack(spacing: 16) {
                        Text(isGerman ? "Erzähl Kluna\nwie es dir geht." : "Tell Kluna\nhow you're doing.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "3D3229"))
                            .multilineTextAlignment(.center)
                            .opacity(appeared ? 1 : 0)

                        Text(isGerman ? "20 Sekunden. Einfach drauflos." : "20 seconds. Just speak freely.")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(Color(hex: "3D3229").opacity(0.2))
                            .opacity(appeared ? 1 : 0)
                    }
                } else if isRecording {
                    VStack(spacing: 20) {
                        Text(isGerman ? "Kluna hört zu..." : "Kluna is listening...")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "E8825C").opacity(0.4))
                        RecordingTransformView(
                            phase: .line,
                            audioLevel: CGFloat(viewModel.audioLevel),
                            elapsedSeconds: Int(viewModel.elapsedTime),
                            isPremium: true
                        ) {
                            stopRecording()
                        }
                        .frame(height: 140)
                    }
                } else if isProcessing {
                    VStack(spacing: 16) {
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(Color(hex: "E8825C").opacity(0.4))
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(isProcessing ? 1.3 : 0.8)
                                    .animation(
                                        .easeInOut(duration: 0.5)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(i) * 0.15),
                                        value: isProcessing
                                    )
                            }
                        }
                        Text(isGerman ? "Kluna hört genau hin..." : "Kluna is listening closely...")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "3D3229").opacity(0.25))
                    }
                }

                Spacer()

                if !isRecording && !isProcessing {
                    Button(action: startRecording) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "E8825C"))
                                .frame(width: 80, height: 80)
                                .shadow(color: Color(hex: "E8825C").opacity(0.25), radius: 20, x: 0, y: 10)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Color.white.opacity(0.25), .clear],
                                        center: .init(x: 0.35, y: 0.35),
                                        startRadius: 0,
                                        endRadius: 28
                                    )
                                )
                                .frame(width: 80, height: 80)
                            Image(systemName: "mic.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.7)
                } else if isRecording {
                    Button(action: stopRecording) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "E85C5C"))
                                .frame(width: 80, height: 80)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                        }
                    }
                }

                Spacer().frame(height: 80)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) { appeared = true }
            KlunaAnalytics.shared.track("onboarding_first_recording")
            viewModel.latestSavedEntry = nil
        }
        .onChange(of: viewModel.elapsedTime) { _, elapsed in
            if isRecording && elapsed >= 20 {
                stopRecording()
            }
        }
        .onChange(of: viewModel.latestSavedEntry?.id) { _, _ in
            guard isProcessing, !didComplete, let entry = viewModel.latestSavedEntry else { return }
            didComplete = true
            isProcessing = false
            let card = DailyCardGenerator.generate(
                entry: entry,
                dims: VoiceDimensions.from(entry),
                baseline: nil,
                zScores: [:],
                mood: entry.moodLabel ?? entry.mood ?? "ruhig",
                coachText: entry.coachText
            )
            let response = viewModel.latestKlunaResponse ?? KlunaResponseViewData(
                mood: entry.mood,
                label: entry.moodLabel,
                text: entry.coachText ?? "",
                themes: entry.themes,
                question: nil,
                voiceObservation: nil
            )
            onRecordingComplete(entry, card, response)
        }
    }

    private func startRecording() {
        didComplete = false
        isRecording = true
        isProcessing = false
        viewModel.startRecording()
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        isProcessing = true
        viewModel.stopRecording()
    }

    private var isGerman: Bool {
        (Locale.current.language.languageCode?.identifier ?? "de") == "de"
    }
}

struct OnboardingPackOpening: View {
    let card: DailyCard
    let transcript: String
    let klunaResponse: KlunaResponseViewData
    let onContinue: () -> Void

    @State private var showTranscript = false
    @State private var showCard = false
    @State private var cardFlipped = false
    @State private var showResponse = false
    @State private var showButton = false
    @State private var glowPulse: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    if showTranscript {
                        VStack(spacing: 8) {
                            Text(isGerman ? "Du sagst:" : "You say:")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "3D3229").opacity(0.2))

                            Text("„\(transcript)“")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(Color(hex: "3D3229").opacity(0.35))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 32)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if showCard {
                        VStack(spacing: 12) {
                            Text(isGerman ? "Deine Stimme sagt:" : "Your voice says:")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(card.primaryColor.opacity(0.4))

                            ZStack {
                                if !cardFlipped {
                                    CardBackCover(glowColor: card.rarity.color, glowPulse: glowPulse)
                                        .frame(width: 300, height: 420)
                                        .onTapGesture { revealCard() }

                                    VStack {
                                        Spacer()
                                        Text(isGerman ? "Tippe zum Enthüllen" : "Tap to reveal")
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(.white.opacity(0.3))
                                            .padding(.bottom, 40)
                                    }
                                    .frame(width: 300, height: 420)
                                    .allowsHitTesting(false)
                                } else {
                                    DailyCardView(card: card)
                                        .frame(width: 300, height: 420)
                                }
                            }

                            if cardFlipped {
                                RarityRevealBadge(rarity: card.rarity)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }

                    if showResponse {
                        Text(klunaResponse.text)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "E8825C").opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                            .padding(.horizontal, 28)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if showButton {
                        Button(action: onContinue) {
                            Text(isGerman ? "Das will ich öfter" : "I want more of this")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(hex: "E8825C"))
                                        .shadow(color: Color(hex: "E8825C").opacity(0.2), radius: 12, x: 0, y: 6)
                                )
                        }
                        .padding(.horizontal, 40)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer().frame(height: 60)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.5)) { showTranscript = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showCard = true }
            }
            KlunaAnalytics.shared.track("onboarding_wow_seen")
        }
    }

    private func revealCard() {
        guard !cardFlipped else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { cardFlipped = true }
        if card.rarity == .legendary {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) { showResponse = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.4)) { showButton = true }
        }
    }

    private var isGerman: Bool {
        (Locale.current.language.languageCode?.identifier ?? "de") == "de"
    }
}

struct OnboardingNameView: View {
    @State private var name = ""
    @FocusState private var focused: Bool
    @State private var appeared = false
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text(isGerman ? "Wie heißt du?" : "What's your name?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "3D3229"))
                    .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 32)

                TextField("", text: $name)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "3D3229"))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
                    .background(
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color(hex: "E8825C").opacity(0.2))
                                .frame(height: 2)
                        }
                    )
                    .padding(.horizontal, 60)
                    .focused($focused)
                    .opacity(appeared ? 1 : 0)

                Spacer()

                Button(action: completeWithName) {
                    Text(isGerman ? "Los geht's" : "Let's go")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(!name.trimmingCharacters(in: .whitespaces).isEmpty
                                      ? Color(hex: "E8825C")
                                      : Color(hex: "E8825C").opacity(0.3))
                        )
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 40)
                .opacity(appeared ? 1 : 0)

                Button(action: skip) {
                    Text(isGerman ? "Überspringen" : "Skip")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color(hex: "3D3229").opacity(0.12))
                }
                .padding(.top, 12)

                Spacer().frame(height: 60)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { focused = true }
        }
        .onTapGesture { focused = false }
    }

    private func completeWithName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: "kluna_user_name")
        UserDefaults.standard.set(trimmed, forKey: "kluna_profile_name")
        UserDefaults.standard.set(trimmed, forKey: "userName")
        UserDefaults.standard.set(true, forKey: "kluna_onboarding_complete")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }

    private func skip() {
        UserDefaults.standard.set(true, forKey: "kluna_onboarding_complete")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }

    private var isGerman: Bool {
        (Locale.current.language.languageCode?.identifier ?? "de") == "de"
    }
}
