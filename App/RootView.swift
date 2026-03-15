import SwiftUI
import UIKit

struct RootView: View {
    @AppStorage("kluna_onboarding_complete") private var onboardingComplete = false
    @AppStorage("hasCompletedOnboarding") private var legacyOnboardingComplete = false
    @AppStorage("appLanguage") private var appLanguage = "de"
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var streakManager: StreakManager
    @Environment(\.managedObjectContext) private var context
    @State private var showSplash = true
    
    var body: some View {
        Group {
            if showSplash {
                SplashScreen {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
            } else if onboardingComplete || legacyOnboardingComplete || skipOnboardingForDebug {
                MainTabView()
            } else {
                JournalOnboardingView()
            }
        }
        .task {
            appLanguage = (Locale.preferredLanguages.first ?? Locale.current.identifier).lowercased().hasPrefix("de") ? "de" : "en"
            if legacyOnboardingComplete && !onboardingComplete {
                onboardingComplete = true
            }
            KlunaAnalytics.shared.trackAppOpened()
            await CoachAPIManager.testClaudeConnection()
            streakManager.checkWeekRollover()
            await subscriptionManager.checkSubscriptionStatus()
            await KlunaNotificationManager.shared.configureOnLaunch()
            MemoryManager(context: context).seedDefaultPitchTypes()
            await checkWeeklyReport()
        }
    }

    private var skipOnboardingForDebug: Bool {
        #if DEBUG
        return DebugConfig.skipOnboarding
        #else
        return false
        #endif
    }

    private func checkWeeklyReport() async {
        guard subscriptionManager.tier != .free else { return }
        let calendar = Calendar.current
        let today = Date()

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let todayString = String(formatter.string(from: today).prefix(10))
        let memory = MemoryManager(context: context)
        let user = memory.loadUser()
        let isWeeklyRunDay = calendar.component(.weekday, from: today) == 1
        let storedLanguage = UserDefaults.standard.string(forKey: "latestWeeklyReportLanguage")
        let needsLanguageRefresh = storedLanguage != user.language

        if !isWeeklyRunDay && !needsLanguageRefresh { return }
        if !needsLanguageRefresh, UserDefaults.standard.string(forKey: "lastWeeklyReportDate") == todayString { return }

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = [.withFullDate]

        let allSessions = memory.allSessions()
        let recentWeek = allSessions
            .filter { $0.date >= sevenDaysAgo }
            .map { session in
                SessionSummary(
                    date: isoDateFormatter.string(from: session.date),
                    pitchType: session.pitchType,
                    overallScore: session.scores.overall,
                    weakestDimension: weakestDimension(for: session.scores),
                    scores: session.scores
                )
            }
        guard !recentWeek.isEmpty else { return }
        guard let currentAverage = memory.averageScores(lastDays: 7) else { return }
        let previousStart = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let previousSessions = allSessions.filter { $0.date >= previousStart && $0.date < sevenDaysAgo }
        let previousAverage = averageScores(for: previousSessions)
        guard !Config.claudeAPIKey.isEmpty else { return }

        let prompt = PromptBuilder.weeklyReportPrompt(
            sessions: recentWeek,
            user: user,
            currentAverage: currentAverage,
            previousWeekAverage: previousAverage
        )
        let systemPrompt = user.language == "de"
            ? "Du bist ein fokussierter Sprachcoach und schreibst kurze, klare Wochenrueckblicke auf Deutsch."
            : "You are a focused voice coaching analyst writing concise weekly reports in English."

        if let report = try? await CoachAPIManager.requestInsights(
            payload: prompt,
            systemPrompt: systemPrompt,
            maxTokens: 350,
            apiKey: Config.claudeAPIKey
        ) {
            UserDefaults.standard.set(report, forKey: "latestWeeklyReport")
            UserDefaults.standard.set(todayString, forKey: "lastWeeklyReportDate")
            UserDefaults.standard.set(user.language, forKey: "latestWeeklyReportLanguage")
        }
    }

    private func averageScores(for sessions: [CompletedSession]) -> DimensionScores? {
        guard !sessions.isEmpty else { return nil }
        let count = Double(sessions.count)
        return DimensionScores(
            confidence: sessions.map { $0.scores.confidence }.reduce(0, +) / count,
            energy: sessions.map { $0.scores.energy }.reduce(0, +) / count,
            tempo: sessions.map { $0.scores.tempo }.reduce(0, +) / count,
            clarity: sessions.map { $0.scores.clarity }.reduce(0, +) / count,
            stability: sessions.map { $0.scores.stability }.reduce(0, +) / count,
            charisma: sessions.map { $0.scores.charisma }.reduce(0, +) / count
        )
    }

    private func weakestDimension(for scores: DimensionScores) -> PerformanceDimension {
        let values: [(PerformanceDimension, Double)] = [
            (.confidence, scores.confidence),
            (.energy, scores.energy),
            (.tempo, scores.tempo),
            (.stability, scores.stability),
            (.charisma, scores.charisma),
        ]
        return values.min(by: { $0.1 < $1.1 })?.0 ?? .confidence
    }
}

private struct SplashScreen: View {
    @State private var bookOpenProgress: CGFloat = 0
    @State private var pageFlipProgress: CGFloat = 0
    @State private var waveProgress: CGFloat = 0
    @State private var waveToKProgress: CGFloat = 0
    @State private var glowOpacity: CGFloat = 0
    @State private var fadeOut: CGFloat = 1
    @State private var sceneScale: CGFloat = 0.96
    @State private var waveBreath: CGFloat = 0
    @State private var kScale: CGFloat = 0.9
    @State private var kYOffset: CGFloat = 12
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            KlunaWarm.background.ignoresSafeArea()

            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    drawBook(context: context, center: center, openProgress: bookOpenProgress, pageFlip: pageFlipProgress)
                    if waveProgress > 0 {
                        drawWave(context: context, center: center, progress: waveProgress)
                    }
                }

