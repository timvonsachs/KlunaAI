import SwiftUI

struct ScoreView: View {
    @ObservedObject var viewModel: SessionViewModel
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    private let memoryManager = MemoryManager(context: PersistenceController.shared.container.viewContext)
    @State private var showDeepCoachingSheet = false
    @State private var coachModeActive = false
    @State private var showPaywall = false
    @State private var paywallTrigger: PaywallTrigger = .general
    @State private var showSoftUpsell = false
    @State private var showDimensionInfo = false
    @State private var selectedDimensionInfo: PerformanceDimension?
    @State private var unlockMessage: String?
    @State private var showUnlockToast = false
    private var userLanguage: String {
        memoryManager.loadUser().language
    }
    private var sessionCount: Int {
        memoryManager.totalSessionCount()
    }
    private var dimensionExplanations: [DimensionExplanation] {
        HowKlunaMeasuresView(language: userLanguage).dimensionExplanations
    }

    var body: some View {
        ScrollView {
            VStack(spacing: KlunaSpacing.lg) {
                Spacer(minLength: KlunaSpacing.xl)

                if sessionCount >= 4,
                   let prediction = viewModel.currentPrediction,
                   let scores = viewModel.currentScores {
                    PredictionRevealView(
                        prediction: prediction,
                        actualScore: scores.overall
                    )
                } else {
                    ScoreRingView(
                        score: viewModel.currentScores?.overall ?? 0,
                        isPreliminary: true,
                        isNewHighScore: viewModel.isNewHighScore
                    )
                    if sessionCount >= 4, viewModel.currentScores != nil, viewModel.currentPrediction == nil {
                        let sessionsBeforeCurrent = max(0, memoryManager.totalSessionCount() - 1)
                        let remaining = max(0, ScorePredictionEngine.minimumSessions - sessionsBeforeCurrent)
                        if remaining > 0 {
                            Text("Noch \(remaining) Sessions bis zur Score-Vorhersage")
                                .font(KlunaFont.caption(11))
                                .foregroundColor(.klunaMuted)
                        }
                    }
                }

                if sessionCount >= 2, let baselineProgress = viewModel.baselineProgress {
                    HStack(spacing: 6) {
                        if baselineProgress.isEstablished {
                            Image(systemName: "person.fill.checkmark")
                                .font(.system(size: 10))
                                .foregroundColor(.klunaGold)
                            Text(L10n.personallyCalibrated)
                                .font(KlunaFont.caption(11))
                                .foregroundColor(.klunaGold)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.klunaAccent)
                            Text("\(L10n.calibration): \(Int(baselineProgress.percentage * 100))%")
                                .font(KlunaFont.caption(11))
                                .foregroundColor(.klunaAccent)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((baselineProgress.isEstablished ? Color.klunaGold : Color.klunaAccent).opacity(0.08))
                    .cornerRadius(KlunaRadius.pill)
                }

                if sessionCount >= 10, let consistency = viewModel.currentConsistency {
                    ConsistencyBadge(consistency: consistency)
                }

                if sessionCount >= 2, let previous = viewModel.previousScores, let current = viewModel.currentScores {
                    ScoreDeltaBadge(delta: current.overall - previous.overall)
                    ImprovementBanner(delta: current.overall - previous.overall)
                } else if let current = viewModel.currentScores, memoryManager.totalSessionCount() <= 1 {
                    Text(scoreLabel(for: current.overall))
                        .font(KlunaFont.caption(14))
                        .foregroundColor(.klunaMuted)
                        .padding(.top, KlunaSpacing.xs)
                }

                if sessionCount >= 10, let completion = viewModel.goalCompletion {
                    GoalCompletedBanner(
                        result: completion,
                        language: userLanguage,
                        onNextGoal: { viewModel.goalCompletion = nil }
                    )
                    .padding(.horizontal, KlunaSpacing.md)
                }

                if sessionCount >= 10, let goal = viewModel.activeGoal, let scores = viewModel.currentScores {
                    DimensionGoalCard(
                        goal: goal,
                        currentScore: scores.value(for: goal.dimension),
                        progress: viewModel.goalProgress ?? 0,
                        language: userLanguage
                    )
                    .padding(.horizontal, KlunaSpacing.md)
                }

                if sessionCount >= 3,
                   let classification = viewModel.profileClassification,
                   let scores = viewModel.currentScores {
                    ProfileBadgeView(
                        classification: classification,
                        overallScore: Int(scores.overall.rounded())
                    )
                }

                if sessionCount >= 8, let melodicAnalysis = viewModel.melodicAnalysis {
                    MelodicInsightsCard(analysis: melodicAnalysis)
                }

                if sessionCount >= 6, let spectral = viewModel.spectralAnalysis {
                    SpectralInsightsCard(result: spectral)
                }

                if sessionCount >= 2, let scores = viewModel.currentScores {
                    DimensionBarsView(scores: scores)
                        .padding(.horizontal, KlunaSpacing.md)
                }

                QuickFeedbackCard(feedback: viewModel.quickFeedback.isEmpty ? nil : viewModel.quickFeedback)
                    .padding(.horizontal, KlunaSpacing.md)

                if sessionCount >= 10 {
                if let challengeResult = viewModel.challengeResult, !challengeResult.passed {
                    HStack(spacing: KlunaSpacing.sm) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .foregroundColor(.klunaAmber)
                        Text(userLanguage == "de" ? "Challenge nicht geschafft. Versuch's nochmal." : "Challenge not passed. Try again.")
                            .font(KlunaFont.body(13))
                            .foregroundColor(.klunaSecondary)
                    }
                    .padding(KlunaSpacing.md)
                    .background(Color.klunaAmber.opacity(0.08))
                    .cornerRadius(KlunaRadius.card)
                    .padding(.horizontal, KlunaSpacing.md)
                }

                if viewModel.isDrill,
                   let preDrill = viewModel.preDrillScore,
                   let dim = viewModel.preDrillDimension,
                   let postDrill = viewModel.currentScores?.value(for: dim) {
                    DrillResultBanner(
                        dimension: dim,
                        before: preDrill,
                        after: postDrill,
                        language: userLanguage
                    )
                    .padding(.horizontal, KlunaSpacing.md)
                }

                if !viewModel.isDrill, let scores = viewModel.currentScores {
                    let provider = MicroDrillProvider.shared
                    let weakDim = provider.weakestDimension(from: scores)
                    let weakScore = scores.value(for: weakDim)
                    if weakScore < 55 {
                        let drill = provider.drillForWeakness(weakDim)
                        ZStack {
                            MicroDrillSuggestion(
                                drill: drill,
                                weakScore: weakScore,
                                language: userLanguage,
                                onStart: {
                                    viewModel.startDrill(weakDimension: weakDim, currentWeakScore: weakScore)
                                    viewModel.selectedPitchType = PitchType(
                                        id: UUID(),
                                        name: drill.title(language: userLanguage),
                                        description: "Drill",
                                        timeLimit: drill.timeLimit,
                                        challengePrompt: drill.instruction(language: userLanguage),
                                        isCustom: true,
                                        isDefault: false
                                    )
                                    viewModel.resetForNewSession()
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        viewModel.startRecording()
                                    }
                                }
                            )
                            .blur(radius: subscriptionManager.hasAccess(to: .microDrills) ? 0 : 4)

                            if !subscriptionManager.hasAccess(to: .microDrills) {
                                ProLockedOverlay(feature: .microDrills, language: userLanguage, onTap: {
                                    paywallTrigger = .general
                                    showPaywall = true
                                })
                            }
                        }
                        .padding(.horizontal, KlunaSpacing.md)
                    }

                    if viewModel.activeBiomarkerChallenge == nil {
                        let challenge = BiomarkerChallengeProvider.shared.challengeForWeakness(weakDim)
                        BiomarkerChallengeCard(
                            challenge: challenge,
                            language: userLanguage,
                            onStart: {
                                viewModel.startBiomarkerChallenge(for: weakDim, language: userLanguage)
                                viewModel.resetForNewSession()
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    viewModel.startRecording()
                                }
                            }
                        )
                        .padding(.horizontal, KlunaSpacing.md)
                    }
                }

                if let result = viewModel.biomarkerResult {
                    BiomarkerResultBanner(result: result, language: userLanguage)
                        .padding(.horizontal, KlunaSpacing.md)
                }

                if let heatmap = viewModel.heatmapData, !heatmap.segments.isEmpty {
                    if subscriptionManager.hasAccess(to: .audioPlayback) {
                        if coachModeActive && !viewModel.timestampedComments.isEmpty {
                            CoachPlaybackView(
                                comments: viewModel.timestampedComments,
                                segments: heatmap.segments,
                                duration: max(viewModel.recordingDuration, 0),
                                playbackProgress: $viewModel.playbackProgress,
                                isPlaying: viewModel.isPlayingBack,
                                onTogglePlayback: { viewModel.togglePlayback() },
                                language: userLanguage
                            )
                            .padding(.horizontal, KlunaSpacing.md)
                        } else {
                            PlaybackHeatmapView(
                                segments: heatmap.segments,
                                duration: max(viewModel.recordingDuration, 0),
                                playbackProgress: $viewModel.playbackProgress,
                                isPlaying: viewModel.isPlayingBack,
                                onTogglePlayback: { viewModel.togglePlayback() }
                            )
                            .padding(.horizontal, KlunaSpacing.md)
                        }
                    } else {
                        ZStack {
                            PlaybackHeatmapView(
                                segments: heatmap.segments,
                                duration: max(viewModel.recordingDuration, 0),
                                playbackProgress: $viewModel.playbackProgress,
                                isPlaying: false,
                                onTogglePlayback: {}
                            )
                            .blur(radius: 4)

                            ProLockedOverlay(feature: .audioPlayback, language: userLanguage, onTap: {
                                paywallTrigger = .playbackLocked
                                showPaywall = true
                            })
                        }
                        .padding(.horizontal, KlunaSpacing.md)
                    }

                    if !viewModel.timestampedComments.isEmpty {
                        Button(action: {
                            if subscriptionManager.hasAccess(to: .coachMode) {
                                coachModeActive.toggle()
                            } else {
                                paywallTrigger = .coachModeLocked
                                showPaywall = true
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: coachModeActive ? "person.fill.checkmark" : "person.fill")
                                    .font(.system(size: 12))
                                Text(coachModeActive
                                     ? (userLanguage == "de" ? "Coach-Modus an" : "Coach mode on")
                                     : (userLanguage == "de" ? "Coach-Modus" : "Coach mode"))
                                    .font(KlunaFont.caption(12))
                            }
                            .foregroundColor(coachModeActive ? .klunaAccent : .klunaMuted)
                            .padding(.horizontal, KlunaSpacing.md)
                            .padding(.vertical, KlunaSpacing.xs)
                            .background(coachModeActive ? Color.klunaAccent.opacity(0.1) : Color.clear)
                            .cornerRadius(KlunaRadius.pill)
                        }
                    }
                }

                if !viewModel.transcription.isEmpty {
                    TranscriptionCard(text: viewModel.transcription)
                        .padding(.horizontal, KlunaSpacing.md)
                }

                if subscriptionManager.hasDeepCoaching {
                    Button {
                        showDeepCoachingSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "brain.head.profile")
                            Text(L10n.deepCoaching)
                            if viewModel.isLoadingDeepCoaching {
                                ProgressView()
                                    .tint(.klunaAccent)
                                    .scaleEffect(0.8)
                            }
                        }
                        .foregroundColor(.klunaAccent)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.klunaAccent, lineWidth: 1))
                    }
                    .disabled(viewModel.isLoadingDeepCoaching)
                    .padding(.horizontal, KlunaSpacing.md)
                }
                }

                ScoreActionButtons(
                    attemptCount: viewModel.attemptCount,
                    onAgain: {
                        viewModel.stopPlayback()
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.resetForNewSession()
                            viewModel.startRecording()
                        }
                    },
                    onDone: {
                        viewModel.stopPlayback()
                        viewModel.attemptCount = 1
                        viewModel.isDrill = false
                        viewModel.preDrillScore = nil
                        viewModel.preDrillDimension = nil
                        dismiss()
                    }
                )
                .padding(.horizontal, KlunaSpacing.md)

                Spacer(minLength: KlunaSpacing.xl)
            }
        }
        .background(Color.klunaBackground.ignoresSafeArea())
        .sheet(isPresented: $showDeepCoachingSheet) {
            DeepCoachingView(coaching: viewModel.deepCoaching)
                .onAppear {
                    if (viewModel.deepCoaching ?? "").isEmpty && !viewModel.isLoadingDeepCoaching {
                        Task { await viewModel.requestDeepCoaching(transcription: viewModel.transcription) }
                    }
                }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: paywallTrigger, language: userLanguage, subscriptionManager: subscriptionManager)
        }
        .sheet(isPresented: $showDimensionInfo) {
            if let dim = selectedDimensionInfo,
               let explanation = dimensionExplanations.first(where: { $0.dimension == dim }),
               let scores = viewModel.currentScores {
                NavigationView {
                    DimensionDetailSheet(
                        explanation: explanation,
                        currentScore: scores.value(for: dim),
                        bestScore: memoryManager.personalBestScores()?.value(for: dim),
                        language: userLanguage
                    )
                    .navigationTitle(dim.shortName(language: userLanguage))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(L10n.done) { showDimensionInfo = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .fullScreenCover(isPresented: $viewModel.showLevelUp) {
            if let result = viewModel.challengeResult {
                LevelUpView(
                    result: result,
                    language: userLanguage,
                    onContinue: {
                        viewModel.showLevelUp = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.showBaselineEstablishedCelebration) {
            BaselineEstablishedView(language: userLanguage) {
                viewModel.showBaselineEstablishedCelebration = false
            }
        }
        .onAppear {
            let newUnlocks = FeatureUnlockManager.shared.checkUnlocks(sessionCount: sessionCount)
            if let firstUnlock = newUnlocks.first {
                unlockMessage = "🔓 \(firstUnlock.message)"
                withAnimation(.spring().delay(0.8)) {
                    showUnlockToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation { showUnlockToast = false }
                }
            }
            if !subscriptionManager.isProUser,
               let score = viewModel.currentScores?.overall,
               score > 65 {
                showSoftUpsell = true
            }
        }
        .overlay(alignment: .top) {
            if showUnlockToast, let unlockMessage {
                UnlockToastView(message: unlockMessage)
                    .padding(.horizontal, KlunaSpacing.md)
                    .padding(.top, KlunaSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let toast = viewModel.pendingBaselineToast {
                HStack(spacing: KlunaSpacing.sm) {
                    Image(systemName: toast.icon)
                        .foregroundColor(toast.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.title)
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaPrimary)
                        Text(toast.subtitle)
                            .font(KlunaFont.caption(11))
                            .foregroundColor(.klunaMuted)
                    }
                    Spacer()
                }
                .padding(KlunaSpacing.md)
                .background(Color.klunaSurface)
                .cornerRadius(KlunaRadius.card)
                .padding(.horizontal, KlunaSpacing.md)
                .padding(.top, KlunaSpacing.md)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        viewModel.pendingBaselineToast = nil
                    }
                }
            } else if showSoftUpsell {
                Button(action: {
                    paywallTrigger = .highScoreMoment
                    showPaywall = true
                    showSoftUpsell = false
                }) {
                    HStack {
                        Text(userLanguage == "de" ? "Du wirst besser! Mehr Fortschritt mit Pro" : "You're getting better! More progress with Pro")
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaAccent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.klunaAccent)
                    }
                    .padding(KlunaSpacing.sm)
                    .background(Color.klunaAccent.opacity(0.08))
                    .cornerRadius(KlunaRadius.button)
                    .padding(.horizontal, KlunaSpacing.md)
                    .padding(.top, KlunaSpacing.md)
                }
            }
        }
    }

    private func scoreLabel(for score: Double) -> String {
        switch score {
        case 80...100: return L10n.excellent
        case 65..<80: return L10n.strong
        case 50..<65: return L10n.solid
        case 35..<50: return L10n.developing
        default: return L10n.starting
        }
    }

    private func visibleDimensions(for scores: DimensionScores) -> [PerformanceDimension] {
        let totalSessions = memoryManager.totalSessionCount()
        return Self.computeVisibleDimensions(
            scores: scores,
            totalSessions: totalSessions,
            hasDimensionAccess: true
        )
    }

    static func computeVisibleDimensions(
        scores: DimensionScores,
        totalSessions: Int,
        hasDimensionAccess: Bool
    ) -> [PerformanceDimension] {
        let allDimensions = PerformanceDimension.activeDimensions
        if !hasDimensionAccess { return [] }
        if totalSessions <= 5 {
            let sorted = allDimensions.sorted { scores.score(for: $0) < scores.score(for: $1) }
            let weakest2 = Array(sorted.prefix(2))
            let strongest1 = sorted.last.map { [$0] } ?? []
            return Array(Set(weakest2 + strongest1)).sorted { $0.rawValue < $1.rawValue }
        }
        return allDimensions
    }
}

struct DimensionBarsView: View {
    let scores: DimensionScores

    var body: some View {
        VStack(spacing: 8) {
            DimensionBar(label: "🎯 Confidence", value: scores.confidence)
            DimensionBar(label: "⚡ Energy", value: scores.energy)
            DimensionBar(label: "🎵 Tempo", value: scores.tempo)
            DimensionBar(label: "😌 Gelassenheit", value: scores.stability)
            DimensionBar(label: "✨ Charisma", value: scores.charisma)
        }
        .padding(KlunaSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .fill(Color.klunaSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: KlunaRadius.card)
                        .stroke(Color.klunaBorder, lineWidth: 1)
                )
        )
    }
}

private struct DimensionBar: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(KlunaFont.caption(12))
                .foregroundColor(.klunaMuted)
                .frame(width: 122, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.klunaSurfaceLight)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(1, value / 100))
                }
            }
            .frame(height: 6)
        }
    }

    private var barColor: Color {
        if value >= 70 { return .klunaGreen.opacity(0.7) }
        if value >= 45 { return .klunaAmber.opacity(0.7) }
        return .klunaOrange.opacity(0.7)
    }
}

