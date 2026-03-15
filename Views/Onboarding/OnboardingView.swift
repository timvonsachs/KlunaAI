import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appLanguage") private var appLanguage = "en"
    @AppStorage("userName") private var userName = ""
    @Environment(\.managedObjectContext) private var context
    @State private var page = 0
    @State private var inputName = ""
    @State private var selectedLanguage = "de"
    @State private var selectedVoiceType: VoiceType = .mid
    @State private var selectedGoal: UserGoal = .pitches
    @State private var permissionsGranted = false

    var body: some View {
        TabView(selection: $page) {
            onboardingPage(
                title: "Kluna AI",
                subtitle: selectedLanguage == "de" ? "Bring deine Stimme aufs naechste Level." : "Level up your voice.",
                icon: "waveform.and.mic"
            )
            .tag(0)

            VStack(spacing: 18) {
                Text(selectedLanguage == "de" ? "So funktioniert es" : "How it works")
                    .font(.title2.bold())
                    .foregroundColor(.klunaPrimary)
                stepRow(icon: "mic.fill", text: selectedLanguage == "de" ? "Sprich deinen Pitch ein" : "Record your pitch")
                stepRow(icon: "chart.pie.fill", text: selectedLanguage == "de" ? "Erhalte deinen Score" : "Get your score")
                stepRow(icon: "chart.line.uptrend.xyaxis", text: selectedLanguage == "de" ? "Werde besser" : "Improve every day")
                Button("Weiter") { page = 2 }
                    .buttonStyle(.borderedProminent)
                    .tint(.klunaAccent)
                    .padding(.top, 12)
            }
            .padding(24)
            .tag(1)

            VStack(spacing: 14) {
                Text(selectedLanguage == "de" ? "Wie heisst du?" : "What's your name?")
                    .font(.title2.bold())
                    .foregroundColor(.klunaPrimary)
                TextField(selectedLanguage == "de" ? "Dein Name" : "Your name", text: $inputName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 24)
                Button("Weiter") {
                    userName = inputName.trimmingCharacters(in: .whitespacesAndNewlines)
                    page = 3
                }
                .buttonStyle(.borderedProminent)
                .tint(.klunaAccent)
                .disabled(inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
            .tag(2)

            VStack(spacing: 12) {
                Text(L10n.voiceTypeTitle)
                    .font(.title2.bold())
                    .foregroundColor(.klunaPrimary)
                voiceTypeButton(icon: "speaker.wave.2.fill", title: L10n.voiceTypeDeep, type: .deep)
                voiceTypeButton(icon: "speaker.wave.2", title: L10n.voiceTypeMid, type: .mid)
                voiceTypeButton(icon: "speaker.wave.3.fill", title: L10n.voiceTypeHigh, type: .high)
                Text(L10n.voiceTypeHint)
                    .font(.footnote)
                    .foregroundColor(.klunaMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                Button("Weiter") { page = 4 }
                    .buttonStyle(.borderedProminent)
                    .tint(.klunaAccent)
                    .padding(.top, 8)
            }
            .padding(24)
            .tag(3)

            VStack(spacing: 12) {
                Text(L10n.goalTitle)
                    .font(.title2.bold())
                    .foregroundColor(.klunaPrimary)
                goalButton(title: L10n.goalPitches, goal: .pitches)
                goalButton(title: L10n.goalContent, goal: .content)
                goalButton(title: L10n.goalInterviews, goal: .interviews)
                goalButton(title: L10n.goalConfidence, goal: .confidence)
                Button("Weiter") { page = 5 }
                    .buttonStyle(.borderedProminent)
                    .tint(.klunaAccent)
                    .padding(.top, 8)
            }
            .padding(24)
            .tag(4)

            VStack(spacing: 12) {
                Text(selectedLanguage == "de" ? "In welcher Sprache sprichst du?" : "What language do you speak?")
                    .font(.title2.bold())
                    .foregroundColor(.klunaPrimary)
                languageButton(flag: "🇩🇪", title: "Deutsch", code: "de")
                languageButton(flag: "🇬🇧", title: "English", code: "en")
                Button("Weiter") { page = 6 }
                    .buttonStyle(.borderedProminent)
                    .tint(.klunaAccent)
                    .padding(.top, 8)
            }
            .padding(24)
            .tag(5)

            VStack(spacing: 16) {
                Text(selectedLanguage == "de" ? "Fast geschafft" : "Almost ready")
                    .font(.title2.bold())
                    .foregroundColor(.klunaPrimary)
                Text(selectedLanguage == "de" ? "Mikrofon + Speech Zugriff erlauben." : "Allow microphone + speech access.")
                    .foregroundColor(.klunaMuted)
                Button(selectedLanguage == "de" ? "Berechtigungen erlauben" : "Allow permissions") {
                    requestPermissions()
                }
                .buttonStyle(.bordered)
                .tint(.klunaAccent)
                Button(selectedLanguage == "de" ? "Los geht's!" : "Let's go!") {
                    finalizeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.klunaAccent)
                .disabled(!permissionsGranted)
            }
            .padding(24)
            .tag(6)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .background(Color.klunaBackground.ignoresSafeArea())
        .onAppear {
            inputName = userName
            selectedLanguage = appLanguage
        }
    }

    private func onboardingPage(title: String, subtitle: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 62))
                .foregroundColor(.klunaAccent)
            Text(title).font(.largeTitle.bold()).foregroundColor(.klunaPrimary)
            Text(subtitle).foregroundColor(.klunaMuted)
            Button("Weiter") { page = 1 }
                .buttonStyle(.borderedProminent)
                .tint(.klunaAccent)
                .padding(.top, 8)
        }
        .padding(24)
    }

    private func stepRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.klunaAccent)
            Text(text).foregroundColor(.klunaPrimary)
            Spacer()
        }
        .padding(12)
        .background(Color.klunaSurface)
        .cornerRadius(12)
    }

    private func languageButton(flag: String, title: String, code: String) -> some View {
        Button {
            selectedLanguage = code
            appLanguage = code
        } label: {
            HStack {
                Text(flag)
                Text(title)
                Spacer()
            }
            .padding(14)
            .background(selectedLanguage == code ? Color.klunaAccent.opacity(0.25) : Color.klunaSurface)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func voiceTypeButton(icon: String, title: String, type: VoiceType) -> some View {
        Button {
            selectedVoiceType = type
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
                Spacer()
            }
            .padding(14)
            .background(selectedVoiceType == type ? Color.klunaAccent.opacity(0.25) : Color.klunaSurface)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func goalButton(title: String, goal: UserGoal) -> some View {
        Button {
            selectedGoal = goal
        } label: {
            HStack {
                Text(title)
                Spacer()
            }
            .padding(14)
            .background(selectedGoal == goal ? Color.klunaAccent.opacity(0.25) : Color.klunaSurface)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private func requestPermissions() {
        PermissionManager.requestAllAudioPermissions { granted in
            permissionsGranted = granted
        }
    }

    private func finalizeOnboarding() {
        let mm = MemoryManager(context: context)
        let base = mm.loadUser()
        let updated = KlunaUser(
            name: inputName.trimmingCharacters(in: .whitespacesAndNewlines),
            language: selectedLanguage,
            firstSessionDate: base.firstSessionDate,
            totalSessions: base.totalSessions,
            weeklyGoal: base.weeklyGoal,
            currentStreak: base.currentStreak,
            strengths: base.strengths,
            weaknesses: base.weaknesses,
            longTermProfile: base.longTermProfile,
            teamCode: base.teamCode,
            role: base.role,
            voiceType: selectedVoiceType,
            goal: selectedGoal
        )
        mm.saveUser(updated)
        hasCompletedOnboarding = true
    }
}