                if waveToKProgress > 0 {
                    ZStack {
                        RadialGradient(
                            gradient: Gradient(colors: [
                                KlunaWarm.warmAccent.opacity(0.3 * glowOpacity),
                                KlunaWarm.warmAccent.opacity(0.06 * glowOpacity),
                                .clear,
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                        .frame(width: 260, height: 260)

                        Text("K")
                            .font(.system(size: 100, weight: .bold, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmAccent)
                    }
                    .opacity(Double(waveToKProgress))
                    .scaleEffect(kScale)
                    .offset(y: kYOffset)
                }
            }
            .scaleEffect(sceneScale)
        }
        .opacity(fadeOut)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                sceneScale = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                bookOpenProgress = 1
            }
            withAnimation(.easeInOut(duration: 0.6).delay(0.6)) {
                pageFlipProgress = 1
            }
            withAnimation(.easeOut(duration: 0.7).delay(1.0)) {
                waveProgress = 1
            }
            withAnimation(.easeInOut(duration: 1.1).delay(1.0).repeatForever(autoreverses: true)) {
                waveBreath = 1
            }
            withAnimation(.easeInOut(duration: 0.5).delay(1.6)) {
                waveToKProgress = 1
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.76).delay(1.6)) {
                kScale = 1
                kYOffset = 0
            }
            withAnimation(.easeOut(duration: 0.4).delay(2.0)) {
                glowOpacity = 1
            }
            withAnimation(.easeInOut(duration: 0.18).delay(2.35)) {
                kScale = 1.03
            }
            withAnimation(.easeInOut(duration: 0.2).delay(2.53)) {
                kScale = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeOut(duration: 0.4)) {
                    fadeOut = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onComplete()
            }
        }
    }

    private func drawBook(context: GraphicsContext, center: CGPoint, openProgress: CGFloat, pageFlip: CGFloat) {
        let bookWidth: CGFloat = 80
        let bookHeight: CGFloat = 100
        let bookY = center.y + 20

        let warmBrown = KlunaWarm.warmBrown.opacity(0.3)

        let spineX = center.x

        var rightPage = Path()
        rightPage.move(to: CGPoint(x: spineX, y: bookY - bookHeight / 2))
        rightPage.addLine(to: CGPoint(x: spineX + bookWidth, y: bookY - bookHeight / 2))
        rightPage.addLine(to: CGPoint(x: spineX + bookWidth, y: bookY + bookHeight / 2))
        rightPage.addLine(to: CGPoint(x: spineX, y: bookY + bookHeight / 2))
        rightPage.closeSubpath()

        context.stroke(rightPage, with: .color(warmBrown), style: StrokeStyle(lineWidth: 1.5))
        context.fill(rightPage, with: .color(KlunaWarm.cardBackground.opacity(0.5)))

        let leftAngle = openProgress * 0.8
        let leftEndX = spineX - bookWidth * cos(leftAngle * .pi / 2)
        let leftEndYOffset = bookWidth * sin(leftAngle * .pi / 2) * 0.1

        var leftPage = Path()
        leftPage.move(to: CGPoint(x: spineX, y: bookY - bookHeight / 2))
        leftPage.addLine(to: CGPoint(x: leftEndX, y: bookY - bookHeight / 2 - leftEndYOffset))
        leftPage.addLine(to: CGPoint(x: leftEndX, y: bookY + bookHeight / 2 + leftEndYOffset))
        leftPage.addLine(to: CGPoint(x: spineX, y: bookY + bookHeight / 2))
        leftPage.closeSubpath()

        context.stroke(leftPage, with: .color(warmBrown), style: StrokeStyle(lineWidth: 1.5))
        context.fill(leftPage, with: .color(KlunaWarm.cardBackground.opacity(0.3)))

        if pageFlip > 0 && pageFlip < 1 {
            for i in 0..<4 {
                let pageProgress = max(0, min(1, pageFlip * 4 - CGFloat(i)))
                let pageAngle = pageProgress * 0.7
                let px = spineX - bookWidth * 0.8 * cos(pageAngle * .pi / 2)

                var page = Path()
                page.move(to: CGPoint(x: spineX, y: bookY - bookHeight / 2 + 5))
                page.addLine(to: CGPoint(x: px, y: bookY - bookHeight / 2 + 3))
                page.addLine(to: CGPoint(x: px, y: bookY + bookHeight / 2 - 3))
                page.addLine(to: CGPoint(x: spineX, y: bookY + bookHeight / 2 - 5))

                context.stroke(
                    page,
                    with: .color(KlunaWarm.warmBrown.opacity(0.1)),
                    style: StrokeStyle(lineWidth: 0.5)
                )
            }
        }

        if openProgress > 0.5 {
            let lineOpacity = (openProgress - 0.5) * 2
            for i in 0..<4 {
                let lineY = bookY - bookHeight / 3 + CGFloat(i) * 15
                var line = Path()
                line.move(to: CGPoint(x: spineX + 10, y: lineY))
                line.addLine(to: CGPoint(x: spineX + bookWidth - 15, y: lineY))
                context.stroke(
                    line,
                    with: .color(KlunaWarm.warmBrown.opacity(0.06 * lineOpacity)),
                    style: StrokeStyle(lineWidth: 1)
                )
            }
        }
    }

    private func drawWave(context: GraphicsContext, center: CGPoint, progress: CGFloat) {
        let bookY = center.y + 20
        let waveStartY = bookY - 30
        let waveEndY = center.y - 80 * progress
        let waveWidth: CGFloat = 160
        let startX = center.x - waveWidth / 2

        var wavePath = Path()
        wavePath.move(to: CGPoint(x: startX, y: waveStartY))

        let segments = 40
        for i in 0...segments {
            let t = CGFloat(i) / CGFloat(segments)
            let x = startX + waveWidth * t
            let baseY = waveStartY + (waveEndY - waveStartY) * t
            let amplitude: CGFloat = (12 + waveBreath * 5) * progress * sin(t * .pi)
            let wave = sin(t * .pi * 4 + progress * .pi + waveBreath * .pi * 0.7) * amplitude
            wavePath.addLine(to: CGPoint(x: x, y: baseY + wave))
        }

        context.stroke(
            wavePath,
            with: .linearGradient(
                Gradient(colors: [
                    KlunaWarm.warmAccent.opacity(0.1),
                    KlunaWarm.warmAccent.opacity(0.6 * progress),
                    KlunaWarm.warmAccent.opacity(0.8 * progress),
                    KlunaWarm.warmAccent.opacity(0.3 * progress),
                ]),
                startPoint: CGPoint(x: center.x, y: waveStartY),
                endPoint: CGPoint(x: center.x, y: waveEndY)
            ),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )

        context.stroke(
            wavePath,
            with: .color(KlunaWarm.warmAccent.opacity(0.1 * progress)),
            style: StrokeStyle(lineWidth: 8, lineCap: .round)
        )
    }
}