struct UnlockToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(KlunaFont.body(13))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.klunaAccent.opacity(0.95))
                    .shadow(color: Color.klunaAccent.opacity(0.35), radius: 10, y: 4)
            )
    }
}

struct DimensionScoreRow: View {
    let dimension: PerformanceDimension
    let score: Double
    let previousScore: Double?
    let language: String

    var body: some View {
        VStack(spacing: KlunaSpacing.xs) {
            HStack {
                Text(dimension.shortName(language: language))
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaSecondary)
                Spacer()
                if let prev = previousScore {
                    let delta = score - prev
                    if abs(delta) > 1 {
                        Text(String(format: "%+.0f", delta))
                            .font(KlunaFont.caption(12))
                            .foregroundColor(delta > 0 ? .klunaGreen : .klunaRed)
                    }
                }
                Text("\(Int(score.rounded()))")
                    .font(KlunaFont.scoreDisplay(18))
                    .foregroundColor(.forScore(score))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.klunaSurfaceLight)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.forScore(score))
                        .frame(width: geo.size.width * CGFloat(max(0, min(1, score / 100))), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, KlunaSpacing.xs)
        .contentShape(Rectangle())
    }
}

struct TranscriptionCard: View {
    let text: String

    var body: some View {
        DisclosureGroup {
            Text(text)
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaSecondary)
                .lineSpacing(4)
        } label: {
            HStack {
                Image(systemName: "text.quote")
                    .foregroundColor(.klunaMuted)
                Text(L10n.whatYouSaid)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaMuted)
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

struct ScoreActionButtons: View {
    let attemptCount: Int
    let onAgain: () -> Void
    let onDone: () -> Void
    @State private var visible = false

    var body: some View {
        VStack(spacing: KlunaSpacing.xs) {
            HStack(spacing: KlunaSpacing.md) {
                Button(action: {
                    SoundManager.againHaptic()
                    onAgain()
                }) {
                    VStack(spacing: KlunaSpacing.xs) {
                        HStack(spacing: KlunaSpacing.sm) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .semibold))
                            Text(L10n.again)
                                .font(KlunaFont.heading(17))
                        }
                        Text(L10n.beatYourScore)
                            .font(KlunaFont.caption(11))
                            .opacity(0.7)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KlunaSpacing.md)
                    .background(Color.klunaAccent)
                    .cornerRadius(KlunaRadius.button)
                }

                Button(action: onDone) {
                    Text(L10n.done)
                        .font(KlunaFont.heading(15))
                        .foregroundColor(.klunaSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KlunaSpacing.md)
                        .background(Color.klunaSurface)
                        .cornerRadius(KlunaRadius.button)
                        .overlay(
                            RoundedRectangle(cornerRadius: KlunaRadius.button)
                                .stroke(Color.klunaBorder, lineWidth: 1)
                        )
                }
                .frame(width: 100)
            }

            if attemptCount > 1 {
                Text("\(L10n.attempt) \(attemptCount)")
                    .font(KlunaFont.caption(11))
                    .foregroundColor(.klunaMuted)
            }
        }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 20)
        .onAppear {
            withAnimation(KlunaAnimation.spring.delay(2.2)) {
                visible = true
            }
        }
    }
}

