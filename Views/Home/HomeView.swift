import SwiftUI
import CoreData
import AVFoundation

enum HomeRecordingState {
    case idle
    case recording
    case analyzing
    case result
}

enum TransitionPhase {
    case point
    case expandingRing
    case spinningRing
    case brakingRing
    case morphingToLine
    case line
}

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var dataManager = KlunaDataManager.shared
    @ObservedObject private var conversationManager = ConversationManager.shared
    @StateObject private var journalViewModel = JournalViewModel()
    @StateObject private var promptManager = PromptManager.shared
    @StateObject private var questionGen = QuestionGenerator.shared
    @State private var recordingState: HomeRecordingState = .idle
    @State private var resultEntry: JournalEntry?
    @State private var streak: Int = 0
    @State private var longestStreak: Int = 0
    @State private var promptOpacity: CGFloat = 0
    @State private var greetingOffset: CGFloat = 15
    @State private var transitionPhase: TransitionPhase = .point
    @State private var transitionTask: Task<Void, Never>?
    @State private var moodExpanded = false
    @State private var communityActiveToday: Int = 0
    @AppStorage("kluna_seen_refresh_hint") private var hasSeenRefreshHint = false
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack {
                    adaptiveBackground()
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer().frame(height: 16)

                            if recordingState == .recording {
                                recordingContent(geo: geo)
                            } else if recordingState == .analyzing {
                                analyzingContent(geo: geo)
                            } else if recordingState == .result, let entry = resultEntry {
                                resultContent(entry: entry, geo: geo)
                            } else if conversationManager.isInConversation {
                                conversationContent()
                            } else {
                                idleContent(geo: geo)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height, alignment: .center)
                    }

                    if moodExpanded {
                        Color.black
                            .opacity(0.08)
                            .ignoresSafeArea()
                            .transition(.opacity)
                            .allowsHitTesting(false)
                            .zIndex(1)
                    }
                }
                .refreshable {
                    if !conversationManager.isInConversation {
                        await questionGen.generateNewQuestion()
                    }
                    await refreshHomeData()
                }
            }
        }
        .onAppear {
            dataManager.refresh(limit: 40)
            streak = calculateStreak()
            longestStreak = calculateLongestStreak()
            animateHomeAppearance()
            questionGen.loadSavedQuestion()
            if questionGen.currentQuestion.isEmpty {
                Task { await questionGen.generateNewQuestion() }
            }
            Task {
                if let stats = await SupabaseManager.shared.fetchLiveCommunity() {
                    await MainActor.run {
                        communityActiveToday = max(0, stats.active_today ?? 0)
                    }
                }
            }
        }
        .onChange(of: journalViewModel.latestSavedEntry?.id) { _, _ in
            guard let entry = journalViewModel.latestSavedEntry else { return }
            streak = calculateStreak()
            longestStreak = calculateLongestStreak()
            print("📦 HOME DEBUG: latestSavedEntry received \(entry.id.uuidString.prefix(8))")
            resultEntry = entry
            withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                recordingState = .result
            }
            print("📦 HOME DEBUG: resultEntry set + recordingState -> result")
        }
        .onChange(of: journalViewModel.isProcessing) { _, processing in
            if processing {
                withAnimation(.easeOut(duration: 0.25)) {
                    recordingState = .analyzing
                }
            }
        }
        .onChange(of: journalViewModel.elapsedTime) { _, elapsed in
            if recordingState == .recording, !subscriptionManager.isProUser, elapsed >= 20 {
                stopInlineRecording()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            guard conversationManager.isInConversation else { return }

            if recordingState == .recording {
                stopInlineRecording()
            }

            conversationManager.autoEndConversationIfNeeded(reason: "scene_\(String(describing: phase))")
        }
    }

    @ViewBuilder
    private func adaptiveBackground() -> some View {
        ZStack {
            KlunaWarm.background
                .ignoresSafeArea()
            if let entry = todayEntry {
                RadialGradient(
                    gradient: Gradient(colors: [
                        entry.stimmungsfarbe.opacity(0.06),
                        entry.stimmungsfarbe.opacity(0.02),
                        .clear,
                    ]),
                    center: .topTrailing,
                    startRadius: 50,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .animation(.easeOut(duration: 1.0), value: entry.id)

                RadialGradient(
                    gradient: Gradient(colors: [
                        entry.stimmungsfarbe.opacity(0.03),
                        .clear,
                    ]),
                    center: .bottomLeading,
                    startRadius: 30,
                    endRadius: 200
                )
                .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func idleContent(geo: GeometryProxy) -> some View {
        headerSection()
            .padding(.horizontal, 28)
            .offset(y: greetingOffset)
            .transition(.opacity.combined(with: .move(edge: .top)))

        Spacer().frame(height: max(24, geo.size.height * 0.04))

        promptSection()
            .padding(.horizontal, 28)
            .opacity(promptOpacity)

        Spacer()

        GlowingRecordPoint(recordingState: $recordingState) {
            startInlineRecording()
        }
        .transition(.scale.combined(with: .opacity))

        Spacer().frame(height: max(28, geo.size.height * 0.1))
    }

    @ViewBuilder
    private func recordingContent(geo: GeometryProxy) -> some View {
        Spacer().frame(height: max(24, geo.size.height * 0.08))
        RecordingTransformView(
            phase: transitionPhase,
            audioLevel: CGFloat(journalViewModel.audioLevel),
            elapsedSeconds: Int(journalViewModel.elapsedTime),
            isPremium: subscriptionManager.isProUser,
            stopAction: stopInlineRecording
        )
        Spacer().frame(height: max(18, geo.size.height * 0.08))
    }

    @ViewBuilder
    private func analyzingContent(geo: GeometryProxy) -> some View {
        Spacer().frame(height: max(24, geo.size.height * 0.08))
        AnalyzingRing()
        Spacer().frame(height: max(18, geo.size.height * 0.08))
    }

    @ViewBuilder
    private func conversationContent() -> some View {
        ConversationFlowView(
            isRecording: recordingState == .recording,
            rounds: conversationManager.activeConversation?.rounds ?? [],
            currentRound: conversationManager.currentRound,
            onRecordTap: {
                if recordingState == .recording {
                    stopInlineRecording()
                } else if recordingState == .idle {
                    startInlineRecording()
                }
            },
            onFinishTap: {
                conversationManager.endConversation()
                withAnimation(.easeOut(duration: 0.25)) {
                    recordingState = .idle
                }
            }
        )
        .padding(.top, 28)
    }

    @ViewBuilder
    private func resultContent(entry: JournalEntry, geo: GeometryProxy) -> some View {
        let _ = print("📦 resultContent CALLED with entry: \(entry.id.uuidString.prefix(8))")
        let card = cardForEntry(entry) ?? fallbackCard(for: entry)
        let _ = print("📦 Card generated: \(card.title), rarity: \(card.rarity)")
        let prev = previousCardForEntry(entry)
        let response = klunaResponseForEntry(entry)
        PackOpeningView(
            transcript: entry.transcript,
            entry: entry,
            card: card,
            previousCard: prev,
            klunaResponse: response,
            onRespond: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    self.resultEntry = nil
                    self.recordingState = .idle
                }
                startInlineRecording()
            },
            onDone: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    recordingState = .idle
                    self.resultEntry = nil
                }
                if conversationManager.isInConversation {
                    conversationManager.endConversation()
                }
            }
        )
        .frame(minHeight: geo.size.height * 0.82)
        .padding(.horizontal, 16)
    }

    private func cardForEntry(_ entry: JournalEntry) -> DailyCard? {
        dataManager.allDailyCards().first { card in
            Calendar.current.isDate(card.date, inSameDayAs: entry.date)
        }
    }

    private func previousCardForEntry(_ entry: JournalEntry) -> DailyCard? {
        let cards = dataManager.allDailyCards().sorted(by: { $0.date > $1.date })
        guard let idx = cards.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: entry.date) }),
              cards.indices.contains(idx + 1) else {
            return nil
        }
        return cards[idx + 1]
    }

    private func klunaResponseForEntry(_ entry: JournalEntry) -> KlunaResponseViewData {
        if let live = journalViewModel.latestKlunaResponse {
            return live
        }
        return KlunaResponseViewData(
            mood: entry.mood,
            label: entry.moodLabel,
            text: entry.coachText ?? "",
            themes: entry.themes,
            question: PromptManager.shared.currentPrompt,
            voiceObservation: entry.voiceObservation
        )
    }

    private func fallbackCard(for entry: JournalEntry) -> DailyCard {
        let dims = VoiceDimensions.from(entry)
        return DailyCardGenerator.generate(
            entry: entry,
            dims: dims,
            baseline: nil,
            zScores: [:],
            mood: entry.moodLabel ?? entry.mood ?? "ruhig",
            coachText: entry.coachText
        )
    }

    @ViewBuilder
    private func headerSection() -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(timeGreeting())
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(KlunaWarm.warmBrown)
            }

            Spacer()

            if streak > 0 {
                StreakBadgeView(currentStreak: streak, longestStreak: longestStreak) {
                    ShareABManager.shared.trackTap(.streak)
                    let color: Color = streak >= 14 ? Color(hex: "E85C5C") : (streak >= 7 ? Color(hex: "F5B731") : KlunaWarm.warmAccent)
                    ShareImageGenerator.share(
                        content: .streak(
                            StreakShareData(days: streak, color: color)
                        )
                    )
                }
                    .onAppear {
                        ShareABManager.shared.trackShown(.streak)
                    }
            }
        }
    }

    @ViewBuilder
    private func todayMoodCircle() -> some View {
        VStack(spacing: 12) {
            if let entry = todayEntry {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    entry.stimmungsfarbe.opacity(0.2),
                                    entry.stimmungsfarbe.opacity(0.05),
                                    .clear,
                                ]),
                                center: .center,
                                startRadius: 50,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)

                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    entry.stimmungsfarbe.opacity(0.85),
                                    entry.stimmungsfarbe,
                                ]),
                                center: .init(x: 0.35, y: 0.35),
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .shadow(color: entry.stimmungsfarbe.opacity(0.3), radius: 20, x: 0, y: 8)

                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [.white.opacity(0.25), .clear]),
                                center: .init(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 120, height: 120)
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: entry.id)

                Text((entry.moodLabel?.isEmpty == false ? entry.moodLabel : MoodCategory.resolve(entry.mood)?.rawValue.capitalized) ?? "home.mood_fallback".localized)
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(KlunaWarm.warmBrown)
            } else {
                ZStack {
                    Circle()
                        .stroke(KlunaWarm.warmBrown.opacity(0.06), lineWidth: 2)
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(KlunaWarm.warmBrown.opacity(0.02))
                        .frame(width: 116, height: 116)
                    Text("?")
                        .font(.system(.title, design: .rounded).weight(.light))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.15))
                }
                Text("home.how_feel".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
            }
        }
    }

    @ViewBuilder
    private func promptSection() -> some View {
        VStack(spacing: 8) {
            if questionGen.isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Color(hex: "#E8825C").opacity(0.3))
                    Text("conversation.kluna_thinking".localized)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.15))
                }
                .padding(.vertical, 20)
                .transition(.opacity)
            } else if !questionGen.currentQuestion.isEmpty {
                Text(questionGen.currentQuestion)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.35))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .transition(.opacity)
            } else {
                Text("\"\(promptManager.currentPrompt)\"")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .italic()
                    .lineSpacing(3)
                    .transition(.opacity)
            }

            if !questionGen.currentQuestion.isEmpty && !hasSeenRefreshHint {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9))
                        Text("home.pull_refresh".localized)
                        .font(.system(size: 11, design: .rounded))
                }
                .foregroundColor(Color(hex: "#3D3229").opacity(0.1))
                .padding(.top, 8)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            hasSeenRefreshHint = true
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.28), value: questionGen.currentQuestion)
        .animation(.easeInOut(duration: 0.28), value: questionGen.isGenerating)
    }

    private func reload() {
        dataManager.refresh(limit: 40)
        streak = calculateStreak()
    }

    private func animateHomeAppearance() {
        promptOpacity = 0
        greetingOffset = 15
        withAnimation(.easeOut(duration: 0.6)) {
            greetingOffset = 0
        }
        withAnimation(.easeIn(duration: 1.0).delay(0.5)) {
            promptOpacity = 1.0
        }
    }

    private func startInlineRecording() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if !conversationManager.isInConversation {
            conversationManager.startConversation()
        }
        moodExpanded = false
        transitionPhase = .point
        runTransitionSequence()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            recordingState = .recording
        }
        journalViewModel.startRecording()
    }

    private func stopInlineRecording() {
        guard recordingState == .recording else { return }
        transitionTask?.cancel()
        transitionPhase = .point
        moodExpanded = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        journalViewModel.stopRecording()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            recordingState = .analyzing
        }
    }

    private func runTransitionSequence() {
        transitionTask?.cancel()
        transitionTask = Task { @MainActor in
            transitionPhase = .expandingRing
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }

            transitionPhase = .spinningRing
            // Mindestens kurz drehen, dann auf echtes Mic-Signal warten.
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }

            let signalArrived = await waitForMicReadiness(maxWaitNanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }

            transitionPhase = .brakingRing
            let brakingDuration: UInt64 = signalArrived ? 380_000_000 : 620_000_000
            try? await Task.sleep(nanoseconds: brakingDuration)
            guard !Task.isCancelled else { return }

            transitionPhase = .morphingToLine
            try? await Task.sleep(nanoseconds: 360_000_000)
            guard !Task.isCancelled else { return }

            transitionPhase = .line
        }
    }

    private func waitForMicReadiness(maxWaitNanoseconds: UInt64) async -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds
        let checkInterval: UInt64 = 80_000_000
        while DispatchTime.now().uptimeNanoseconds - start < maxWaitNanoseconds {
            if Task.isCancelled { return false }
            // Signal gilt als da, wenn Pegel oder laufender Timer sichtbar anspringen.
            if journalViewModel.audioLevel > 0.015 || journalViewModel.elapsedTime >= 1 {
                return true
            }
            try? await Task.sleep(nanoseconds: checkInterval)
        }
        return false
    }

    private func timeGreeting() -> String {
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Guten Morgen."
        case 12..<17: return "Guten Tag."
        case 17..<21: return "Guten Abend."
        default: return "Noch wach?"
        }
    }

    private func refreshHomeData() async {
        reload()
    }

    private var todayEntry: JournalEntry? {
        dataManager.entries
            .filter { calendar.isDateInToday($0.date) }
            .sorted(by: { $0.date > $1.date })
            .first
    }

    private var hasEntryToday: Bool {
        todayEntry != nil
    }

    private func calculateStreak() -> Int {
        var days = 0
        var checkDate = Date()
        while true {
            let hasEntry = dataManager.entries.contains { calendar.isDate($0.date, inSameDayAs: checkDate) }
            if !hasEntry {
                if calendar.isDateInToday(checkDate) {
                    guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = prev
                    continue
                }
                break
            }
            days += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return days
    }

    private func calculateLongestStreak() -> Int {
        let days = Set(dataManager.entries.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var run = 1
        for idx in 1..<days.count {
            let delta = calendar.dateComponents([.day], from: days[idx - 1], to: days[idx]).day ?? 99
            if delta == 1 {
                run += 1
            } else {
                best = max(best, run)
                run = 1
            }
        }
        return max(best, run)
    }
}

struct CommunityPulse: View {
    let activeToday: Int
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: "6BC5A0"))
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .fill(Color(hex: "6BC5A0").opacity(0.28))
                        .frame(width: 12, height: 12)
                )
            Text(isGerman
                ? "\(activeToday) Menschen haben heute mit Kluna gesprochen"
                : "\(activeToday) people talked to Kluna today")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color(hex: "6BC5A0").opacity(0.06)))
    }
}