private struct MicrophonePermissionView: View {
    let onRetry: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(KlunaWarm.warmAccent)
            Text("Kluna braucht Mikrofonzugriff")
                .font(.title3.weight(.semibold))
                .foregroundStyle(KlunaWarm.warmBrown)
            Text("Bitte erlaube den Mikrofonzugriff, damit du sofort mit deinem Voice Journal starten kannst.")
                .multilineTextAlignment(.center)
                .foregroundStyle(KlunaWarm.secondary)
                .padding(.horizontal, 28)
            Button("Erneut anfragen", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(KlunaWarm.warmAccent)
            Button("Einstellungen öffnen", action: onOpenSettings)
                .buttonStyle(.bordered)
                .tint(KlunaWarm.warmBrown)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KlunaWarm.background.ignoresSafeArea())
    }
}

struct LegacyMainTabView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @AppStorage("main.selectedTab") private var selectedTab = 0
    @AppStorage("main.hasInitializedTab") private var hasInitializedTab = false
    private let memoryManager = MemoryManager(context: PersistenceController.shared.container.viewContext)

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(L10n.dashboard, systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            RecordingView()
                .tabItem {
                    Label(L10n.practice, systemImage: "mic.fill")
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label(L10n.history, systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(L10n.settings, systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.klunaAccent)
        .onAppear {
            // Initial tab only once to avoid overriding user navigation.
            guard !hasInitializedTab else { return }
            selectedTab = memoryManager.totalSessionCount() == 0 ? 1 : 0
            hasInitializedTab = true
        }
    }
}
