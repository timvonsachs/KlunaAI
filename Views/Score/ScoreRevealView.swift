import SwiftUI

struct ScoreRevealView: View {
    let scores: DimensionScores
    let prediction: ScorePrediction?
    let vocalState: VocalStateResult
    let coachingText: String
    let transcription: String
    let transcriptionSource: TranscriptionManager.TranscriptionSource
    let nextExercise: TrainingExercise
    let xpGain: XPGain
    let levelInfo: LevelInfo
    let leveledUp: Bool
    let voiceDNA: VoiceDNAProfile?
    let voiceInsight: VoiceInsight?
    let isDiscoveryComplete: Bool
    let discoverySessionCount: Int
    let onSelectQuadrant: () -> Void

    @State private var phase = 0

    var body: some View {
        ZStack {
            NoiseBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    if phase >= 1 {
                        if let prediction {
                            PredictionRevealView(prediction: prediction, actualScore: scores.overall)
                                .transition(.opacity)
                        } else {
                            PremiumScoreNumber(score: scores.overall)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    if phase >= 3 {
                        PremiumDimensionBars(scores: scores)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if phase >= 4 {
                        VocalStateBadge(state: vocalState)
                            .transition(.opacity.combined(with: .scale))
                    }

                    if phase >= 5 {
                        PremiumCoachingCard(text: coachingText)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if phase >= 6 {
                        VStack(spacing: 16) {
                            PremiumXPGain(xpGain: xpGain, levelInfo: levelInfo, leveledUp: leveledUp)
                            if let voiceDNA {
                                if !isDiscoveryComplete, let voiceInsight {
                                    InsightCardView(
                                        insight: voiceInsight,
                                        remaining: max(0, 7 - discoverySessionCount)
                                    )
                                } else if voiceInsight?.sessionNumber == 7 {
                                    ProfileRevealView(profile: voiceDNA, onSelectQuadrant: onSelectQuadrant)
                                } else {
                                    VoiceDNARadarView(profile: voiceDNA)
                                }
                            }
                            if !transcription.isEmpty {
                                RevealTranscriptionCard(text: transcription, source: transcriptionSource)
                            }
                            NextExerciseCard(exercise: nextExercise)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
            }

            if leveledUp && phase >= 6 {
                LevelUpOverlay(level: levelInfo)
            }
        }
        .onAppear(perform: startRevealSequence)
    }

    private func startRevealSequence() {
        FeedbackEngine.shared.scoreReveal(score: scores.overall)
        withAnimation(KlunaAnimation.spring) { phase = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation(KlunaAnimation.spring) { phase = 3 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { withAnimation(KlunaAnimation.springFast) { phase = 4 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) { withAnimation(KlunaAnimation.spring) { phase = 5 } }
        if let prediction, scores.overall - prediction.expectedScore > 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { FeedbackEngine.shared.positiveSurprise() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            withAnimation(KlunaAnimation.spring) { phase = 6 }
            FeedbackEngine.shared.xpGain()
        }
    }
}

struct PremiumScoreNumber: View {
    let score: Double
    @State private var animatedScore: Double = 0
    @State private var showGlow = false

    var body: some View {
        ZStack {
            Circle()
                .fill(KlunaColors.scoreColor(score).opacity(showGlow ? 0.12 : 0))
                .frame(width: 200, height: 200)
                .blur(radius: 60)

            Text("\(Int(animatedScore))")
                .font(KlunaFonts.score(88))
                .foregroundStyle(KlunaColors.scoreGradient(score))
                .contentTransition(.numericText())
                .shadow(color: KlunaColors.scoreColor(score).opacity(0.3), radius: 20, y: 0)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) { animatedScore = score }
            withAnimation(.easeIn(duration: 0.8).delay(0.4)) { showGlow = true }
        }
    }
}

struct PremiumDimensionBars: View {
    let scores: DimensionScores
    @State private var animateBar: [Bool] = Array(repeating: false, count: 5)

    private let dimensions: [(key: String, label: String, icon: String)] = [
        ("confidence", "Confidence", "🎯"),
        ("energy", "Energy", "⚡"),
        ("tempo", "Tempo", "🎵"),
        ("stability", "Gelassenheit", "😌"),
        ("charisma", "Charisma", "✨")
    ]

    var body: some View {
        KlunaCard {
            VStack(spacing: 12) {
            ForEach(Array(dimensions.enumerated()), id: \.element.key) { index, dim in
                let value = scoreForDimension(dim.key)
                let isWeakest = index == weakestIndex
                HStack(spacing: 10) {
                    Text(dim.icon).font(.system(size: 13)).frame(width: 20)
                    Text(dim.label)
                        .font(KlunaFonts.label(13))
                        .foregroundColor(isWeakest ? KlunaColors.tense.opacity(0.9) : KlunaColors.textSecondary)
                        .frame(width: 94, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barGradient(value: value, isWeakest: isWeakest))
                                .frame(width: animateBar[index] ? geo.size.width * min(1, value / 100) : 0)
                                .shadow(color: barShadowColor(value: value, isWeakest: isWeakest), radius: 6, x: 0, y: 0)
                        }
                    }
                    .frame(height: 8)
                    Text("\(Int(value))")
                        .font(KlunaFonts.score(14))
                        .foregroundColor(isWeakest ? KlunaColors.tense : KlunaColors.textPrimary.opacity(0.8))
                        .frame(width: 28, alignment: .trailing)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.12)) {
                        animateBar[index] = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.12) {
                        FeedbackEngine.shared.barFill()
                    }
                }
            }
        }
        }
    }

    private var weakestIndex: Int {
        let values = dimensions.map { scoreForDimension($0.key) }
        return values.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }

    private func scoreForDimension(_ key: String) -> Double {
        switch key {
        case "confidence": return scores.confidence
        case "energy": return scores.energy
        case "tempo": return scores.tempo
        case "stability": return scores.stability
        case "charisma": return scores.charisma
        default: return 0
        }
    }

    private func barGradient(value: Double, isWeakest: Bool) -> LinearGradient {
        if isWeakest {
            return LinearGradient(colors: [Color(hex: "F97316"), Color(hex: "EF4444")], startPoint: .leading, endPoint: .trailing)
        }
        if value >= 75 {
            return LinearGradient(colors: [KlunaColors.accent, KlunaColors.accentCyan], startPoint: .leading, endPoint: .trailing)
        }
        if value >= 55 {
            return LinearGradient(colors: [Color(hex: "22D97F"), Color(hex: "10B981")], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [Color(hex: "EAB308"), Color(hex: "F59E0B")], startPoint: .leading, endPoint: .trailing)
    }

    private func barShadowColor(value: Double, isWeakest: Bool) -> Color {
        if isWeakest { return KlunaColors.tense.opacity(0.25) }
        if value >= 75 { return KlunaColors.accent.opacity(0.20) }
        return .clear
    }
}

struct VocalStateBadge: View {
    let state: VocalStateResult

    var body: some View {
        HStack(spacing: 8) {
            Text(state.primaryState.icon).font(.system(size: 16))
            Text(displayStateName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.klunaPrimary)
            if state.confidence < 0.5, let secondary = state.secondaryState {
                Text("/ \(displayName(for: secondary))")
                    .font(.system(size: 12))
                    .foregroundColor(.klunaMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(stateColor.opacity(0.12)))
        .overlay(Capsule().stroke(stateColor.opacity(0.25), lineWidth: 1))
    }

    private var stateColor: Color {
        switch state.primaryState {
        case .energized: return .stateEnergized
        case .focused: return .stateFocused
        case .tense: return .stateTense
        case .tired: return .stateTired
        case .relaxed: return .stateRelaxed
        }
    }

    private var displayStateName: String {
        displayName(for: state.primaryState)
    }

    private func displayName(for state: VocalState) -> String {
        switch state {
        case .energized: return "Energetisch"
        case .focused: return "Fokussiert"
        case .tense: return "Angespannt"
        case .tired: return "Müde"
        case .relaxed: return "Entspannt"
        }
    }
}

struct PremiumCoachingCard: View {
    let text: String
    @State private var appear = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KlunaColors.accentGradient)
                Text("KLUNA COACH")
                    .font(KlunaFonts.upperLabel(10))
                    .foregroundColor(KlunaColors.textMuted)
                    .tracking(1.5)
            }
            Text(text)
                .font(KlunaFonts.body(15))
                .foregroundColor(KlunaColors.textPrimary.opacity(0.85))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(KlunaColors.accentCyan.opacity(0.04))
                VStack {
                    Spacer()
                    HStack {
                        KlunaColors.accentCyan.opacity(0.06)
                            .frame(width: 120, height: 60)
                            .blur(radius: 40)
                        Spacer()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [KlunaColors.accentCyan.opacity(0.15), KlunaColors.accentCyan.opacity(0.05), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appear = true }
        }
    }
}

struct PremiumXPGain: View {
    let xpGain: XPGain
    let levelInfo: LevelInfo
    let leveledUp: Bool
    @State private var displayedXP: Int = 0
    @State private var showBreakdown = false
    @State private var progressWidth: CGFloat = 0

    var body: some View {
        KlunaCard {
            VStack(spacing: 12) {
            HStack {
                Text("+\(displayedXP) XP")
                    .font(KlunaFonts.score(24))
                    .foregroundStyle(KlunaColors.accentGradient)
                    .contentTransition(.numericText())
                Spacer()
                Button(action: { withAnimation(KlunaAnimation.spring) { showBreakdown.toggle() } }) {
                    Image(systemName: showBreakdown ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KlunaColors.textMuted)
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.04)))
                }
            }
            if showBreakdown {
                VStack(spacing: 6) {
                    ForEach(xpGain.breakdown, id: \.label) { item in
                        HStack {
                            Text(item.label)
                                .font(KlunaFonts.body(13))
                                .foregroundColor(KlunaColors.textSecondary)
                            Spacer()
                            Text("+\(item.amount)")
                                .font(KlunaFonts.label(13))
                                .foregroundColor(KlunaColors.textPrimary.opacity(0.7))
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KlunaColors.accentGradient)
                            .frame(width: progressWidth)
                            .shadow(color: KlunaColors.accent.opacity(0.3), radius: 8, x: 0, y: 0)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                        progressWidth = geo.size.width * levelInfo.progress
                                    }
                                }
                            }
                    }
                }
                .frame(height: 6)
                HStack {
                    Text("Level \(levelInfo.level) · \(levelInfo.title)")
                        .font(KlunaFonts.label(11))
                        .foregroundColor(KlunaColors.textMuted)
                    Spacer()
                    Text("\(levelInfo.currentXP)/\(levelInfo.xpForNextLevel)")
                        .font(KlunaFonts.label(11))
                        .foregroundColor(KlunaColors.textMuted)
                }
            }
        }
        }
        .onAppear {
            let duration = 0.8
            let steps = 20
            let stepDuration = duration / Double(steps)
            let increment = max(1, xpGain.totalXP / steps)
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                    displayedXP = min(xpGain.totalXP, increment * i)
                    if i % 5 == 0 {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.3)
                    }
                }
            }
        }
    }
}

