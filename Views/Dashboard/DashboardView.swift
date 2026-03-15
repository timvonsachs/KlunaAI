import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @AppStorage("main.selectedTab") private var selectedTab = 0
    private let memoryManager = MemoryManager(context: PersistenceController.shared.container.viewContext)
    private let journalManager = JournalManager(context: PersistenceController.shared.container.viewContext)
    @StateObject private var journalViewModel = JournalViewModel()

    @State private var totalSessions = 0
    @State private var weekAverage: Double = 0
    @State private var weekDelta: Double?
    @State private var heroSubtitle = ""
    @State private var bestScore: Double = 0
    @State private var streakWeeks = 0
    @State private var scoreHistory: [DailyScoreSummary] = []
    @State private var recentSessions: [SessionSummary] = []
    @State private var sparklineScores: [Double] = []
    @State private var sparklineLabels: [String] = []
    @State private var reportExpanded = false
    @State private var userLanguage = "de"
    @State private var showJournal = false
    @State private var showPaywall = false
    @State private var paywallTrigger: PaywallTrigger = .general
    @State private var scorePrediction: ScorePrediction?
    @State private var lastScore: Double?
    @State private var consistency: ConsistencyResult?
    
    var body: some View {
            ScrollView {
            VStack(spacing: KlunaSpacing.md) {
                if !journalManager.todayHasEntry() {
                    Button(action: {
                        if subscriptionManager.hasAccess(to: .voiceJournal) {
                            showJournal = true
                        } else {
                            paywallTrigger = .general
                            showPaywall = true
                        }
                    }) {
                        HStack(spacing: KlunaSpacing.sm) {
                            Image(systemName: "waveform")
                                .font(.system(size: 14))
                                .foregroundColor(.klunaAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.voiceJournal)
                                    .font(KlunaFont.heading(14))
                                    .foregroundColor(.klunaPrimary)
                                Text(userLanguage == "de" ? "60 Sekunden für deine Stimme" : "60 seconds for your voice")
                                    .font(KlunaFont.caption(12))
                                    .foregroundColor(.klunaMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.klunaMuted)
                        }
                        .padding(KlunaSpacing.md)
                        .background(Color.klunaAccent.opacity(0.06))
                        .cornerRadius(KlunaRadius.card)
                    }
                }

                HeroScoreView(averageScore: weekAverage, trend: weekDelta, subtitle: heroSubtitle)
                if totalSessions >= 4 {
                    PredictionWidget(prediction: scorePrediction, lastScore: lastScore)
                }
                if totalSessions >= 10, let consistency {
                    MasteryDashboardView(consistency: consistency)
                }
                Text(motivationText)
                    .font(KlunaFont.body(15))
                    .foregroundColor(.klunaSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, KlunaSpacing.md)
                let baseline = BaselineProgress(totalSessions: totalSessions)
                if !baseline.isEstablished {
                    BaselineProgressView(progress: baseline, language: userLanguage)
                }
                QuickStatsRow(totalSessions: totalSessions, bestScore: bestScore, streakWeeks: streakWeeks)
                DailyChallengeCard(
                    challenge: DailyChallengeProvider.shared.todaysChallenge(),
                    isCompleted: DailyChallengeProvider.shared.isTodayCompleted(),
                    streak: DailyChallengeProvider.shared.challengeStreak(),
                    language: userLanguage,
                    onStart: startDailyChallenge
                )

                if let goal = DimensionGoalManager.shared.activeGoal(),
                   let scores = memoryManager.averageScores(lastDays: 7) {
                    DimensionGoalCard(
                        goal: goal,
                        currentScore: scores.value(for: goal.dimension),
                        progress: DimensionGoalManager.shared.goalProgress(currentScores: scores) ?? 0,
                        language: userLanguage
                    )
                }

                let progressiveProvider = ProgressiveChallengeProvider.shared
                ProgressiveChallengeCard(
                    challenge: progressiveProvider.currentChallenge(),
                    currentLevel: progressiveProvider.currentLevel(),
                    totalXP: XPManager.shared.totalXP,
                    language: userLanguage,
                    onStart: startProgressiveChallenge
                )

                if subscriptionManager.tier == .free {
                    premiumLockedCard(text: L10n.weeklyReportLocked)
                } else if let report = UserDefaults.standard.string(forKey: "latestWeeklyReport") {
                    weeklyReportCard(report: report)
                }

                SparklineView(
                    dataPoints: sparklineScores,
                    labels: sparklineLabels,
                    emptyLabel: userLanguage == "de" ? "Starte deine erste Session!" : "Start your first session!",
                    title: userLanguage == "de" ? "7-Tage Verlauf (Overall)" : "7-day trend (overall)"
                )

                if subscriptionManager.hasAccess(to: .progressMilestones),
                   shouldShowProgressCard,
                   let initial = memoryManager.initialBaselineScores(),
                   let current = memoryManager.averageScores(lastDays: 7) {
                    ProgressMilestoneCard(
                        initialScores: initial,
                        currentScores: current,
                        totalSessions: memoryManager.totalSessionCount(),
                        language: userLanguage
                    )
                } else if totalSessions >= 3 {
                    EncouragementCard(
                        sessionCount: totalSessions,
                        daysActive: uniqueActiveDaysCount,
                        language: userLanguage
                    )
                }

                if let last = recentSessions.first {
                    lastSessionCard(last)
                }
            }
            .padding(.horizontal, KlunaSpacing.md)
            .padding(.vertical, KlunaSpacing.md)
        }
        .background(Color.klunaBackground.ignoresSafeArea())
        .onAppear(perform: reload)
        .fullScreenCover(isPresented: $showJournal) {
            JournalRecordView(
                viewModel: journalViewModel,
                language: userLanguage,
                onComplete: {
                    showJournal = false
                }
            )
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(trigger: paywallTrigger, language: userLanguage, subscriptionManager: subscriptionManager)
        }
    }

    private var shouldShowProgressCard: Bool {
        let all = memoryManager.allSessions()
        let dates = all.map(\.date)
        let dayStarts = Set(dates.map { Calendar.current.startOfDay(for: $0) })
        guard let first = dates.min(), let last = dates.max() else { return false }
        let daySpan = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        return all.count >= 10 && dayStarts.count >= 3 && daySpan >= 7
    }

    private var uniqueActiveDaysCount: Int {
        let all = memoryManager.allSessions()
        let dates = all.map(\.date)
        return Set(dates.map { Calendar.current.startOfDay(for: $0) }).count
    }

    private func lastSessionCard(_ session: SessionSummary) -> some View {
        let delta: Double? = {
            guard recentSessions.count > 1 else { return nil }
            return session.overallScore - recentSessions[1].overallScore
        }()
        return HStack {
            VStack(alignment: .leading, spacing: KlunaSpacing.xs) {
                Text(L10n.lastSession)
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaMuted)
                Text(session.pitchType)
                    .font(KlunaFont.heading(15))
                    .foregroundColor(.klunaPrimary)
                Text(session.date.relativeDescription)
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaMuted)
            }
            Spacer()
            HStack(spacing: KlunaSpacing.sm) {
                Text("\(Int(session.overallScore.rounded()))")
                    .font(KlunaFont.scoreDisplay(28))
                    .foregroundColor(.forScore(session.overallScore))
                if let delta {
                    Text(String(format: "%+.0f", delta))
                        .font(KlunaFont.scoreLarge(14))
                        .foregroundColor(delta >= 0 ? .klunaGreen : .klunaRed)
                }
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

    private func weeklyReportCard(report: String) -> some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            HStack(spacing: KlunaSpacing.sm) {
                Image(systemName: "doc.text")
                    .foregroundColor(.klunaAccent)
                Text(L10n.weeklyReport)
                    .font(KlunaFont.heading(14))
                    .foregroundColor(.klunaAccent)
            }
            Text(report)
                .font(KlunaFont.body(15))
                .foregroundColor(.klunaPrimary)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }

    private func premiumLockedCard(text: String) -> some View {
        HStack(spacing: KlunaSpacing.sm) {
            Image(systemName: "lock.fill").foregroundColor(.klunaAccent)
            Text(text)
                .font(KlunaFont.body(14))
                .foregroundColor(.klunaSecondary)
            Spacer()
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(Color.klunaBorder, lineWidth: 1)
        )
    }

    private func reload() {
        totalSessions = memoryManager.totalSessionCount()
        let weeklyData = currentWeeklyScore()
        weekAverage = weeklyData.score
        weekDelta = weeklyData.delta
        heroSubtitle = weeklyData.subtitle
        bestScore = memoryManager.allTimeBestScore() ?? 0
        let user = memoryManager.loadUser()
        streakWeeks = max(user.currentStreak, memoryManager.consecutiveDaysWithSessions())
        userLanguage = user.language
        scoreHistory = memoryManager.scoreHistory(lastDays: 30)
        recentSessions = memoryManager.recentSessions(count: 2)
        let recentPredictionScores = memoryManager.recentOverallScores(limit: 10, oldestFirst: true)
        scorePrediction = ScorePredictionEngine.predict(from: recentPredictionScores)
        lastScore = recentPredictionScores.last
        consistency = ConsistencyTracker().analyze()
        sparklineScores = currentSparklineScores()
        sparklineLabels = currentSparklineLabels()
    }

    private func currentSparklineScores() -> [Double] {
        let recentDays = Array(scoreHistory.suffix(7)).map(\.averageOverall)
        if recentDays.count >= 2 {
            return recentDays
        }
        let recentSessions = memoryManager.recentSessions(count: 7).reversed()
        return recentSessions.map(\.overallScore)
    }

    private func currentSparklineLabels() -> [String] {
        let recentDays = Array(scoreHistory.suffix(7))
        if recentDays.count >= 2 {
            return recentDays.map { weekdayLabel(for: $0.date) }
        }
        let sessions = Array(memoryManager.recentSessions(count: 7).reversed())
        return sessions.enumerated().map { index, _ in
            userLanguage == "de" ? "S\(index + 1)" : "S\(index + 1)"
        }
    }

    private func weekdayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: userLanguage == "de" ? "de_DE" : "en_US")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private func currentWeeklyScore() -> (score: Double, delta: Double?, subtitle: String) {
        let now = Date()
        let calendar = Calendar.current
        let sessions = memoryManager.allSessions().map { ($0.date, $0.scores.overall) }
        guard !sessions.isEmpty else {
            return (0, nil, L10n.yourWeeklyScore)
        }

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let last7 = sessions.filter { $0.0 >= sevenDaysAgo }
        if !last7.isEmpty {
            let score = last7.map(\.1).reduce(0, +) / Double(last7.count)
            let prev7 = sessions.filter { $0.0 >= fourteenDaysAgo && $0.0 < sevenDaysAgo }
            let delta = prev7.isEmpty ? nil : score - (prev7.map(\.1).reduce(0, +) / Double(prev7.count))
            return (score, delta, L10n.yourWeeklyScore)
        }

        let last14 = sessions.filter { $0.0 >= fourteenDaysAgo }
        if !last14.isEmpty {
            let score = last14.map(\.1).reduce(0, +) / Double(last14.count)
            return (score, nil, L10n.yourCurrentScore)
        }

        if let latest = sessions.max(by: { $0.0 < $1.0 }) {
            let subtitle = totalSessions < 3 ? L10n.yourFirstSessions : L10n.yourCurrentScore
            return (latest.1, nil, subtitle)
        }
        return (0, nil, L10n.yourWeeklyScore)
    }

    private var motivationText: String {
        switch totalSessions {
        case 0:
            return "Sprich 20 Sekunden. Kluna analysiert deine Stimme."
        case 1:
            return "Gut gemacht. Einmal noch - dann zeigt Kluna dir mehr."
        case 2:
            return "Session 3 schaltet dein Sprecher-Profil frei."
        case 3:
            return "Ab jetzt kann Kluna deinen Score vorhersagen."
        case 4...9:
            return "Jede Session macht deine Analyse präziser."
        default:
            return "Bereit für heute?"
        }
    }

    private func startDailyChallenge() {
        let challenge = DailyChallengeProvider.shared.todaysChallenge()
        UserDefaults.standard.set(challenge.id, forKey: "pending_daily_challenge_id")
        UserDefaults.standard.set(challenge.prompt(language: userLanguage), forKey: "pending_daily_challenge_prompt")
        UserDefaults.standard.set(challenge.timeLimit, forKey: "pending_daily_challenge_time_limit")
        selectedTab = 1
    }

    private func startProgressiveChallenge() {
        let challenge = ProgressiveChallengeProvider.shared.currentChallenge()
        if !subscriptionManager.isProUser && challenge.level > 3 {
            paywallTrigger = .challengeLevelLocked
            showPaywall = true
            return
        }
        UserDefaults.standard.set(challenge.id, forKey: "pending_progressive_challenge_id")
        UserDefaults.standard.set(challenge.title(language: userLanguage), forKey: "pending_progressive_challenge_name")
        UserDefaults.standard.set(challenge.instruction(language: userLanguage), forKey: "pending_progressive_challenge_prompt")
        UserDefaults.standard.set(challenge.timeLimit, forKey: "pending_progressive_challenge_time_limit")
        selectedTab = 1
    }
}