struct CoachFeedbackView: View {
    let entry: JournalEntry
    @State private var feedback: Int?
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        Group {
            if feedback == nil {
                HStack(spacing: 20) {
                    Button {
                        submit(1)
                    } label: {
                        Image(systemName: "hand.thumbsup")
                            .font(.system(size: 14))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.22))
                    }
                    Button {
                        submit(-1)
                    } label: {
                        Image(systemName: "hand.thumbsdown")
                            .font(.system(size: 14))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.22))
                    }
                }
            } else {
                Text((feedback == 1)
                    ? (isGerman ? "Danke! Kluna lernt." : "Thanks! Kluna is learning.")
                    : (isGerman ? "Danke. Wird besser." : "Thanks. Getting better."))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.28))
                    .transition(.opacity)
            }
        }
        .padding(.top, 6)
        .onAppear { feedback = CoachFeedbackStore.get(for: entry.id) }
    }

    private func submit(_ value: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { feedback = value }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        CoachFeedbackStore.save(value, for: entry.id)
        KlunaAnalytics.shared.track("coach_feedback", value: value > 0 ? "positive" : "negative")
        Task {
            await SupabaseManager.shared.donateCoachFeedback(
                entryId: entry.id,
                feedback: value,
                mood: entry.mood,
                roundIndex: Int(entry.roundIndex)
            )
        }
    }
}