struct NextExerciseCard: View {
    let exercise: TrainingExercise
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.stateFocused.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: "figure.wave")
                    .font(.system(size: 16))
                    .foregroundColor(.stateFocused)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("NÄCHSTE ÜBUNG")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.klunaMuted)
                    .tracking(1.2)
                Text(exercise.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.klunaPrimary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.klunaMuted)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.stateFocused.opacity(0.12), lineWidth: 1))
    }
}

struct RevealTranscriptionCard: View {
    let text: String
    let source: TranscriptionManager.TranscriptionSource
    @State private var expanded = false

    var body: some View {
        KlunaCard {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: { withAnimation(.spring()) { expanded.toggle() } }) {
                    HStack {
                        Image(systemName: "text.quote")
                            .font(.system(size: 12))
                            .foregroundColor(KlunaColors.textMuted)
                        Text("TRANSKRIPTION")
                            .font(KlunaFonts.upperLabel(10))
                            .foregroundColor(KlunaColors.textMuted)
                            .tracking(1.2)
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                            .foregroundColor(KlunaColors.textMuted)
                    }
                }
                .buttonStyle(.plain)

                if expanded {
                    Text(text)
                        .font(KlunaFonts.body(14))
                        .foregroundColor(KlunaColors.textSecondary)
                        .lineSpacing(4)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    HStack(spacing: 4) {
                        Circle()
                            .fill(source == .whisper ? KlunaColors.accent : KlunaColors.tense)
                            .frame(width: 5, height: 5)
                        Text(source == .whisper ? "Whisper AI" : "On-Device")
                            .font(KlunaFonts.label(9))
                            .foregroundColor(KlunaColors.textGhost)
                    }
                }
            }
        }
    }
}