struct EncouragementCard: View {
    let sessionCount: Int
    let daysActive: Int
    let language: String

    var body: some View {
        HStack(spacing: KlunaSpacing.md) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20))
                .foregroundColor(.klunaAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(language == "de" ? "\(sessionCount) Sessions geschafft!" : "\(sessionCount) sessions completed!")
                    .font(KlunaFont.heading(15))
                    .foregroundColor(.klunaPrimary)
                Text(language == "de"
                     ? "Du warst bereits an \(daysActive) Tagen aktiv. Noch etwas Konstanz für klare Fortschritts-Trends."
                     : "You were active on \(daysActive) days. A bit more consistency reveals stronger progress trends.")
                .font(KlunaFont.caption(12))
                .foregroundColor(.klunaMuted)
            }
            Spacer()
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

struct DailyChallengeCard: View {
    let challenge: DailyChallenge
    let isCompleted: Bool
    let streak: Int
    let language: String
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KlunaSpacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(.klunaAccent)
                Text(L10n.dailyChallenge)
                    .font(KlunaFont.caption(13))
                    .foregroundColor(.klunaAccent)
                Spacer()
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.klunaOrange)
                        Text("\(streak)")
                            .font(KlunaFont.scoreDisplay(14))
                            .foregroundColor(.klunaOrange)
                    }
                }
            }

            Text(challenge.prompt(language: language))
                .font(KlunaFont.heading(16))
                .foregroundColor(.klunaPrimary)
                .lineSpacing(3)

            HStack(spacing: KlunaSpacing.md) {
                Label("\(challenge.timeLimit)s", systemImage: "timer")
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaMuted)
                Label(challenge.category.localizedName(language: language), systemImage: challenge.category.icon)
                    .font(KlunaFont.caption(12))
                    .foregroundColor(.klunaMuted)
                Spacer()
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i < challenge.difficulty.rawValue ? Color.klunaAccent : Color.klunaSurfaceLight)
                            .frame(width: 6, height: 6)
                    }
                }
            }

            if isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.klunaGreen)
                    Text(L10n.completed)
                        .font(KlunaFont.caption(14))
                        .foregroundColor(.klunaGreen)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, KlunaSpacing.sm)
            } else {
                Button(action: onStart) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 14))
                        Text(L10n.acceptChallenge)
                            .font(KlunaFont.heading(15))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KlunaSpacing.sm + 2)
                    .background(Color.klunaAccent)
                    .cornerRadius(KlunaRadius.button)
                }
            }
        }
        .padding(KlunaSpacing.md)
        .background(Color.klunaSurface)
        .cornerRadius(KlunaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: KlunaRadius.card)
                .stroke(isCompleted ? Color.klunaGreen.opacity(0.3) : Color.klunaBorder, lineWidth: 1)
        )
    }
}

private extension DailyChallengeCategory {
    var icon: String {
        switch self {
        case .spontan: return "bolt.fill"
        case .storytelling: return "book.fill"
        case .ueberzeugung: return "hand.raised.fill"
        case .emotion: return "heart.fill"
        case .klarheit: return "lightbulb.fill"
        }
    }

    func localizedName(language: String) -> String {
        switch self {
        case .spontan: return language == "de" ? "Spontan" : "Impromptu"
        case .storytelling: return language == "de" ? "Story" : "Story"
        case .ueberzeugung: return language == "de" ? "Überzeugen" : "Persuade"
        case .emotion: return language == "de" ? "Emotion" : "Emotion"
        case .klarheit: return language == "de" ? "Präsenz" : "Presence"
        }
    }
}