struct ConversationFlowView: View {
    let isRecording: Bool
    let rounds: [ConversationManager.ConversationRound]
    let currentRound: Int
    let onRecordTap: () -> Void
    let onFinishTap: () -> Void
    @State private var selectedRound: Int = 0
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        VStack(spacing: 0) {
            if rounds.isEmpty && currentRound == 0 {
                Text("Sag kurz, was gerade wirklich in dir los ist.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

            if !rounds.isEmpty {
                HStack(spacing: 8) {
                    ForEach(0..<rounds.count, id: \.self) { index in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedRound = index
                            }
                        }) {
                            Capsule()
                                .fill(index == selectedRound ? Color(hex: "#E8825C") : Color(hex: "#E8825C").opacity(0.15))
                                .frame(width: index == selectedRound ? 20 : 8, height: 4)
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 20)

                TabView(selection: $selectedRound) {
                    ForEach(Array(rounds.enumerated()), id: \.offset) { index, round in
                        ScrollView(showsIndicators: false) {
                            RoundContentView(
                                round: round,
                                roundIndex: index,
                                isLatest: index == rounds.count - 1
                            )
                            .padding(.top, 16)
                            .padding(.bottom, 40)
                            .scaleEffect(selectedRound == index ? 1.0 : 0.97)
                            .opacity(selectedRound == index ? 1.0 : 0.88)
                            .offset(y: selectedRound == index ? 0 : 6)
                            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: selectedRound)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)
            }

            let isOnLatestRound = rounds.isEmpty || selectedRound == rounds.count - 1

            if isOnLatestRound {
                if let question = rounds.last?.claudeQuestion, !question.isEmpty {
                    VStack(spacing: 8) {
                        Text(isGerman ? "Kluna fragt:" : "Kluna asks:")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#3D3229").opacity(0.2))

                        Text(question)
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#3D3229").opacity(0.4))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }

                Button(action: onRecordTap) {
                    HStack(spacing: 6) {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isRecording ? "Aufnahme stoppen" : "Antwort aufnehmen")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                    }
                    .foregroundStyle(KlunaWarm.warmAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(KlunaWarm.warmAccent.opacity(0.10)))
                }

                if currentRound >= 1 {
                    Button(action: onFinishTap) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .medium))
                            Text("home.done".localized)
                                .font(.system(.subheadline, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.15))
                    }
                    .padding(.top, 16)
                }
            } else if !rounds.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedRound = rounds.count - 1
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("conversation.to_current".localized)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: "#E8825C").opacity(0.5))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#E8825C").opacity(0.06)))
                }
                .padding(.top, 20)
            }

            Spacer().frame(height: 30)
        }
        .padding(.horizontal, 20)
        .onAppear {
            selectedRound = max(0, rounds.count - 1)
        }
        .onChange(of: rounds.count) { _, newCount in
            withAnimation(.easeInOut(duration: 0.3)) {
                selectedRound = max(0, newCount - 1)
            }
        }
    }
}

struct RoundContentView: View {
    let round: ConversationManager.ConversationRound
    let roundIndex: Int
    let isLatest: Bool
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        let moodCol = moodColor(for: round.claudeMood ?? "ruhig")
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [moodCol.opacity(0.12), .clear]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [moodCol.opacity(0.6), moodCol]),
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 35
                        )
                    )
                    .frame(width: 70, height: 70)
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white.opacity(0.3), .clear]),
                            center: .init(x: 0.3, y: 0.3),
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .frame(width: 70, height: 70)
            }
            .padding(.bottom, 8)

            Text(round.claudeMood ?? "ruhig")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(moodCol.opacity(0.7))
                .padding(.top, 4)

            if let label = round.claudeLabel, !label.isEmpty {
                Text(label)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.25))
                    .padding(.top, 2)
            }

            HStack(spacing: 24) {
                MiniRoundDim(label: "Energie", value: round.dimensions.energy, delta: round.deltaFromPrevious?.energy)
                MiniRoundDim(label: "Anspannung", value: round.dimensions.tension, delta: round.deltaFromPrevious?.tension)
                MiniRoundDim(label: "Lebendigkeit", value: round.dimensions.expressiveness, delta: round.deltaFromPrevious?.expressiveness)
            }
            .padding(.top, 14)
            .padding(.bottom, 20)

            if !round.transcript.isEmpty {
                Text("Du sagst:")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.18))
                    .padding(.bottom, 6)
                Text("„\(round.transcript)“")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.25))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
            }

            if roundIndex > 0 {
                Text("\("conversation.round".localized) \(roundIndex + 1)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#E8825C").opacity(0.2))
                    .padding(.bottom, 8)
            }

            Text(round.claudeResponse)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#E8825C").opacity(0.8))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 6)

            if let voiceObservation = round.claudeVoiceObservation, !voiceObservation.isEmpty {
                VStack(spacing: 6) {
                    Text(isGerman ? "Deine Stimme sagt:" : "Your voice says:")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(moodCol.opacity(0.35))

                    Text(voiceObservation)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(moodCol.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 36)
                .padding(.top, 8)
            }

            if round.hasContradiction,
               let words = round.contradictionWords,
               let voice = round.contradictionVoice {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("home.words".localized)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#3D3229").opacity(0.2))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#3D3229").opacity(0.1))
                        Text("home.voice".localized)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#E8825C").opacity(0.4))
                    }
                    Text("\"\(words)\" -> \(voice)")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(Color(hex: "#E8825C").opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "#E8825C").opacity(0.03))
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }

            if let delta = round.deltaFromPrevious {
                let changes = significantChanges(delta)
                if !changes.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#6BC5A0").opacity(0.4))
                        Text(changes)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Color(hex: "#6BC5A0").opacity(0.4))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: "#6BC5A0").opacity(0.05)))
                    .padding(.top, 12)
                }
            }

            Spacer(minLength: isLatest ? 20 : 12)
        }
    }

    private func moodColor(for mood: String) -> Color {
        switch mood.lowercased() {
        case "begeistert", "aufgekratzt": return Color(hex: "#F5B731")
        case "angespannt", "aufgewuehlt", "frustriert": return Color(hex: "#E85C5C")
        case "erschoepft", "verletzlich": return Color(hex: "#8CA6D9")
        case "zufrieden", "ruhig", "nachdenklich": return Color(hex: "#6BC5A0")
        default: return Color(hex: "#E8825C")
        }
    }

    private func significantChanges(_ delta: ConversationManager.DimensionDelta) -> String {
        var changes: [String] = []
        if abs(delta.tension) > 0.08 { changes.append("Anspannung \(delta.tension > 0 ? "↑" : "↓")") }
        if abs(delta.warmth) > 0.08 { changes.append("Wärme \(delta.warmth > 0 ? "↑" : "↓")") }
        if abs(delta.energy) > 0.08 { changes.append("Energie \(delta.energy > 0 ? "↑" : "↓")") }
        return changes.joined(separator: " · ")
    }
}

struct MiniRoundDim: View {
    let label: String
    let value: Float
    let delta: Float?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color(hex: "#3D3229").opacity(0.04), lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: CGFloat(value) * 0.75)
                    .stroke(dimensionColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(135))
                if let d = delta, abs(d) > 0.05 {
                    Image(systemName: d > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(d > 0 ? Color(hex: "#E85C5C").opacity(0.5) : Color(hex: "#6BC5A0").opacity(0.5))
                }
            }
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.2))
        }
    }

    private var dimensionColor: Color {
        switch label {
        case "Energie": return Color(hex: "#F5B731")
        case "Anspannung": return Color(hex: "#E85C5C")
        case "Lebendigkeit": return Color(hex: "#6BC5A0")
        default: return Color(hex: "#E8825C")
        }
    }
}

struct ExpandableMoodCircle: View {
    let entry: JournalEntry?
    @Binding var isExpanded: Bool
    @Namespace private var moodAnimation
    @State private var player: AVAudioPlayer?

    var body: some View {
        Group {
            if let entry {
                if isExpanded {
                    expandedCard(entry: entry)
                } else {
                    collapsedCircle(entry: entry)
                }
            } else {
                emptyCircle()
            }
        }
    }