struct LevelUpOverlay: View {
    let level: LevelInfo
    @State private var show = false
    @State private var dismissed = false

    var body: some View {
        if !dismissed {
            ZStack {
                Color.black.opacity(show ? 0.7 : 0).ignoresSafeArea().onTapGesture {
                    withAnimation(KlunaAnimation.spring) { dismissed = true }
                }
                VStack(spacing: 16) {
                    Text("LEVEL UP")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.stateEnergized)
                        .tracking(3)
                    Text("\(level.level)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Color.stateEnergized, Color.stateRelaxed], startPoint: .top, endPoint: .bottom))
                    Text(level.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.klunaPrimary)
                    Text(level.tierName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.klunaSecondary)
                }
                .scaleEffect(show ? 1 : 0.5)
                .opacity(show ? 1 : 0)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { show = true }
                FeedbackEngine.shared.levelUp()
            }
        }
    }
}

struct ScoreRevealContainerView: View {
    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var xpResult: XPGain?
    @State private var levelInfo: LevelInfo = LevelEngine.shared.getCurrentLevel()
    @State private var leveledUp = false
    @State private var showQuadrantSelection = false

    var body: some View {
        Group {
            if let scores = viewModel.currentScores,
               let vocalState = viewModel.vocalState,
               let nextExercise = viewModel.suggestedExercise,
               let xpResult {
                VStack(spacing: 0) {
                    ScoreRevealView(
                        scores: scores,
                        prediction: viewModel.currentPrediction,
                        vocalState: vocalState,
                        coachingText: viewModel.quickFeedback,
                        transcription: viewModel.transcription,
                        transcriptionSource: viewModel.transcriptionSource,
                        nextExercise: nextExercise,
                        xpGain: xpResult,
                        levelInfo: levelInfo,
                        leveledUp: leveledUp,
                        voiceDNA: viewModel.voiceDNAProfile,
                        voiceInsight: viewModel.voiceDNAInsight,
                        isDiscoveryComplete: viewModel.isVoiceDNADiscoveryComplete,
                        discoverySessionCount: viewModel.voiceDNADiscoverySessionCount,
                        onSelectQuadrant: { showQuadrantSelection = true }
                    )
                    Button("Fertig") {
                        viewModel.stopPlayback()
                        viewModel.attemptCount = 1
                        viewModel.resetForNewSession()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.klunaSecondary)
                    .padding(.vertical, 10)
                }
            } else {
                ScoreView(viewModel: viewModel)
            }
        }
        .onAppear(perform: prepareXP)
        .sheet(isPresented: $showQuadrantSelection) {
            if let profile = viewModel.voiceDNAProfile {
                QuadrantSelectionView(profile: profile) { selected in
                    viewModel.selectVoiceDNAQuadrant(selected)
                    showQuadrantSelection = false
                }
            } else {
                EmptyView()
            }
        }
    }

    private func prepareXP() {
        guard let scores = viewModel.currentScores else { return }
        let gain = LevelEngine.shared.calculateXPGain(
            sessionScore: scores.overall,
            streakDays: viewModel.currentConsistency?.currentStreak ?? 0,
            predictionDelta: viewModel.currentPredictionError?.delta,
            completedExercise: viewModel.isDrill,
            newMilestones: viewModel.latestMilestones.count
        )
        let levelResult = LevelEngine.shared.addXP(gain.totalXP)
        xpResult = gain
        levelInfo = levelResult.newLevel
        leveledUp = levelResult.leveledUp
    }
}