struct ImprovementBanner: View {
    let delta: Double
    @State private var visible = false

    private var isPositive: Bool { delta > 0 }
    private var message: String {
        if delta > 5 { return L10n.greatImprovement }
        if delta > 0 { return L10n.gettingBetter }
        if delta < -5 { return L10n.tryAgainTip }
        return L10n.keepGoing
    }

    var body: some View {
        HStack(spacing: KlunaSpacing.sm) {
            Image(systemName: isPositive ? "arrow.up.circle.fill" : "arrow.right.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(isPositive ? .klunaGreen : .klunaAmber)
            VStack(alignment: .leading, spacing: 2) {
                if isPositive {
                    Text("+\(Int(delta.rounded())) Punkte")
                        .font(KlunaFont.scoreDisplay(16))
                        .foregroundColor(.klunaGreen)
                }
                Text(message)
                    .font(KlunaFont.body(13))
                    .foregroundColor(.klunaSecondary)
            }
            Spacer()
        }
        .padding(KlunaSpacing.md)
        .background((isPositive ? Color.klunaGreen : Color.klunaAmber).opacity(0.08))
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke((isPositive ? Color.klunaGreen : Color.klunaAmber).opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, KlunaSpacing.md)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 15)
        .onAppear {
            withAnimation(KlunaAnimation.spring.delay(0.4)) {
                visible = true
            }
        }
    }
}