    @ViewBuilder
    private func collapsedCircle(entry: JournalEntry) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                entry.stimmungsfarbe.opacity(0.85),
                                entry.stimmungsfarbe,
                            ]),
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)
                    .matchedGeometryEffect(id: "moodBg", in: moodAnimation)
                    .shadow(color: entry.stimmungsfarbe.opacity(0.25), radius: 16, x: 0, y: 8)

                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white.opacity(0.25), .clear]),
                            center: .init(x: 0.3, y: 0.3),
                            startRadius: 0,
                            endRadius: 36
                        )
                    )
                    .frame(width: 110, height: 110)
            }
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    isExpanded = true
                }
            }

            Text((entry.moodLabel?.isEmpty == false ? entry.moodLabel : MoodCategory.resolve(entry.mood)?.rawValue.capitalized) ?? entry.quadrant.label)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(KlunaWarm.warmBrown)
                .matchedGeometryEffect(id: "moodLabel", in: moodAnimation)
        }
    }

    @ViewBuilder
    private func expandedCard(entry: JournalEntry) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                entry.stimmungsfarbe.opacity(0.85),
                                entry.stimmungsfarbe,
                            ]),
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: 48, height: 48)
                    .matchedGeometryEffect(id: "moodBg", in: moodAnimation)
                    .shadow(color: entry.stimmungsfarbe.opacity(0.2), radius: 8, x: 0, y: 4)

                Text((entry.moodLabel?.isEmpty == false ? entry.moodLabel : MoodCategory.resolve(entry.mood)?.rawValue.capitalized) ?? entry.quadrant.label)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .matchedGeometryEffect(id: "moodLabel", in: moodAnimation)

                Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle()
                .fill(entry.stimmungsfarbe.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 20)

            Text(entry.transcript)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.75))
                .lineSpacing(4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let coach = entry.coachText, !coach.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(KlunaWarm.warmAccent)
                        .padding(.top, 2)
                    Text(coach)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmAccent.opacity(0.85))
                        .lineSpacing(3)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(KlunaWarm.warmAccent.opacity(0.05))
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            HStack {
                if entry.audioRelativePath != nil {
                    Button(action: { playAudio(entry: entry) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("home.listen_again".localized)
                                .font(.system(.caption2, design: .rounded).weight(.medium))
                        }
                        .foregroundStyle(KlunaWarm.warmAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(KlunaWarm.warmAccent.opacity(0.08)))
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    MiniGauge(label: "E", value: CGFloat(entry.arousal / 100), color: entry.stimmungsfarbe)
                    MiniGauge(label: "W", value: CGFloat((entry.rawFeatures[FeatureKeys.hnr] ?? 12) / 25).clamped(to: 0...1), color: entry.stimmungsfarbe)
                    MiniGauge(label: "S", value: (1 - CGFloat((entry.rawFeatures[FeatureKeys.jitter] ?? 0.03) / 3)).clamped(to: 0...1), color: entry.stimmungsfarbe)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: entry.stimmungsfarbe.opacity(0.12), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(entry.stimmungsfarbe.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                isExpanded = false
            }
        }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 30 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            isExpanded = false
                        }
                    }
                }
        )
        .transition(.scale(scale: 0.3).combined(with: .opacity))
    }

    @ViewBuilder
    private func emptyCircle() -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(KlunaWarm.warmBrown.opacity(0.06), lineWidth: 2)
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(KlunaWarm.warmBrown.opacity(0.02))
                    .frame(width: 116, height: 116)

                Text("?")
                    .font(.system(.title, design: .rounded).weight(.light))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.15))
            }

            Text("home.how_feel".localized)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
        }
    }

    private func playAudio(entry: JournalEntry) {
        KlunaAudioPlayer.shared.play(audioPath: entry.audioRelativePath)
    }
}

struct MiniGauge: View {
    let label: String
    let value: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(KlunaWarm.warmBrown.opacity(0.06), lineWidth: 2)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: 0.75 * value.clamped(to: 0...1))
                    .stroke(color.opacity(0.5), lineWidth: 2)
                    .rotationEffect(.degrees(135))
            }
            .frame(width: 20, height: 20)

            Text(label)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
        }
    }
}

struct StreakBadgeView: View {
    let currentStreak: Int
    let longestStreak: Int
    let onShare: () -> Void

    @State private var showDetail = false
    @State private var flameScale: CGFloat = 1.0

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showDetail.toggle()
            }
        }) {
            HStack(spacing: 5) {
                Text("🔥")
                    .font(.system(size: 16))
                    .scaleEffect(flameScale)
                Text("\(currentStreak)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(KlunaWarm.warmBrown)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(streakColor.opacity(0.08))
            )
        }
        .popover(isPresented: $showDetail) {
            StreakDetailPopover(
                current: currentStreak,
                longest: longestStreak,
                color: streakColor,
                onShare: onShare
            )
            .presentationCompactAdaptation(.popover)
        }
        .onAppear {
            guard currentStreak >= 7 else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                flameScale = 1.15
            }
        }
    }

    private var streakColor: Color {
        switch currentStreak {
        case 0...2: return Color(hex: "E8825C").opacity(0.6)
        case 3...6: return Color(hex: "E8825C")
        case 7...13: return Color(hex: "F5B731")
        case 14...29: return Color(hex: "E85C5C")
        case 30...99: return Color(hex: "B088A8")
        default: return Color(hex: "F5B731")
        }
    }
}

struct StreakDetailPopover: View {
    let current: Int
    let longest: Int
    let color: Color
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("🔥")
                .font(.system(size: 48))

            VStack(spacing: 2) {
                Text("\(current)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(KlunaWarm.warmBrown)
                Text("Tage in Folge")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(KlunaWarm.warmBrown.opacity(0.3))
            }

            if longest > current {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "F5B731"))
                    Text("Rekord: \(longest)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(KlunaWarm.warmBrown.opacity(0.3))
                }
            }

            KlunaShareButton(action: onShare)
        }
        .padding(24)
        .frame(width: 220)
    }
}

struct InteractiveWeekBand: View {
    let weekEntries: [(weekday: String, entry: JournalEntry?)]
    @State private var selectedIndex: Int?
    @State private var appeared = false
    @State private var player: AVAudioPlayer?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(segmentColor(for: index))
                            .frame(height: segmentHeight(for: index))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(selectedIndex == index ? KlunaWarm.warmBrown.opacity(0.3) : .clear, lineWidth: 1.5)
                            )
                            .scaleEffect(x: appeared ? 1 : 0, y: appeared ? 1 : 0.3, anchor: .bottom)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.65).delay(Double(index) * 0.07),
                                value: appeared
                            )
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    selectedIndex = selectedIndex == index ? nil : index
                                }
                            }
                            .onLongPressGesture(minimumDuration: 0.35) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                playSnippet(for: index)
                            }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
            }
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekEntries[safe: index]?.weekday ?? "-")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(selectedIndex == index ? KlunaWarm.warmBrown : KlunaWarm.warmBrown.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 6)

            if let selectedIndex {
                weekDayDetail(for: selectedIndex)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    .padding(.top, 10)
            }
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
    }

    private func segmentColor(for index: Int) -> Color {
        if let entry = weekEntries[safe: index]?.entry {
            return entry.stimmungsfarbe
        }
        return KlunaWarm.warmBrown.opacity(0.06)
    }

    private func segmentHeight(for index: Int) -> CGFloat {
        guard let entry = weekEntries[safe: index]?.entry else { return 6 }
        let minHeight: CGFloat = 12
        let maxHeight: CGFloat = 44
        let ratio = CGFloat(entry.arousal / 100)
        return minHeight + (maxHeight - minHeight) * ratio
    }

    private func playSnippet(for index: Int) {
        guard let path = weekEntries[safe: index]?.entry?.audioRelativePath else { return }
        KlunaAudioPlayer.shared.play(audioPath: path)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            KlunaAudioPlayer.shared.stop()
        }
    }

    @ViewBuilder
    private func weekDayDetail(for index: Int) -> some View {
        if let entry = weekEntries[safe: index]?.entry {
            HStack(spacing: 10) {
                Circle()
                    .fill(entry.stimmungsfarbe)
                    .frame(width: 8, height: 8)

                Text(entry.moodLabel ?? MoodCategory.resolve(entry.mood)?.rawValue.capitalized ?? "home.mood_fallback".localized)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(KlunaWarm.warmBrown)

                Spacer()

                Text(entry.date.formatted(.dateTime.hour().minute()))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
            }
            .padding(.horizontal, 4)
        } else {
            Text("Kein Eintrag")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
        }
    }
}

struct GlowingRecordPoint: View {
    @State private var breathPhase: CGFloat = 0
    @Binding var recordingState: HomeRecordingState
    let action: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Button(action: action) {
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            KlunaWarm.warmAccent.opacity(0.25 + breathPhase * 0.2),
                            KlunaWarm.warmAccent.opacity(0.08 + breathPhase * 0.08),
                            KlunaWarm.warmAccent.opacity(0),
                        ]),
                        center: .center,
                        startRadius: 25,
                        endRadius: 70 + breathPhase * 20
                    )
                    .frame(width: 180, height: 180)

                    RadialGradient(
                        gradient: Gradient(colors: [
                            KlunaWarm.warmAccent.opacity(0.35 + breathPhase * 0.15),
                            KlunaWarm.warmAccent.opacity(0),
                        ]),
                        center: .center,
                        startRadius: 28,
                        endRadius: 50 + breathPhase * 10
                    )
                    .frame(width: 120, height: 120)

                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    KlunaWarm.warmAccent.opacity(0.95),
                                    KlunaWarm.warmAccent,
                                ]),
                                center: .init(x: 0.4, y: 0.4),
                                startRadius: 0,
                                endRadius: 32
                            )
                        )
                        .frame(width: 56 + breathPhase * 6, height: 56 + breathPhase * 6)
                        .shadow(
                            color: KlunaWarm.warmAccent.opacity(0.3 + breathPhase * 0.15),
                            radius: 14 + breathPhase * 6,
                            x: 0,
                            y: 4
                        )
                }
            }
            .buttonStyle(GlowButtonStyle())

            Text("home.record_now".localized)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathPhase = 1.0
            }
        }
    }
}

struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}

struct RecordingTransformView: View {
    let phase: TransitionPhase
    let audioLevel: CGFloat
    let elapsedSeconds: Int
    let isPremium: Bool
    let stopAction: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                if phase != .line {
                    PointToLineTransition(phase: phase)
                        .frame(width: 260, height: 80)
                }

