import SwiftUI

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var streakManager: StreakManager
    @State private var showPaywall = false
    @State private var showHowKlunaMeasures = false
    @State private var user = KlunaUser(
        name: "User",
        language: "en",
        firstSessionDate: Date(),
        totalSessions: 0,
        weeklyGoal: 3,
        currentStreak: 0,
        strengths: [],
        weaknesses: [],
        longTermProfile: nil,
        teamCode: nil,
        role: .consumer,
        voiceType: .mid,
        goal: .pitches
    )
    @State private var weeklyGoal = 3
    @State private var openAIKey = ""
    @State private var revealOpenAIKey = false

    var body: some View {
        ScrollView {
            VStack(spacing: KlunaSpacing.md) {
                Text(L10n.settings)
                    .font(KlunaFont.heading(28))
                    .foregroundColor(.klunaPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, KlunaSpacing.md)

                SettingsSection(title: L10n.profile) {
                    VStack(spacing: 0) {
                        SettingsRow(icon: "person.fill", label: L10n.name, value: user.name)
                        SettingsRow(icon: "globe", label: L10n.language, value: user.language == "de" ? "Deutsch" : "English")
                        SettingsRow(icon: "waveform", label: L10n.voiceType, value: user.voiceType.localizedName)
                        SettingsRow(icon: "target", label: L10n.goal, value: user.goal.localizedName)
                    }
                }

                SettingsSection(title: L10n.training) {
                    VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
                        Text(L10n.weeklyGoal)
                            .font(KlunaFont.body(14))
                            .foregroundColor(.klunaSecondary)
                        Picker("", selection: $weeklyGoal) {
                            Text("3").tag(3)
                            Text("5").tag(5)
                            Text("7").tag(7)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: weeklyGoal) { value in
                            streakManager.setWeeklyGoal(value)
                            persist()
                        }
                    }
                    .padding(KlunaSpacing.md)
                }

                SettingsSection(title: L10n.subscription) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(subscriptionManager.tier == .pro ? "Pro" : "Free")
                                .font(KlunaFont.heading(16))
                                .foregroundColor(subscriptionManager.tier == .pro ? .klunaAccent : .klunaMuted)
                        }
                        Spacer()
                        if subscriptionManager.tier != .pro {
                            Button(L10n.upgrade) { showPaywall = true }
                                .font(KlunaFont.caption(13))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.klunaAccent)
                                .cornerRadius(KlunaRadius.button)
                        }
                    }
                    .padding(KlunaSpacing.md)
                }

                SettingsSection(title: L10n.app) {
                    VStack(spacing: 0) {
                        Button {
                            showHowKlunaMeasures = true
                        } label: {
                            HStack {
                                Image(systemName: "waveform.badge.magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundColor(.klunaAccent)
                                    .frame(width: 28)
                                Text(user.language == "de" ? "Wie Kluna misst" : "How Kluna measures")
                                    .font(KlunaFont.body(16))
                                    .foregroundColor(.klunaPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.klunaMuted)
                            }
                            .padding(KlunaSpacing.md)
                        }
                        .buttonStyle(.plain)

                        SettingsRow(icon: "info.circle", label: L10n.version, value: "1.0.0")
                    }
                }

                SettingsSection(title: "AI Services") {
                    VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
                        Text("OpenAI API Key (Whisper)")
                            .font(KlunaFont.body(14))
                            .foregroundColor(.klunaSecondary)
                        HStack(spacing: 8) {
                            Group {
                                if revealOpenAIKey {
                                    TextField("sk-...", text: $openAIKey)
                                } else {
                                    SecureField("sk-...", text: $openAIKey)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(KlunaFont.body(13))
                            .foregroundColor(.klunaPrimary)

                            Button(revealOpenAIKey ? "Hide" : "Show") {
                                revealOpenAIKey.toggle()
                            }
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaAccent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.klunaBackground.opacity(0.6))
                        .cornerRadius(10)

                        Text("Wird lokal gespeichert und für Whisper-Transkription genutzt.")
                            .font(KlunaFont.caption(11))
                            .foregroundColor(.klunaMuted)
                    }
                    .padding(KlunaSpacing.md)
                    .onChange(of: openAIKey) { value in
                        UserDefaults.standard.set(value.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "openai_api_key")
                    }
                }

                SettingsSection(title: "Data") {
                    DataExportView()
                }

                Spacer(minLength: 100)
            }
        }
        .background(Color.klunaBackground.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showHowKlunaMeasures) {
            NavigationStack {
                HowKlunaMeasuresView(language: user.language)
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        let mm = MemoryManager(context: context)
        user = mm.loadUser()
        weeklyGoal = user.weeklyGoal
        openAIKey = UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }

    private func persist() {
        let mm = MemoryManager(context: context)
        var updated = user
        updated.weeklyGoal = weeklyGoal
        mm.saveUser(updated)
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            Text(title.uppercased())
                .font(KlunaFont.caption(11))
                .foregroundColor(.klunaMuted)
                .padding(.horizontal, KlunaSpacing.md)

            content()
                .background(Color.klunaSurface)
                .cornerRadius(KlunaRadius.card)
                .overlay(
                    RoundedRectangle(cornerRadius: KlunaRadius.card)
                        .stroke(Color.klunaBorder, lineWidth: 1)
                )
                .padding(.horizontal, KlunaSpacing.md)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.klunaAccent)
                .frame(width: 24)
            Text(label)
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaSecondary)
            Spacer()
            Text(value)
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaMuted)
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.klunaMuted)
        }
        .padding(KlunaSpacing.md)
    }
}