struct PlaybackHeatmapView: View {
    let segments: [HeatmapSegment]
    let duration: TimeInterval
    @Binding var playbackProgress: Double
    let isPlaying: Bool
    let onTogglePlayback: () -> Void

    var body: some View {
        VStack(spacing: KlunaSpacing.sm) {
            HStack {
                Text(L10n.yourRecording)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaMuted)
                Spacer()
                Text(formatTime(playbackProgress * duration))
                    .font(KlunaFont.scoreLight(14))
                    .foregroundColor(.klunaSecondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 3) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.forScore(segment.scores.overall))
                                    .opacity(opacityForSegment(index))
                                VStack(spacing: 2) {
                                    Text("\(Int(segment.scores.overall.rounded()))")
                                        .font(KlunaFont.scoreDisplay(18))
                                        .foregroundColor(.white)
                                    Text(segmentLabel(index))
                                        .font(KlunaFont.caption(9))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                    if isPlaying || playbackProgress > 0 {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 50)
                            .shadow(color: .white.opacity(0.5), radius: 4)
                            .offset(x: max(0, min(geo.size.width - 2, geo.size.width * playbackProgress)))
                            .animation(.linear(duration: 1.0 / 30.0), value: playbackProgress)
                    }
                }
            }
            .frame(height: 56)

            Button(action: onTogglePlayback) {
                HStack(spacing: KlunaSpacing.sm) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.klunaAccent)
                    if isPlaying {
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                WaveformBar(index: i, isAnimating: isPlaying)
                            }
                        }
                        .frame(height: 16)
                    } else {
                        Text(L10n.listenToYourself)
                            .font(KlunaFont.caption(13))
                            .foregroundColor(.klunaSecondary)
                    }
                    Spacer()
                    Text(formatTime(duration))
                        .font(KlunaFont.caption(12))
                        .foregroundColor(.klunaMuted)
                        .monospacedDigit()
                }
                .padding(.horizontal, KlunaSpacing.md)
                .padding(.vertical, KlunaSpacing.sm)
                .background(Color.klunaSurfaceLight)
                .cornerRadius(KlunaRadius.button)
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

    private func opacityForSegment(_ index: Int) -> Double {
        guard isPlaying else { return 1.0 }
        let segmentProgress = Double(index) / Double(segments.count)
        let nextSegmentProgress = Double(index + 1) / Double(segments.count)
        let isCurrent = playbackProgress >= segmentProgress && playbackProgress < nextSegmentProgress
        return isCurrent ? 1.0 : 0.5
    }

    private func segmentLabel(_ index: Int) -> String {
        switch index {
        case 0: return L10n.start
        case 1: return L10n.middle
        default: return L10n.end
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WaveformBar: View {
    let index: Int
    let isAnimating: Bool
    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.klunaAccent)
            .frame(width: 3, height: height)
            .onAppear {
                guard isAnimating else { return }
                withAnimation(.easeInOut(duration: 0.4 + Double(index) * 0.1).repeatForever(autoreverses: true)) {
                    height = CGFloat.random(in: 6...16)
                }
            }
    }
}