                VoiceWaveLine(audioLevel: min(1.0, max(0, audioLevel)))
                    .frame(height: 60)
                    .padding(.horizontal, 40)
                    .opacity(phase == .line ? 1 : 0)
            }
            .frame(height: 80)

            HomeRecordingTimer(elapsedSeconds: elapsedSeconds, isPremium: isPremium)

            Button(action: stopAction) {
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            KlunaWarm.warmAccent.opacity(0.2),
                            KlunaWarm.warmAccent.opacity(0),
                        ]),
                        center: .center,
                        startRadius: 20,
                        endRadius: 50
                    )
                    .frame(width: 100, height: 100)

                    Circle()
                        .fill(KlunaWarm.warmAccent)
                        .frame(width: 56, height: 56)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                }
            }

            Text("home.done".localized)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
        }
    }

}

struct HomeRecordingTimer: View {
    let elapsedSeconds: Int
    let isPremium: Bool
    private let freeLimit = 20

    var body: some View {
        VStack(spacing: 4) {
            Text(formatTime(elapsedSeconds))
                .font(.system(size: 44, weight: .ultraLight, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                .monospacedDigit()

            if !isPremium {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(KlunaWarm.warmBrown.opacity(0.06))
                            .frame(height: 3)
                        Capsule()
                            .fill(elapsedSeconds > 15 ? KlunaWarm.warmAccent : KlunaWarm.warmBrown.opacity(0.15))
                            .frame(
                                width: geo.size.width * CGFloat(min(elapsedSeconds, freeLimit)) / CGFloat(freeLimit),
                                height: 3
                            )
                            .animation(.linear(duration: 0.25), value: elapsedSeconds)
                    }
                }
                .frame(width: 120, height: 3)
                .padding(.top, 4)

                if elapsedSeconds >= 15 && elapsedSeconds < freeLimit {
                    Text("\(freeLimit - elapsedSeconds)s")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmAccent.opacity(0.6))
                        .transition(.opacity)
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = max(0, seconds) / 60
        let s = max(0, seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct PointToLineTransition: View {
    let phase: TransitionPhase

    @State private var ringRotation: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringWidth: CGFloat = 60
    @State private var ringHeight: CGFloat = 60
    @State private var ringCornerRadius: CGFloat = 30
    @State private var ringStrokeWidth: CGFloat = 60

    var body: some View {
        RoundedRectangle(cornerRadius: ringCornerRadius)
            .stroke(KlunaWarm.warmAccent, lineWidth: ringStrokeWidth)
            .frame(width: ringWidth, height: ringHeight)
            .rotationEffect(.degrees(ringRotation))
            .scaleEffect(ringScale)
            .opacity(phase == .point ? 0 : 1)
            .onChange(of: phase) { _, newPhase in
                animatePhase(newPhase)
            }
    }

    private func animatePhase(_ newPhase: TransitionPhase) {
        switch newPhase {
        case .point:
            ringRotation = 0
            ringScale = 0.5
            ringWidth = 60
            ringHeight = 60
            ringCornerRadius = 30
            ringStrokeWidth = 60
        case .expandingRing:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                ringScale = 1.0
                ringStrokeWidth = 3
                ringWidth = 80
                ringHeight = 80
                ringCornerRadius = 40
            }
        case .spinningRing:
            withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        case .brakingRing:
            withAnimation(.easeOut(duration: 0.8)) {
                ringRotation = 0
            }
        case .morphingToLine:
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                ringWidth = 250
                ringHeight = 4
                ringCornerRadius = 2
                ringStrokeWidth = 3
                ringRotation = 0
            }
        case .line:
            break
        }
    }
}

struct VoiceWaveLine: View {
    let audioLevel: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let midY = size.height / 2
                let width = size.width
                let segments = 64
                let segmentWidth = width / CGFloat(segments)
                let level = max(0.02, min(1.0, audioLevel * 2.2))

                var path = Path()
                path.move(to: CGPoint(x: 0, y: midY))

                for i in 0...segments {
                    let x = CGFloat(i) * segmentWidth
                    let normalizedX = CGFloat(i) / CGFloat(segments)
                    let envelope = sin(normalizedX * .pi)
                    let phase = CGFloat(t * 5.0) + normalizedX * 8
                    let wave = sin(phase) * level * envelope
                    let noise = sin(phase * 1.9) * 0.08 * level
                    let y = midY + (wave + noise) * size.height * 0.36
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                let gradient = Gradient(colors: [
                    KlunaWarm.warmAccent.opacity(0.2),
                    KlunaWarm.warmAccent.opacity(0.8),
                    KlunaWarm.warmAccent,
                    KlunaWarm.warmAccent.opacity(0.8),
                    KlunaWarm.warmAccent.opacity(0.2),
                ])

                context.stroke(
                    path,
                    with: .linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: midY),
                        endPoint: CGPoint(x: width, y: midY)
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                context.stroke(
                    path,
                    with: .color(KlunaWarm.warmAccent.opacity(0.15)),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
            }
        }
    }
}

struct AnalyzingRing: View {
    @State private var rotation: Double = 0
    @State private var opacity: CGFloat = 1

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [
                                KlunaWarm.warmAccent,
                                KlunaWarm.warmAccent.opacity(0.3),
                                KlunaWarm.warmAccent.opacity(0),
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotation))

                Circle()
                    .fill(KlunaWarm.warmAccent.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .scaleEffect(opacity == 1 ? 1.0 : 1.1)
            }

            Text("conversation.kluna_thinking".localized)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                opacity = 0.7
            }
        }
    }
}

struct PackOpeningView: View {
    let transcript: String
    let entry: JournalEntry
    let card: DailyCard
    let previousCard: DailyCard?
    let klunaResponse: KlunaResponseViewData
    let onRespond: () -> Void
    let onDone: () -> Void

    @State private var showTranscript = false
    @State private var showCard = false
    @State private var cardFlipped = false
    @State private var showCoachText = false
    @State private var showActions = false
    @State private var glowPulse: CGFloat = 0.5

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

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
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if showCard {
                    VStack(spacing: 10) {
                        Text(isGerman ? "Deine Stimme sagt:" : "Your voice says:")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(card.primaryColor.opacity(0.4))

                        ZStack {
                            if !cardFlipped {
                                CardBackCover(glowColor: card.rarity.color, glowPulse: glowPulse)
                                    .frame(width: 300, height: 420)
                                    .onTapGesture {
                                        guard !cardFlipped else { return }
                                        revealCard()
                                    }

                                VStack {
                                    Spacer()
                                    Text(isGerman ? "Tippe zum Enthüllen" : "Tap to reveal")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(.bottom, 50)
                                }
                                .frame(width: 300, height: 420)
                                .allowsHitTesting(false)
                            } else {
                                DailyCardView(card: card)
                                    .frame(width: 300, height: 420)
                                    .allowsHitTesting(false)
                            }
                        }

                        if cardFlipped {
                            RarityRevealBadge(rarity: card.rarity)
                                .padding(.top, 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.bottom, 20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                if showCoachText {
                    VStack(spacing: 12) {
                        Text(klunaResponse.text)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "E8825C").opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 28)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        if let voice = klunaResponse.voiceObservation, !voice.isEmpty {
                            Text(voice)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(card.primaryColor.opacity(0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 4)
                        }

                        if let contradiction = ContradictionStore.load(for: entry.id) {
                            VStack(spacing: 6) {
                                HStack(spacing: 6) {
                                    Text(isGerman ? "Deine Worte" : "Your words")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(Color(hex: "3D3229").opacity(0.15))
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 9))
                                        .foregroundColor(Color(hex: "3D3229").opacity(0.08))
                                    Text(isGerman ? "Deine Stimme" : "Your voice")
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(Color(hex: "E8825C").opacity(0.3))
                                }

                                Text("\(contradiction.wordsSay) ↔ \(contradiction.voiceSays)")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(Color(hex: "E8825C").opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "E8825C").opacity(0.03))
                            )
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                        }

                        CoachFeedbackView(entry: entry)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if showActions {
                    VStack(spacing: 12) {
                        if let question = klunaResponse.question, !question.isEmpty {
                            Text(question)
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "3D3229").opacity(0.3))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal, 28)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 8)
                        }

                        Button(action: onRespond) {
                            HStack(spacing: 8) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 14))
                                Text(isGerman ? "Antworten" : "Respond")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(hex: "E8825C"))
                                    .shadow(color: Color(hex: "E8825C").opacity(0.2), radius: 12, x: 0, y: 6)
                            )
                        }
                        .padding(.horizontal, 40)
                        .buttonStyle(.plain)

                        Button(action: onDone) {
                            Text(isGerman ? "Fertig" : "Done")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(Color(hex: "3D3229").opacity(0.15))
                        }
                        .padding(.top, 4)
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: 60)
            }
        }
        .background(Color(hex: "FFF8F0").ignoresSafeArea())
        .onAppear {
            startSequence()
        }
    }

    func startSequence() {
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowPulse = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) { showTranscript = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { showCard = true }
        }
    }

    func revealCard() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            cardFlipped = true
        }

        if card.rarity == .legendary {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } else if card.rarity == .rare {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.6)) { showCoachText = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) { showActions = true }
        }
    }

    var isGerman: Bool { Locale.current.language.languageCode?.identifier == "de" }
}

struct CardBackCover: View {
    let glowColor: Color
    let glowPulse: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "1A1A2E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.06 + 0.04 * glowPulse), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 160
                    )
                )

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(glowColor.opacity(0.1 + 0.1 * glowPulse), lineWidth: 1)
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(glowColor.opacity(0.05 + 0.05 * glowPulse), lineWidth: 1)
                        .frame(width: 100, height: 100)
                    Text("K")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(glowColor.opacity(0.25 + 0.15 * glowPulse))
                }
                Text("?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.1))
            }

            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    AngularGradient(
                        colors: [
                            glowColor.opacity(0.1),
                            .white.opacity(0.05),
                            glowColor.opacity(0.15),
                            .white.opacity(0.03),
                            glowColor.opacity(0.1),
                        ],
                        center: .center
                    ),
                    lineWidth: 1.5
                )
        }
        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }
}

struct RarityRevealBadge: View {
    let rarity: CardRarity
    @State private var glowing = false

    var body: some View {
        HStack(spacing: 8) {
            if rarity == .legendary {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(rarity.color)
            }
            Text(rarity.label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundColor(rarity.color)
            if rarity == .legendary {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(rarity.color)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(rarity.color.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(rarity.color.opacity(glowing ? 0.3 : 0.1), lineWidth: 1)
                )
        )
        .shadow(color: rarity.color.opacity(glowing ? 0.2 : 0), radius: 12)
        .onAppear {
            if rarity == .legendary || rarity == .rare {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    glowing = true
                }
            }
        }
    }
}

struct ParticleExplosion: View {
    let color: Color
    let count: Int

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var targetX: CGFloat
        var targetY: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color.opacity(particle.opacity))
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: 0.5)
                }
            }
            .onAppear {
                spawnParticles(in: geo.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func spawnParticles(in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let distance = CGFloat.random(in: 80...220)
            let particleSize = CGFloat.random(in: 2...6)
            let particle = Particle(
                x: center.x,
                y: center.y,
                size: particleSize,
                opacity: 0.8,
                targetX: center.x + cos(angle) * distance,
                targetY: center.y + sin(angle) * distance
            )
            particles.append(particle)
            let index = particles.count - 1
            withAnimation(.easeOut(duration: Double.random(in: 0.6...1.2))) {
                particles[index].x = particle.targetX
                particles[index].y = particle.targetY
                particles[index].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            particles = []
        }
    }
}

struct CardComparisonHint: View {
    let before: DailyCard
    let after: DailyCard

    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        let tensionChange = after.dims.tension - before.dims.tension
        let warmthChange = after.dims.warmth - before.dims.warmth

        if abs(tensionChange) > 0.08 || abs(warmthChange) > 0.08 {
            HStack(spacing: 8) {
                Circle().fill(before.primaryColor).frame(width: 12, height: 12)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "3D3229").opacity(0.15))
                Circle().fill(after.primaryColor).frame(width: 12, height: 12)
                Text(changeText(tensionChange: tensionChange, warmthChange: warmthChange))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color(hex: "6BC5A0").opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color(hex: "6BC5A0").opacity(0.04)))
            .padding(.top, 8)
        }
    }

    private func changeText(tensionChange: CGFloat, warmthChange: CGFloat) -> String {
        if tensionChange < -0.1 && warmthChange > 0.05 {
            return isGerman ? "Entspannter und wärmer" : "More relaxed and warmer"
        }
        if tensionChange < -0.1 {
            return isGerman ? "Ruhiger geworden" : "Getting calmer"
        }
        if warmthChange > 0.1 {
            return isGerman ? "Wärmer geworden" : "Getting warmer"
        }
        if tensionChange > 0.1 {
            return isGerman ? "Etwas arbeitet" : "Something is working"
        }
        return isGerman ? "Verändert sich" : "Shifting"
    }
}

struct InlineResultView: View {
    let entry: JournalEntry
    let onDismiss: () -> Void
    let onRecordAgain: () -> Void
    @ObservedObject private var promptManager = PromptManager.shared
    @State private var showTranscript = false
    @State private var showCoach = false
    @State private var showActions = false
    @State private var showVoice = false

    private var dims: VoiceDimensions {
        VoiceDimensions.from(entry)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(entry.transcript)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(showTranscript ? 1 : 0)

            if let coach = entry.coachText, !coach.isEmpty {
                Text(coach)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmAccent)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(showCoach ? 1 : 0)
                    .offset(y: showCoach ? 0 : 10)

                CoachFeedbackView(entry: entry)
                    .opacity(showCoach ? 1 : 0)
            }

            if let contradiction = ContradictionStore.load(for: entry.id) {
                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        VStack(spacing: 4) {
                            Text("home.words".localized)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                            Text(contradiction.wordsSay)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                                .multilineTextAlignment(.center)
                        }

                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(KlunaWarm.warmAccent.opacity(0.35))

                        VStack(spacing: 4) {
                            Text("home.voice".localized)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmAccent.opacity(0.55))
                            Text(contradiction.voiceSays)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(KlunaWarm.warmAccent)
                                .multilineTextAlignment(.center)
                        }
                    }

                    let payload = ContradictionShareData(
                        wordsSay: contradiction.wordsSay,
                        voiceSays: contradiction.voiceSays,
                        moodColor: entry.stimmungsfarbe,
                        date: entry.date
                    )
                    KlunaShareButton(action: {
                        ShareABManager.shared.trackTap(.contradiction)
                        ShareImageGenerator.share(content: .contradiction(payload))
                    })
                    .onAppear {
                        ShareABManager.shared.trackShown(.contradiction)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(KlunaWarm.warmAccent.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(KlunaWarm.warmAccent.opacity(0.08), lineWidth: 1)
                        )
                )
            }

            VoiceSignatureV2Mini(entry: entry, size: 60)
                .opacity(showVoice ? 1 : 0)
                .scaleEffect(showVoice ? 1 : 0.5)
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    NotificationCenter.default.post(name: .klunaOpenVoiceTab, object: nil)
                }

            HStack(spacing: 16) {
                MiniDimension(label: "Energie", value: dims.energy, color: entry.stimmungsfarbe)
                MiniDimension(label: "Anspannung", value: dims.tension, color: entry.stimmungsfarbe)
                MiniDimension(label: "Lebendigkeit", value: dims.expressiveness, color: entry.stimmungsfarbe)
            }
            .opacity(showVoice ? 1 : 0)

            if showActions {
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        Text(promptManager.currentPrompt)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                            .multilineTextAlignment(.center)

                        Button(action: {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            onRecordAgain()
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(KlunaWarm.warmAccent)
                                    .frame(width: 28, height: 28)
                                Text("home.continue".localized)
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(KlunaWarm.warmAccent)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(KlunaWarm.warmAccent.opacity(0.08))
                            )
                        }
                    }

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onDismiss()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                            Text("home.done".localized)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                        }
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(KlunaWarm.warmBrown.opacity(0.06))
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35).delay(0.2)) { showTranscript = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.5)) { showCoach = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.68)) { showVoice = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.9)) { showActions = true }
        }
    }
}

struct MiniDimension: View {
    let label: String
    let value: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(KlunaWarm.warmBrown.opacity(0.06), lineWidth: 2)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: 0.75 * min(1, max(0, value)))
                    .stroke(color, lineWidth: 2)
                    .rotationEffect(.degrees(135))
            }
            .frame(width: 28, height: 28)

            Text(label)
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
        }
    }
}

struct VoiceSignature: View {
    let entry: JournalEntry
    let size: CGFloat
    @State private var drawProgress: CGFloat = 0

    private var arousal: CGFloat { CGFloat(entry.arousal / 100) }
    private var valence: CGFloat { CGFloat(entry.acousticValence / 100) }

    var body: some View {
        ZStack {
            signaturePath()
                .fill(entry.stimmungsfarbe.opacity(0.1))
                .blur(radius: 10)
                .scaleEffect(1.1)

            signaturePath()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            entry.stimmungsfarbe.opacity(0.7),
                            entry.stimmungsfarbe.opacity(0.3),
                        ]),
                        center: .init(x: 0.4, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.45
                    )
                )

            signaturePath()
                .trim(from: 0, to: drawProgress)
                .stroke(entry.stimmungsfarbe.opacity(0.4), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                drawProgress = 1
            }
        }
    }

    private func signaturePath() -> Path {
        Path { path in
            let center = CGPoint(x: size / 2, y: size / 2)
            let a = arousal
            let v = valence

            let warmth = featureValue("hnr", fallback: v * 0.7 + 0.15)
            let jitter = featureValue("jitter", fallback: (1 - v) * 0.3 + a * 0.2)
            let speechRate = featureValue("speechRate", fallback: a * 0.6 + 0.2)
            let f0Range = featureValue("f0Range", fallback: a * 0.5 + (1 - v) * 0.3)

            let seed = entry.date.timeIntervalSince1970
            let lobes = 3.0 + a * 4.0
            let lobeDepth = 0.15 + jitter * 0.35
            let asymmetry = f0Range * 0.2
            let baseRadius = size * 0.25 * (0.5 + a * 0.5)

            let points = 200
            for i in 0...points {
                let t = CGFloat(i) / CGFloat(points)
                let angle = t * .pi * 2

                let mainShape = 1.0 + lobeDepth * sin(angle * lobes)
                let asymmetryOffset = asymmetry * sin(angle * 2 + CGFloat(seed.truncatingRemainder(dividingBy: 6.28)))
                let noise1 = jitter * 0.12 * sin(angle * 13 + CGFloat(seed.truncatingRemainder(dividingBy: 100)))
                let noise2 = jitter * 0.06 * cos(angle * 21 + 1.7)
                let warmthSmooth = warmth * 0.08 * sin(angle * 7 + 3.1)
                let tempoRipple = speechRate * 0.04 * sin(angle * (10 + speechRate * 8))
                let radius = baseRadius * (mainShape + asymmetryOffset + noise1 + noise2 + warmthSmooth + tempoRipple)

                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.closeSubpath()
        }
    }

    private func featureValue(_ key: String, fallback: CGFloat) -> CGFloat {
        let normalized: CGFloat?
        switch key {
        case "hnr":
            normalized = entry.rawFeatures[FeatureKeys.hnr].map { CGFloat($0 / 30) }
        case "jitter":
            normalized = entry.rawFeatures[FeatureKeys.jitter].map { CGFloat($0 / 5) }
        case "speechRate":
            normalized = entry.rawFeatures[FeatureKeys.speechRate].map { CGFloat($0 / 8) }
        case "f0Range":
            let f0 = entry.rawFeatures[FeatureKeys.f0RangeST] ?? entry.rawFeatures[FeatureKeys.f0Range]
            normalized = f0.map { CGFloat($0 / 20) }
        default:
            normalized = nil
        }
        return (normalized ?? fallback).clamped(to: 0...1)
    }
}

struct RecordingSheet: View {
    @ObservedObject var viewModel: JournalViewModel
    @ObservedObject private var promptManager = PromptManager.shared
    @Environment(\.dismiss) private var dismiss

    enum RecordingState {
        case ready
        case recording
        case analyzing
        case result
    }

    @State private var recordingState: RecordingState = .ready
    @State private var resultEntry: JournalEntry?

    var body: some View {
        NavigationStack {
            ZStack {
                KlunaWarm.background.ignoresSafeArea()

                VStack {
                    switch recordingState {
                    case .ready:
                        readyView
                    case .recording:
                        recordingView
                    case .analyzing:
                        analyzingView
                    case .result:
                        if let resultEntry {
                            resultView(entry: resultEntry)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if !viewModel.isRecording && !viewModel.isProcessing {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(KlunaWarm.warmBrown.opacity(0.06)))
                    }
                    .disabled(viewModel.isRecording || viewModel.isProcessing)
                }
            }
        }
        .onChange(of: viewModel.latestSavedEntry?.id) { _, _ in
            if let entry = viewModel.latestSavedEntry {
                resultEntry = entry
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    recordingState = .result
                }
            }
        }
        .onChange(of: viewModel.elapsedTime) { _, newValue in
            if viewModel.isRecording, newValue >= 20 {
                stopRecording()
            }
        }
    }

    private var readyView: some View {
        VStack {
            Spacer()
            Text(promptManager.currentPrompt)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(KlunaWarm.warmBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            BreathingRecordButton {
                startRecording()
            }
            Spacer().frame(height: 80)
        }
    }

    private var recordingView: some View {
        VStack {
            Spacer()
            Text(promptManager.currentPrompt)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                .padding(.bottom, 32)

            OrganicAudioVisualizer(level: CGFloat(viewModel.audioLevel))
                .frame(width: 240, height: 240)

            Text(formatTime(Int(viewModel.elapsedTime)))
                .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
                .monospacedDigit()
                .padding(.top, 24)

            if let error = viewModel.recordingError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
            }

            Spacer()

            Button {
                stopRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(KlunaWarm.warmAccent.opacity(0.15))
                        .frame(width: 84, height: 84)
                    Circle()
                        .fill(KlunaWarm.warmAccent)
                        .frame(width: 64, height: 64)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 22, height: 22)
                }
            }
            .disabled(!viewModel.isRecording || viewModel.isProcessing)

            Text("home.done".localized)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))

            Spacer().frame(height: 60)
        }
    }

    private var analyzingView: some View {
        VStack {
            Spacer()
            AnalyzingAnimation()
            Text("conversation.kluna_thinking".localized)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                .padding(.top, 24)
            Spacer()
        }
    }

    private func resultView(entry: JournalEntry) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.system(.headline, design: .rounded))
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                }
                .padding(.top, 16)

                WarmCard {
                    Text(entry.transcript)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(KlunaWarm.color(for: entry.quadrant), lineWidth: 4)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(KlunaWarm.color(for: entry.quadrant).opacity(0.2))
                            .frame(width: 64, height: 64)
                    }
                    Text(entry.moodLabel ?? entry.quadrant.label)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                }

                VStack(spacing: 10) {
                    MoodBar(label: "Energie", value: CGFloat(entry.arousal / 100), color: KlunaWarm.warmAccent)
                    MoodBar(label: "Stimmung", value: CGFloat(entry.acousticValence / 100), color: KlunaWarm.color(for: entry.quadrant))
                }
                .padding(.horizontal, 32)

                if let coach = entry.coachText, !coach.isEmpty {
                    CoachCard(text: coach)
                }

                VStack(spacing: 10) {
                    Text("Möchtest du noch etwas sagen?")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    Button {
                        resultEntry = nil
                        viewModel.latestSavedEntry = nil
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            recordingState = .ready
                        }
                    } label: {
                        Circle()
                            .fill(KlunaWarm.warmAccent.opacity(0.15))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .fill(KlunaWarm.warmAccent.opacity(0.5))
                                    .frame(width: 32, height: 32)
                            )
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(KlunaWarm.zufrieden)
                    Text("home.entry_saved".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                }

                Button {
                    dismiss()
                } label: {
                    Text("home.back_to_journal".localized)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(KlunaWarm.warmAccent)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().stroke(KlunaWarm.warmAccent.opacity(0.3), lineWidth: 1))
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
    }

    private func startRecording() {
        viewModel.latestSavedEntry = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            recordingState = .recording
        }
        viewModel.startRecording()
    }

    private func stopRecording() {
        guard viewModel.isRecording else { return }
        viewModel.stopRecording()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            recordingState = .analyzing
        }
    }

    private func formatTime(_ value: Int) -> String {
        let sec = max(0, 20 - value)
        return "0:\(String(format: "%02d", sec))"
    }
}

struct AnalyzingAnimation: View {
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            KlunaWarm.warmAccent.opacity(0.3),
                            KlunaWarm.warmAccent.opacity(0.05),
                            KlunaWarm.warmAccent.opacity(0.3)
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(rotation))

            Circle()
                .fill(KlunaWarm.warmAccent.opacity(0.12))
                .frame(width: 80, height: 80)
                .scaleEffect(pulseScale)

            Circle()
                .fill(KlunaWarm.warmAccent.opacity(0.08))
                .frame(width: 50, height: 50)
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }
}

struct GreetingGenerator {
    static func generate(lastEntry: JournalEntry?, currentHour: Int, entriesThisWeek: Int) -> (greeting: String, subtitle: String) {
        let timeGreeting: String
        switch currentHour {
        case 5..<12: timeGreeting = "Guten Morgen."
        case 12..<17: timeGreeting = "Guten Tag."
        case 17..<22: timeGreeting = "Guten Abend."
        default: timeGreeting = "Noch wach?"
        }

        let subtitle: String
        if let last = lastEntry {
            let daysAgo = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
            if daysAgo == 0 {
                subtitle = "Du hast heute schon eingesprochen. Noch etwas auf dem Herzen?"
            } else if daysAgo == 1 {
                switch last.quadrant {
                case .begeistert: subtitle = "Gestern war viel Energie da. Wie geht's heute weiter?"
                case .aufgewuehlt: subtitle = "Gestern war es aufwühlend. Wie ist es heute?"
                case .zufrieden: subtitle = "Gestern warst du ruhig und zufrieden. Und heute?"
                case .erschoepft: subtitle = "Gestern war ein schwerer Tag. Wie geht es dir heute?"
                }
            } else if daysAgo <= 3 {
                subtitle = "Schön, dass du wieder da bist."
            } else {
                subtitle = "Lang nicht gehört. Was ist passiert?"
            }
        } else {
            subtitle = entriesThisWeek == 0 ? "Dein erstes Mal hier. Erzähl einfach." : "Was liegt dir heute auf dem Herzen?"
        }
        return (timeGreeting, subtitle)
    }
}

struct WeekMoodRing: View {
    let entry: JournalEntry?

    var body: some View {
        ZStack {
            if let entry {
                let c = KlunaWarm.color(for: entry.quadrant)
                Circle()
                    .stroke(c, lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .fill(c.opacity(0.3))
                    .frame(
                        width: 36 * CGFloat(max(0.2, min(1.0, entry.arousal / 100))),
                        height: 36 * CGFloat(max(0.2, min(1.0, entry.arousal / 100)))
                    )
                    .animation(.easeInOut(duration: 0.35), value: entry.arousal)
            } else {
                Circle()
                    .stroke(KlunaWarm.warmBrown.opacity(0.08), lineWidth: 1)
                    .frame(width: 36, height: 36)
            }
        }
    }
}

struct WeekMoodRings: View {
    let weekEntries: [(weekday: String, entry: JournalEntry?)]
    @State private var selectedIndex: Int?
    @State private var appeared = false

    var body: some View {
        WarmCard {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ForEach(0..<7, id: \.self) { i in
                        let item = weekEntries[safe: i]
                        VStack(spacing: 6) {
                            Text(item?.weekday ?? "-")
                                .font(.system(.caption2, design: .rounded).weight(.medium))
                                .foregroundStyle(selectedIndex == i ? KlunaWarm.warmBrown : KlunaWarm.warmBrown.opacity(0.5))

                            ZStack {
                                if let entry = item?.entry {
                                    let color = KlunaWarm.color(for: entry.quadrant)
                                    Circle()
                                        .stroke(color, lineWidth: selectedIndex == i ? 3 : 2.5)
                                        .frame(width: 34, height: 34)
                                    Circle()
                                        .fill(color.opacity(0.2))
                                        .frame(
                                            width: 34 * CGFloat(max(0.2, min(1, entry.arousal / 100))),
                                            height: 34 * CGFloat(max(0.2, min(1, entry.arousal / 100)))
                                        )
                                } else {
                                    Circle()
                                        .stroke(KlunaWarm.warmBrown.opacity(0.06), lineWidth: 0.5)
                                        .frame(width: 34, height: 34)
                                }
                            }
                            .scaleEffect(selectedIndex == i ? 1.15 : 1)
                            .scaleEffect(appeared ? 1 : 0.5)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.4).delay(Double(i) * 0.06), value: appeared)
                            .onTapGesture {
                                guard item?.entry != nil else { return }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedIndex = selectedIndex == i ? nil : i
                                }
                            }
                        }
                    }
                }

                if let idx = selectedIndex, let entry = weekEntries[safe: idx]?.entry {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(KlunaWarm.color(for: entry.quadrant))
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.moodLabel ?? entry.quadrant.label)
                                .font(.system(.caption, design: .rounded).weight(.medium))
                                .foregroundStyle(KlunaWarm.warmBrown)
                            Text(String(entry.transcript.prefix(50)) + "…")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KlunaWarm.color(for: entry.quadrant).opacity(0.06))
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            }
        }
    }
}

struct MiniEntryPreview: View {
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(KlunaWarm.color(for: entry.quadrant))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.moodLabel ?? entry.quadrant.label)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Text(String(entry.transcript.prefix(60)) + "…")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(KlunaWarm.color(for: entry.quadrant).opacity(0.06))
        )
    }
}

struct AnimatedPromptCard: View {
    let prompt: String
    let onNextPrompt: () -> Void
    @State private var opacity: CGFloat = 0
    @State private var offsetY: CGFloat = 10

    var body: some View {
        WarmCard {
            VStack {
                Text(prompt)
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .opacity(opacity)
            .offset(y: offsetY)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
            }
            .onTapGesture {
                triggerNextPrompt()
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard abs(value.translation.width) > 35 else { return }
                        triggerNextPrompt()
                    }
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(0.25)) {
                    opacity = 1
                    offsetY = 0
                }
            }
        }
    }

    private func triggerNextPrompt() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) {
            opacity = 0
            offsetY = -8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            onNextPrompt()
            withAnimation(.easeOut(duration: 0.45)) {
                opacity = 1
                offsetY = 0
            }
        }
    }
}

struct BreathingRecordButton: View {
    @State private var breathScale: CGFloat = 1
    @State private var glowOpacity: CGFloat = 0.08
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            } label: {
                ZStack {
                    Circle()
                        .fill(KlunaWarm.warmAccent.opacity(glowOpacity))
                        .frame(width: 110, height: 110)
                        .scaleEffect(breathScale)
                    Circle()
                        .fill(KlunaWarm.warmAccent.opacity(0.15))
                        .frame(width: 84, height: 84)
                        .scaleEffect(1 + (breathScale - 1) * 0.5)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [KlunaWarm.warmAccent, KlunaWarm.warmAccent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                        .shadow(color: KlunaWarm.warmAccent.opacity(0.25), radius: 10, x: 0, y: 5)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            .onAppear {
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    breathScale = 1.12
                    glowOpacity = 0.14
                }
            }
            Text("home.record_now".localized)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
        }
    }
}

private struct HomeScrollOffsetPreference: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct EntryCard: View {
    let entry: JournalEntry
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [KlunaWarm.color(for: entry.quadrant), KlunaWarm.color(for: entry.quadrant).opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 5)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(KlunaWarm.color(for: entry.quadrant), lineWidth: 2.5)
                            .frame(width: 28, height: 28)
                        Circle()
                            .fill(KlunaWarm.color(for: entry.quadrant).opacity(0.25))
                            .frame(
                                width: 28 * CGFloat(max(0.2, min(1.0, entry.arousal / 100))),
                                height: 28 * CGFloat(max(0.2, min(1.0, entry.arousal / 100)))
                            )
                    }
                }

                Text(entry.transcript)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Circle()
                        .fill(KlunaWarm.color(for: entry.quadrant))
                        .frame(width: 6, height: 6)
                    Text(entry.moodLabel ?? entry.quadrant.label)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 20)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct MoodCircle: View {
    let quadrant: EmotionQuadrant
    let arousal: Float

    var body: some View {
        let c = KlunaWarm.color(for: quadrant)
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(colors: [c, c.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 4
                )
                .frame(width: 80, height: 80)
            Circle()
                .fill(c.opacity(0.2))
                .frame(width: 72, height: 72)
            Circle()
                .fill(c.opacity(0.4))
                .frame(
                    width: CGFloat(max(10, (arousal / 100) * 60)),
                    height: CGFloat(max(10, (arousal / 100) * 60))
                )
        }
    }
}

struct CoachCard: View {
    let text: String

    var body: some View {
        WarmCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundStyle(KlunaWarm.warmAccent)
                    .padding(.top, 2)
                Text(text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EntryResultView: View {
    let entry: JournalEntry
    @State private var showTranscript = false
    @State private var showMood = false
    @State private var showCoach = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                }
                .foregroundStyle(KlunaWarm.warmBrown)
                .padding(.top, 20)

                WarmCard {
                    Text(entry.transcript.isEmpty ? "…" : entry.transcript)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .opacity(showTranscript ? 1 : 0)
                .offset(y: showTranscript ? 0 : 20)

                VStack(spacing: 10) {
                    MoodCircle(quadrant: entry.quadrant, arousal: entry.arousal)
                    Text(entry.moodLabel ?? entry.quadrant.title)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                }
                .opacity(showMood ? 1 : 0)
                .offset(y: showMood ? 0 : 20)

                VStack(spacing: 12) {
                    MoodBar(label: "Energie", value: CGFloat(entry.arousal / 100), color: KlunaWarm.warmAccent)
                    MoodBar(label: "Stimmung", value: CGFloat(entry.acousticValence / 100), color: KlunaWarm.color(for: entry.quadrant))
                }
                .padding(.horizontal, 10)
                .opacity(showMood ? 1 : 0)
                .offset(y: showMood ? 0 : 20)

                if let coach = entry.coachText, !coach.isEmpty {
                    CoachCard(text: coach)
                        .opacity(showCoach ? 1 : 0)
                        .offset(y: showCoach ? 0 : 20)
                }

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green.opacity(0.7))
                    Text("home.entry_saved".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .background(KlunaWarm.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { showTranscript = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) { showMood = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) { showCoach = true }
        }
    }
}

struct MoodBar: View {
    let label: String
    let value: CGFloat
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(KlunaWarm.warmBrown.opacity(0.06))
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(colors: [color.opacity(0.5), color], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: geo.size.width * max(0, min(1, value)), height: 6)
                        .animation(.easeOut(duration: 0.8), value: value)
                }
            }
            .frame(height: 6)
        }
    }
}

struct EntryDetailView: View {
    let entry: JournalEntry
    @State private var player: AVAudioPlayer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(entry.date.formatted(date: .complete, time: .shortened))
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)

                WarmCard {
                    Text(entry.transcript)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(entry.moodLabel ?? entry.quadrant.label)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))

                if let coach = entry.coachText, !coach.isEmpty {
                    CoachCard(text: coach)
                }

                Button("Audio abspielen") { play() }
                    .buttonStyle(.borderedProminent)
                    .tint(KlunaWarm.warmAccent)

                if let prompt = entry.prompt, !prompt.isEmpty {
                    Text("Prompt: \(prompt)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                }
            }
            .padding(20)
        }
        .background(KlunaWarm.background.ignoresSafeArea())
    }

    private func play() {
        KlunaAudioPlayer.shared.play(audioPath: entry.audioRelativePath)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
