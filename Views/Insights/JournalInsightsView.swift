import SwiftUI
import CoreData
import UIKit
import Foundation

struct JournalInsightsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var dataManager = KlunaDataManager.shared
    @ObservedObject private var klunaMemory = KlunaMemory.shared

    @State private var monthOffset = 0
    @State private var weekOffset = 0

    @State private var monthWord = "Wandel"
    @State private var weekSummary = "Noch kein Wochenfazit."
    @State private var themes: [VoiceTheme] = []
    @State private var insights: [Insight] = []
    @State private var monthlyLetter = "Noch kein Monatsbrief verfügbar."
    @State private var detectedPatterns: [StimmPatternV2] = []

    @State private var showMonthlyLetter = false

    private var displayName: String {
        let profileName = UserDefaults.standard.string(forKey: "kluna_profile_name")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !profileName.isEmpty { return profileName }
        let onboardingName = UserDefaults.standard.string(forKey: "userName")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return onboardingName.isEmpty ? "du" : onboardingName
    }

    private var todayEntries: [JournalEntry] {
        dataManager.entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted(by: { $0.date < $1.date })
    }

    private var uniqueDays: Int {
        Set(dataManager.entries.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var mentionReactions: [MentionReaction] {
        MentionTracker.shared.allSignificantReactions()
    }

    private var dailyAverages: [(date: Date, dims: VoiceDimensions)] {
        let grouped = Dictionary(grouping: dataManager.entries) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted().map { day in
            let dayEntries = grouped[day] ?? []
            let dims = dayEntries.map(VoiceDimensions.from)
            let c = CGFloat(max(1, dims.count))
            return (
                day,
                VoiceDimensions(
                    energy: dims.map(\.energy).reduce(0, +) / c,
                    tension: dims.map(\.tension).reduce(0, +) / c,
                    fatigue: dims.map(\.fatigue).reduce(0, +) / c,
                    warmth: dims.map(\.warmth).reduce(0, +) / c,
                    expressiveness: dims.map(\.expressiveness).reduce(0, +) / c,
                    tempo: dims.map(\.tempo).reduce(0, +) / c
                )
            )
        }
    }

    private var monthEntriesForRing: [JournalEntry] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: currentMonthDate) else { return [] }
        return dataManager.entries
            .filter { monthInterval.contains($0.date) }
            .sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("insights.title_v2".localized)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 16)

                    MoodRingSection(
                        entries: monthEntriesForRing,
                        monthDate: currentMonthDate,
                        monthWord: monthWord,
                        onPreviousMonth: { monthOffset -= 1 },
                        onNextMonth: { monthOffset += 1 }
                    )

                    if !todayEntries.isEmpty {
                        TodaySummarySectionV2(todayEntries: todayEntries)
                    }

                    if !themes.isEmpty {
                        ThemesSectionV2(aggregates: themes.map(ThemeAggregate.init))
                    }

                    if !mentionReactions.isEmpty {
                        VoiceLandmapSection(reactions: mentionReactions)
                    }

                    if dataManager.entries.count >= 3 {
                        PatternSectionV2(patterns: detectedPatterns.isEmpty ? generatePatternsV2() : detectedPatterns)
                    }

                    if uniqueDays >= 3 {
                        TrendSectionV2(dailyAverages: dailyAverages)
                    }

                    if dataManager.entries.count >= 5 || uniqueDays >= 3 {
                        ClaudeSummarySectionV2(
                            title: summaryTitle(uniqueDays: uniqueDays, totalEntries: dataManager.entries.count),
                            text: summaryTextV2()
                        )
                    }

                    if !dataManager.entries.isEmpty {
                        KlunaKnowsYouSection(memory: klunaMemory)
                    }

                    if uniqueDays >= 28 {
                        MonthlyLetterTeaser(
                            month: monthTitle,
                            text: formatMonthlyLetter(monthlyLetter, name: displayName)
                        ) {
                            showMonthlyLetter = true
                        }
                        if let monthlyShareData {
                            KlunaShareButton(action: {
                                ShareABManager.shared.trackTap(.monthly)
                                ShareImageGenerator.share(content: .monthlyReview(monthlyShareData))
                            })
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, -4)
                            .onAppear {
                                ShareABManager.shared.trackShown(.monthly)
                            }
                        }
                    }

                    if uniqueDays < 3 {
                        LockedInsightCard(
                            title: "insights.voice_trend".localized,
                            description: "Noch \(3 - uniqueDays) Tage bis Kluna deinen Verlauf zeigen kann.",
                            icon: "chart.line.uptrend.xyaxis"
                        )
                    }
                    if uniqueDays < 7 {
                        LockedInsightCard(
                            title: "weekly_report".localized,
                            description: String(format: "insights.weekly_analysis_locked".localized, 7 - uniqueDays),
                            icon: "calendar"
                        )
                    }
                    if uniqueDays < 28 {
                        LockedInsightCard(
                            title: "Monatsbrief",
                            description: String(format: "insights.monthly_letter_locked".localized, 28 - uniqueDays),
                            icon: "envelope"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(KlunaWarm.background.ignoresSafeArea())
            .refreshable {
                await refreshInsightsData()
            }
            .sheet(isPresented: $showMonthlyLetter) {
                MonthlyLetterSheet(
                    month: monthTitle,
                    monthWord: monthWord,
                    entries: monthEntries,
                    letterText: formatMonthlyLetter(monthlyLetter, name: displayName),
                    highlights: monthHighlights
                )
            }
            .navigationTitle("insights.title_v2".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            reload()
            Task { await refreshAI(force: false) }
        }
        .onChange(of: monthOffset) { _, _ in
            Task { await refreshAI(force: false) }
        }
        .onChange(of: weekOffset) { _, _ in
            Task { await refreshAI(force: false) }
        }
    }

    private var currentMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var currentWeekStart: Date {
        let base = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: base) ?? base
    }

    private var monthEntries: [JournalEntry] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: currentMonthDate) else { return [] }
        return dataManager.entries
            .filter { monthInterval.contains($0.date) }
            .sorted(by: { $0.date < $1.date })
    }

    private var currentWeekEntries: [JournalEntry] {
        guard let weekInterval = Calendar.current.dateInterval(of: .weekOfYear, for: currentWeekStart) else { return [] }
        return dataManager.entries
            .filter { weekInterval.contains($0.date) }
            .sorted(by: { $0.date < $1.date })
    }

    private var monthTitle: String {
        currentMonthDate.formatted(.dateTime.month(.wide).year())
    }

    private var monthHighlights: MonthHighlights {
        MonthHighlights.from(entries: monthEntries)
    }

    private var monthlyShareData: MonthlyReviewShareData? {
        guard !monthEntries.isEmpty else { return nil }
        let grouped = Dictionary(grouping: monthEntries) {
            MoodCategory.resolve($0.mood)?.rawValue ?? ($0.moodLabel ?? "ruhig").lowercased()
        }
        let total = Float(max(1, monthEntries.count))
        let moodDistribution: [(String, Color, Float)] = grouped
            .map { key, value in
                let sample = value.first
                return (key, sample?.stimmungsfarbe ?? KlunaWarm.warmAccent, Float(value.count) / total)
            }
            .sorted(by: { $0.2 > $1.2 })
        let dominant = moodDistribution.first
        let dimensions = VoiceDimensions.from(monthEntries.first ?? monthEntries.last!)
        let minutes = Int(monthEntries.map(\.duration).reduce(0, +) / 60)
        return MonthlyReviewShareData(
            month: monthTitle.capitalized,
            dominantMood: dominant?.0 ?? "ruhig",
            dominantColor: dominant?.1 ?? KlunaWarm.warmAccent,
            totalEntries: monthEntries.count,
            totalMinutes: minutes,
            streakRecord: longestStreak(in: monthEntries),
            moodDistribution: moodDistribution,
            signatureData: .fromDimensions(dimensions)
        )
    }

    private func reload() {
        dataManager.refresh(limit: 160)
    }

    private func summaryTitle(uniqueDays: Int, totalEntries: Int) -> String {
        if uniqueDays >= 28 { return "Dein Monat" }
        if uniqueDays >= 7 { return "Deine Woche" }
        if uniqueDays >= 3 { return "Deine letzten Tage" }
        if totalEntries >= 5 { return "Deine bisherigen Einträge" }
        return "Kluna lernt dich kennen"
    }

    private func longestStreak(in entries: [JournalEntry]) -> Int {
        let days = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1..<days.count {
            let previous = days[index - 1]
            let currentDay = days[index]
            let diff = Calendar.current.dateComponents([.day], from: previous, to: currentDay).day ?? 0
            if diff == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    private func summaryTextV2() -> String {
        if uniqueDays >= 7 {
            return weekSummary
        }
        let fallback = "Mit jedem Eintrag erkennt Kluna deine Stimme klarer."
        if !monthlyLetter.isEmpty, monthlyLetter != "Noch kein Monatsbrief verfügbar." {
            return monthlyLetter
        }
        return weekSummary == "Noch kein Wochenfazit." ? fallback : weekSummary
    }

    private func generatePatternsV2() -> [StimmPatternV2] {
        guard dataManager.entries.count >= 3 else {
            return [
                StimmPatternV2(icon: "sparkles", title: "Erste Muster", description: "Kluna beginnt Muster in deiner Stimme zu erkennen.", color: KlunaWarm.warmAccent, confidence: 58)
            ]
        }

        let sorted = dataManager.entries.sorted(by: { $0.date < $1.date })
        let dims = sorted.map(VoiceDimensions.from)
        let avgTension = dims.map(\.tension).reduce(0, +) / CGFloat(max(1, dims.count))
        let avgFatigue = dims.map(\.fatigue).reduce(0, +) / CGFloat(max(1, dims.count))
        let avgEnergy = dims.map(\.energy).reduce(0, +) / CGFloat(max(1, dims.count))

        var patterns: [StimmPatternV2] = []
        if avgTension > 0.58 {
            patterns.append(.init(icon: "bolt.heart", title: "Grundspannung", description: "Deine Stimme wirkt in mehreren Einträgen leicht angespannt.", color: Color(hex: "E85C5C"), confidence: 81, colorKey: "red"))
        }
        if avgFatigue > 0.55 {
            patterns.append(.init(icon: "moon.zzz", title: "Müdigkeitsmuster", description: "Über mehrere Einträge klingt deine Stimme eher erschöpft.", color: Color(hex: "8B9DAF"), confidence: 77, colorKey: "blue"))
        }
        if avgEnergy > 0.6 {
            patterns.append(.init(icon: "flame", title: "Energiephase", description: "In den letzten Einträgen ist viel Energie hörbar.", color: Color(hex: "F5B731"), confidence: 75, colorKey: "orange"))
        }

        if patterns.count < 2 {
            patterns.append(.init(icon: "waveform.path.ecg", title: "Stimmkurve", description: "Deine Stimme bleibt insgesamt stabil, mit kleinen Schwankungen im Tagesverlauf.", color: KlunaWarm.warmAccent, confidence: 63, colorKey: "orange"))
        }
        return Array(patterns.prefix(4))
    }

    @MainActor
    private func refreshAI(force: Bool) async {
        let weekKey = CacheKeys.weekKey(for: currentWeekStart)
        let monthKey = CacheKeys.monthKey(for: currentMonthDate)

        if !force, let cachedWeek = InsightsCache.loadWeek(key: weekKey) {
            weekSummary = cachedWeek.weekSummary
            themes = cachedWeek.themes.map { $0.toTheme(entries: dataManager.entries) }
            insights = cachedWeek.insights.map { $0.toInsight() }
        }

        if !force, let cachedMonth = InsightsCache.loadMonth(key: monthKey) {
            monthWord = cachedMonth.monthWord
            monthlyLetter = cachedMonth.letterText
        }
        if !force, let cachedPatterns = InsightsCache.loadPatterns(), !InsightsCache.isPatternsStale() {
            detectedPatterns = cachedPatterns.patterns.map(patternFromCache)
        }

        guard !Config.claudeAPIKey.isEmpty else {
            if themes.isEmpty { themes = fallbackThemes(from: currentWeekEntries) }
            if insights.isEmpty { insights = fallbackInsights(from: currentWeekEntries) }
            if weekSummary == "Noch kein Wochenfazit." { weekSummary = fallbackWeekSummary(from: currentWeekEntries) }
            if monthlyLetter == "Noch kein Monatsbrief verfügbar." { monthlyLetter = fallbackMonthlyLetter(from: monthEntries) }
            if monthWord == "Wandel" { monthWord = fallbackMonthWord(from: monthEntries) }
            if detectedPatterns.isEmpty { detectedPatterns = generatePatternsV2() }
            return
        }

        let shouldCallWeeklyClaude = PeriodicClaudeCalls.shouldGenerateWeeklySummary()
        if currentWeekEntries.count >= 5,
           shouldCallWeeklyClaude,
           (InsightsCache.loadWeek(key: weekKey) == nil || InsightsCache.isWeekStale(key: weekKey) || force) {
            do {
                let weekPack = try await generateWeekInsights(entries: currentWeekEntries)
                weekSummary = weekPack.weekSummary
                themes = weekPack.themes
                insights = weekPack.insights
                InsightsCache.saveWeek(
                    key: weekKey,
                    value: .init(
                        generatedAt: Date(),
                        weekSummary: weekPack.weekSummary,
                        themes: weekPack.themes.map(WeekThemeDTO.init),
                        insights: weekPack.insights.map(WeekInsightDTO.init)
                    )
                )
                PeriodicClaudeCalls.markWeeklyGenerated()
            } catch {
                if themes.isEmpty { themes = fallbackThemes(from: currentWeekEntries) }
                if insights.isEmpty { insights = fallbackInsights(from: currentWeekEntries) }
                if weekSummary == "Noch kein Wochenfazit." { weekSummary = fallbackWeekSummary(from: currentWeekEntries) }
            }
        }

        let shouldCallMonthlyClaude = PeriodicClaudeCalls.shouldGenerateMonthlyLetter()
        if monthEntries.count >= 8,
           shouldCallMonthlyClaude,
           (InsightsCache.loadMonth(key: monthKey) == nil || InsightsCache.isMonthStale(key: monthKey) || force) {
            do {
                let monthPack = try await generateMonthInsights(entries: monthEntries)
                monthWord = monthPack.word
                monthlyLetter = monthPack.letter
                InsightsCache.saveMonth(
                    key: monthKey,
                    value: .init(generatedAt: Date(), monthWord: monthPack.word, letterText: monthPack.letter)
                )
                PeriodicClaudeCalls.markMonthlyGenerated()
            } catch {
                if monthWord == "Wandel" { monthWord = fallbackMonthWord(from: monthEntries) }
                if monthlyLetter == "Noch kein Monatsbrief verfügbar." { monthlyLetter = fallbackMonthlyLetter(from: monthEntries) }
            }
        }

        if dataManager.entries.count >= 3 && (force || detectedPatterns.isEmpty) {
            detectedPatterns = generatePatternsV2()
            InsightsCache.savePatterns(
                PatternCache(
                    generatedAt: Date(),
                    patterns: detectedPatterns.map(patternToCache)
                )
            )
        }
    }

    @MainActor
    private func refreshInsightsData() async {
        reload()
        await refreshAI(force: true)
    }

    private func generateWeekInsights(entries: [JournalEntry]) async throws -> WeekPack {
        let sorted = entries.sorted(by: { $0.date < $1.date })
        let rows = sorted.map {
            "\($0.date.formatted(.dateTime.weekday(.abbreviated))): \($0.quadrant.rawValue), \($0.moodLabel ?? "-"), \"\(String($0.transcript.prefix(90)))\""
        }.joined(separator: "\n")

        let weekSummaryPayload = "[WOCHE]\n\(rows)"
        let unifiedWeekPrompt = """
        Du analysierst eine Journal-Woche.
        Antworte NUR als JSON-Objekt im Format:
        {
          "summary": "2-3 Saetze, warm, persoenlich, ohne Zahlen",
          "themes": [{"name":"...", "count":2, "trend":"improving|declining|stable"}],
          "insights": [{"icon":"calendar","color":"orange","title":"...","body":"..."}]
        }
        Regeln:
        - themes: 3-6 Elemente, name max 2 Worte
        - insights: 3-5 Elemente
        - kein Text ausserhalb von JSON
        """
        let unifiedRaw = try await CoachAPIManager.requestInsights(
            payload: weekSummaryPayload,
            systemPrompt: unifiedWeekPrompt,
            maxTokens: 420,
            apiKey: Config.claudeAPIKey
        )
        let parsed = parseWeekUnifiedDTO(from: unifiedRaw)
        let parsedThemes = (parsed?.themes ?? [])
            .prefix(6)
            .map { $0.toTheme(entries: sorted) }
        let parsedInsights = (parsed?.insights ?? [])
            .prefix(5)
            .map { $0.toInsight() }

        return WeekPack(
            weekSummary: cleanedPlainText(parsed?.summary ?? ""),
            themes: parsedThemes.isEmpty ? fallbackThemes(from: sorted) : parsedThemes,
            insights: parsedInsights.isEmpty ? fallbackInsights(from: sorted) : parsedInsights
        )
    }

    private func generateMonthInsights(entries: [JournalEntry]) async throws -> MonthPack {
        let rows = entries.sorted(by: { $0.date < $1.date }).map {
            "\($0.date.formatted(.dateTime.day().month(.abbreviated))): \($0.moodLabel ?? $0.quadrant.rawValue) \"\(String($0.transcript.prefix(80)))\""
        }.joined(separator: "\n")

        let monthPrompt = """
        Schreibe eine Monatsauswertung.
        Antworte EXAKT mit:
        WORD: <ein Wort als Essenz>
        LETTER: <4-6 Saetze, warm, direkt an \(displayName), ohne Fachbegriffe und Zahlen>
        """
        let monthRaw = try await CoachAPIManager.requestInsights(
            payload: rows,
            systemPrompt: monthPrompt,
            maxTokens: 320,
            apiKey: Config.claudeAPIKey
        )
        let parsedMonth = parseMonthTaggedResponse(from: monthRaw)
        let cleanedWord = cleanedPlainText(parsedMonth.word)
            .components(separatedBy: .whitespacesAndNewlines)
            .first?
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,:;!?\"'")) ?? "Wandel"

        return MonthPack(
            word: cleanedWord.isEmpty ? "Wandel" : cleanedWord,
            letter: cleanedPlainText(parsedMonth.letter)
        )
    }

    private func fallbackWeekSummary(from entries: [JournalEntry]) -> String {
        let stressed = entries.filter { $0.quadrant == .aufgewuehlt || $0.quadrant == .erschoepft }.count
        if stressed >= 3 {
            return "Diese Woche war fordernd. Gegen Ende wirkt deine Stimme etwas ruhiger."
        }
        return "Diese Woche klingt insgesamt ausbalanciert, mit einzelnen Spitzen."
    }

    private func fallbackMonthWord(from entries: [JournalEntry]) -> String {
        let top = Dictionary(grouping: entries, by: { $0.quadrant }).max { $0.value.count < $1.value.count }?.key
        switch top {
        case .begeistert: return "Aufbruch"
        case .aufgewuehlt: return "Unruhe"
        case .zufrieden: return "Ruhe"
        case .erschoepft: return "Erholung"
        case .none: return "Wandel"
        }
    }

    private func fallbackMonthlyLetter(from entries: [JournalEntry]) -> String {
        guard !entries.isEmpty else { return "Noch kein Monatsbrief verfügbar." }
        let first = entries.first?.moodLabel ?? "offen"
        let last = entries.last?.moodLabel ?? "ruhiger"
        return "\(displayName), dein Monat hat bei \(first) begonnen und endet spürbar bei \(last). In deinen Einträgen zeigt sich, dass du dir selbst klarer zuhörst. Das wirkt ruhiger und gleichzeitig entschlossener."
    }

    private func formatMonthlyLetter(_ text: String, name: String) -> String {
        text
            .replacingOccurrences(of: "[Name]", with: name)
            .replacingOccurrences(of: "[name]", with: name)
    }

    private func fallbackThemes(from entries: [JournalEntry]) -> [VoiceTheme] {
        let keywords = [
            ("arbeit", "Arbeit"),
            ("projekt", "Projekt"),
            ("familie", "Familie"),
            ("freund", "Freunde"),
            ("gesund", "Gesundheit"),
            ("schlaf", "Schlaf"),
        ]
        var buckets: [String: [JournalEntry]] = [:]
        for entry in entries {
            let text = entry.transcript.lowercased()
            for (needle, label) in keywords where text.contains(needle) {
                buckets[label, default: []].append(entry)
            }
        }
        return buckets.map { key, group in
            VoiceTheme(
                id: key,
                name: key,
                count: group.count,
                averageMoodColor: group.first?.stimmungsfarbe ?? KlunaWarm.secondary,
                trend: .stable,
                relatedEntries: group.sorted(by: { $0.date > $1.date }),
                averageArousal: group.map(\.arousal).reduce(0, +) / Float(max(1, group.count))
            )
        }.sorted(by: { $0.count > $1.count })
    }

    private func fallbackInsights(from entries: [JournalEntry]) -> [Insight] {
        let body = entries.count >= 5
            ? "Du hast diese Woche eine erkennbare emotionale Kurve. Mitte der Woche wirkt deine Stimme meist fokussierter."
            : "Mit mehr Einträgen werden deine Muster noch klarer."
        return [
            Insight(id: "fallback-1", icon: "calendar", accentColor: KlunaWarm.warmAccent, title: "Wochenmuster", body: body, relatedEntryIds: entries.prefix(2).map(\.id)),
            Insight(id: "fallback-2", icon: "sparkles", accentColor: KlunaWarm.zufrieden, title: "Entwicklung", body: "Du klingst in den letzten Einträgen konsistenter und klarer.", relatedEntryIds: entries.suffix(2).map(\.id))
        ]
    }

    private func parseThemeDTOs(from raw: String) -> [WeekThemeDTO] {
        guard let data = extractJSONArrayData(from: raw) else { return [] }
        return (try? JSONDecoder().decode([WeekThemeDTO].self, from: data)) ?? []
    }

    private func parseInsightDTOs(from raw: String) -> [WeekInsightDTO] {
        guard let data = extractJSONArrayData(from: raw) else { return [] }
        return (try? JSONDecoder().decode([WeekInsightDTO].self, from: data)) ?? []
    }

    private func parsePatternDTOs(from raw: String) -> [PatternDTO] {
        guard let data = extractJSONArrayData(from: raw) else { return [] }
        return (try? JSONDecoder().decode([PatternDTO].self, from: data)) ?? []
    }

    private func extractJSONArrayData(from text: String) -> Data? {
        if let direct = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: direct)) is [[String: Any]] {
            return direct
        }
        guard let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start <= end else { return nil }
        let fragment = String(text[start...end])
        return fragment.data(using: .utf8)
    }

    private func cleanedPlainText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseWeekUnifiedDTO(from raw: String) -> WeekUnifiedDTO? {
        guard let data = extractJSONObjectData(from: raw) else { return nil }
        return try? JSONDecoder().decode(WeekUnifiedDTO.self, from: data)
    }

    private func parseMonthTaggedResponse(from raw: String) -> (word: String, letter: String) {
        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var word = ""
        var letter = ""
        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("WORD:") {
                word = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if upper.hasPrefix("LETTER:") {
                letter = String(line.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if !letter.isEmpty {
                letter += " " + line
            }
        }
        return (word: word, letter: letter)
    }

    private func extractJSONObjectData(from text: String) -> Data? {
        if let direct = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: direct)) is [String: Any] {
            return direct
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else { return nil }
        let fragment = String(text[start...end])
        return fragment.data(using: .utf8)
    }

    private func patternToCache(_ pattern: StimmPatternV2) -> PatternCacheItem {
        PatternCacheItem(
            icon: pattern.icon,
            title: pattern.title,
            description: pattern.description,
            color: pattern.colorHint,
            confidence: pattern.confidence
        )
    }

    private func patternFromCache(_ item: PatternCacheItem) -> StimmPatternV2 {
        StimmPatternV2(
            icon: item.icon,
            title: item.title,
            description: item.description,
            color: InsightColorMapper.color(for: item.color),
            confidence: min(max(item.confidence, 50), 99),
            colorKey: item.color
        )
    }
}

// MARK: - AI Cache

private enum CacheKeys {
    static let weekPrefix = "insights.week."
    static let monthPrefix = "insights.month."
    static let patternsKey = "insights.patterns.v2"

    static func weekKey(for weekStart: Date) -> String {
        weekPrefix + weekStart.formatted(.iso8601.year().weekOfYear())
    }

    static func monthKey(for monthDate: Date) -> String {
        monthPrefix + monthDate.formatted(.dateTime.year().month(.twoDigits))
    }
}

private enum InsightsCache {
    static func saveWeek(key: String, value: WeekCache) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadWeek(key: String) -> WeekCache? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WeekCache.self, from: data)
    }

    static func isWeekStale(key: String) -> Bool {
        guard let cache = loadWeek(key: key) else { return true }
        return Date().timeIntervalSince(cache.generatedAt) > 60 * 60 * 24 * 7
    }

    static func saveMonth(key: String, value: MonthCache) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadMonth(key: String) -> MonthCache? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MonthCache.self, from: data)
    }

    static func isMonthStale(key: String) -> Bool {
        guard let cache = loadMonth(key: key) else { return true }
        return Date().timeIntervalSince(cache.generatedAt) > 60 * 60 * 24 * 31
    }

    static func savePatterns(_ patterns: PatternCache) {
        if let data = try? JSONEncoder().encode(patterns) {
            UserDefaults.standard.set(data, forKey: CacheKeys.patternsKey)
        }
    }

    static func loadPatterns() -> PatternCache? {
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.patternsKey) else { return nil }
        return try? JSONDecoder().decode(PatternCache.self, from: data)
    }

    static func isPatternsStale() -> Bool {
        guard let cache = loadPatterns() else { return true }
        return Date().timeIntervalSince(cache.generatedAt) > 60 * 60 * 6
    }
}

private struct WeekCache: Codable {
    let generatedAt: Date
    let weekSummary: String
    let themes: [WeekThemeDTO]
    let insights: [WeekInsightDTO]
}

private struct MonthCache: Codable {
    let generatedAt: Date
    let monthWord: String
    let letterText: String
}

private struct PatternCache: Codable {
    let generatedAt: Date
    let patterns: [PatternCacheItem]
}

private struct PatternCacheItem: Codable {
    let icon: String
    let title: String
    let description: String
    let color: String
    let confidence: Int
}

private struct WeekUnifiedDTO: Codable {
    let summary: String
    let themes: [WeekThemeDTO]
    let insights: [WeekInsightDTO]
}

private struct WeekPack {
    let weekSummary: String
    let themes: [VoiceTheme]
    let insights: [Insight]
}

private struct MonthPack {
    let word: String
    let letter: String
}

private struct WeekThemeDTO: Codable {
    let name: String
    let count: Int
    let trend: String

    init(name: String, count: Int, trend: String) {
        self.name = name
        self.count = count
        self.trend = trend
    }

    init(_ theme: VoiceTheme) {
        self.name = theme.name
        self.count = theme.count
        switch theme.trend {
        case .improving: self.trend = "improving"
        case .declining: self.trend = "declining"
        case .stable: self.trend = "stable"
        }
    }

    func toTheme(entries: [JournalEntry]) -> VoiceTheme {
        let related = entries
            .filter { $0.transcript.localizedCaseInsensitiveContains(name) }
            .sorted(by: { $0.date > $1.date })
        return VoiceTheme(
            id: name,
            name: name,
            count: max(count, related.count),
            averageMoodColor: related.first?.stimmungsfarbe ?? KlunaWarm.secondary,
            trend: ThemeTrend(raw: trend),
            relatedEntries: related,
            averageArousal: related.map(\.arousal).reduce(0, +) / Float(max(1, related.count))
        )
    }
}

private struct WeekInsightDTO: Codable {
    let icon: String
    let color: String
    let title: String
    let body: String

    init(icon: String, color: String, title: String, body: String) {
        self.icon = icon
        self.color = color
        self.title = title
        self.body = body
    }

    init(_ insight: Insight) {
        self.icon = insight.icon
        self.color = "orange"
        self.title = insight.title
        self.body = insight.body
    }

    func toInsight() -> Insight {
        Insight(
            id: UUID().uuidString,
            icon: icon,
            accentColor: InsightColorMapper.color(for: color),
            title: title,
            body: body,
            relatedEntryIds: []
        )
    }
}

private struct PatternDTO: Codable {
    let icon: String
    let title: String
    let description: String
    let color: String
    let confidence: Int?
}

private enum InsightColorMapper {
    static func color(for raw: String) -> Color {
        switch raw.lowercased() {
        case "teal": return .teal
        case "green": return .green
        case "blue": return .blue
        case "red": return .red
        case "purple": return .purple
        default: return KlunaWarm.warmAccent
        }
    }
}

// MARK: - V2 Sections

private struct TodaySummarySectionV2: View {
    let todayEntries: [JournalEntry]

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("insights.today".localized)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Spacer()
                    Text(String(format: "insights.entries_count".localized, todayEntries.count))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(todayEntries) { entry in
                            HStack(spacing: 6) {
                                Circle().fill(entry.stimmungsfarbe).frame(width: 8, height: 8)
                                Text(entry.moodLabel ?? entry.quadrant.label)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                                Text(entry.date.formatted(.dateTime.hour().minute()))
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(entry.stimmungsfarbe.opacity(0.06)))
                        }
                    }
                }

                if todayEntries.count >= 2 {
                    Text(highlightText())
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                        .lineSpacing(3)
                }
            }
        }
    }

    private func highlightText() -> String {
        let energetic = todayEntries.max { VoiceDimensions.from($0).energy < VoiceDimensions.from($1).energy }
        let tired = todayEntries.max { VoiceDimensions.from($0).fatigue < VoiceDimensions.from($1).fatigue }
        var text = ""
        if let energetic {
            text += "Am lebendigsten um \(energetic.date.formatted(.dateTime.hour().minute()))."
        }
        if let tired, tired.id != energetic?.id {
            text += " Am müdesten um \(tired.date.formatted(.dateTime.hour().minute()))."
        }
        return text
    }
}

private struct ThemesSectionV2: View {
    let aggregates: [ThemeAggregate]
    @State private var expandedTheme: String?
    @State private var didAppear = false

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("insights.your_themes".localized)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)

                InsightsFlowLayout(spacing: 8) {
                    ForEach(Array(aggregates.sorted(by: { $0.count > $1.count }).enumerated()), id: \.element.id) { index, theme in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                expandedTheme = expandedTheme == theme.name ? nil : theme.name
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 7) {
                                Circle()
                                    .fill(theme.dominantMoodColor)
                                    .frame(width: 8, height: 8)
                                Text(wrappedThemeName(theme.name))
                                    .font(
                                        .system(
                                            size: bubbleFontSize(theme.count),
                                            weight: theme.count > 3 ? .semibold : .medium,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundStyle(KlunaWarm.warmBrown)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: 210, alignment: .leading)
                            .padding(.horizontal, bubblePadding(theme.count))
                            .padding(.vertical, bubblePadding(theme.count) * 0.6)
                            .background(
                                Capsule().fill(
                                    theme.dominantMoodColor.opacity(
                                        expandedTheme == theme.name ? 0.12 : 0.06
                                    )
                                )
                            )
                            .scaleEffect(expandedTheme == theme.name ? 1.05 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .opacity(didAppear ? 1 : 0)
                        .scaleEffect(didAppear ? 1 : 0.92)
                        .offset(y: didAppear ? 0 : 8)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.84).delay(Double(index) * 0.03),
                            value: didAppear
                        )
                    }
                }

                if let name = expandedTheme,
                   let theme = aggregates.first(where: { $0.name == name }) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(String(format: "insights.mentioned_count".localized, theme.count))
                                .font(.system(.caption, design: .rounded).weight(.medium))
                                .foregroundStyle(theme.dominantMoodColor)
                            Spacer()
                            Text(theme.dominantMoodLabel)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                        }

                        ForEach(theme.relatedEntries.prefix(3)) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(entry.stimmungsfarbe)
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.date.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                                    Text(entry.transcript)
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.dominantMoodColor.opacity(0.05))
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.84)) {
                didAppear = true
            }
        }
    }

    private func bubbleFontSize(_ count: Int) -> CGFloat {
        switch count {
        case 1: return 13
        case 2...3: return 15
        case 4...6: return 17
        default: return 19
        }
    }

    private func bubblePadding(_ count: Int) -> CGFloat {
        switch count {
        case 1: return 10
        case 2...3: return 12
        case 4...6: return 14
        default: return 16
        }
    }

    private func wrappedThemeName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 14, !trimmed.contains("\n") else { return trimmed }
        let words = trimmed.split(separator: " ").map(String.init)
        guard words.count >= 2 else { return trimmed }
        let mid = words.count / 2
        let first = words[..<mid].joined(separator: " ")
        let second = words[mid...].joined(separator: " ")
        return "\(first)\n\(second)"
    }
}

private struct InsightsFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: .init(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        let size: CGSize
        let positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return ArrangeResult(
            size: CGSize(width: maxWidth, height: y + rowHeight),
            positions: positions
        )
    }
}

private struct PatternSectionV2: View {
    let patterns: [StimmPatternV2]

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("insights.kluna_observes".localized)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)

                ForEach(patterns) { pattern in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(pattern.color.opacity(0.08))
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: pattern.icon).font(.system(size: 14)).foregroundStyle(pattern.color))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(pattern.title)
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(KlunaWarm.warmBrown)
                                Text("\(pattern.confidence)%")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(pattern.color)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(pattern.color.opacity(0.10)))
                            }
                            Text(pattern.description)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                                .lineSpacing(3)
                        }
                    }
                }
            }
        }
    }
}

private struct TrendSectionV2: View {
    let dailyAverages: [(date: Date, dims: VoiceDimensions)]
    @State private var selected = 0

    private let labels = ["Energie", "Anspannung", "Müdigkeit", "Wärme", "Lebendigkeit", "Tempo"]
    private let colors: [Color] = [
        Color(hex: "F5B731"), Color(hex: "E85C5C"), Color(hex: "8B9DAF"),
        Color(hex: "E8825C"), Color(hex: "6BC5A0"), Color(hex: "7BA7C4"),
    ]

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("insights.your_trend".localized)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(labels.indices, id: \.self) { idx in
                            Text(labels[idx])
                                .font(.system(.caption, design: .rounded).weight(selected == idx ? .semibold : .regular))
                                .foregroundStyle(selected == idx ? .white : KlunaWarm.warmBrown.opacity(0.45))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(selected == idx ? colors[idx] : KlunaWarm.warmBrown.opacity(0.06)))
                                .onTapGesture { withAnimation(.spring(response: 0.3)) { selected = idx } }
                        }
                    }
                }

                SmoothCurve(dataPoints: selectedPoints(), color: colors[selected], progress: 1)
                    .frame(height: 110)

                HStack {
                    ForEach(Array(dailyAverages.enumerated()), id: \.offset) { idx, item in
                        Text(shortLabel(item.date))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(idx == dailyAverages.count - 1 ? 0.45 : 0.28))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func selectedPoints() -> [CGFloat] {
        dailyAverages.map { pair in
            switch selected {
            case 0: return pair.dims.energy
            case 1: return pair.dims.tension
            case 2: return pair.dims.fatigue
            case 3: return pair.dims.warmth
            case 4: return pair.dims.expressiveness
            default: return pair.dims.tempo
            }
        }
    }

    private func shortLabel(_ date: Date) -> String {
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return date.formatted(.dateTime.weekday(.narrow))
        }
        return date.formatted(.dateTime.day())
    }
}

private struct ClaudeSummarySectionV2: View {
    let title: String
    let text: String

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Text(text)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.72))
                    .lineSpacing(4)
            }
        }
    }
}

private struct KlunaKnowsYouSection: View {
    @ObservedObject var memory: KlunaMemory
    @State private var expandedLayer: Int?

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("✨")
                        .font(.system(size: 16))
                    Text("insights.kluna_knows_you".localized)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Spacer()
                    Text(String(format: "insights.entries_count".localized, memory.entryCount))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
                }

                ForEach(Array(memory.layersForUI.enumerated()), id: \.offset) { index, layer in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                expandedLayer = expandedLayer == index ? nil : index
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: layer.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(KlunaWarm.warmAccent)
                                    .frame(width: 22)
                                Text(layer.title)
                                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.75))
                                Spacer()
                                Image(systemName: expandedLayer == index ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.18))
                            }
                        }
                        .buttonStyle(.plain)

                        if expandedLayer == index {
                            Text(layer.text)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                                .lineSpacing(5)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.vertical, 2)
                }

                if memory.entryCount < 5 {
                    lockedLayer(title: "Deine Muster", icon: "heart.fill", hint: "Ab 5 Eintraegen")
                    lockedLayer(title: "Was Kluna vorhersieht", icon: "eye.fill", hint: "Ab 5 Eintraegen")
                }
                if memory.entryCount < 10 {
                    lockedLayer(title: "Wer du bist", icon: "sparkles", hint: "Ab 10 Eintraegen")
                }
            }
        }
    }

    @ViewBuilder
    private func lockedLayer(title: String, icon: String, hint: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.18))
                .frame(width: 22)
            Text(title)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
            Spacer()
            Text(hint)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.16))
            Image(systemName: "lock.fill")
                .font(.system(size: 9))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.14))
        }
        .padding(.vertical, 2)
    }

    private func stripMarkdown(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "### ", with: "")
        result = result.replacingOccurrences(of: "## ", with: "")
        result = result.replacingOccurrences(of: "# ", with: "")

        let fullRange = NSRange(result.startIndex..., in: result)
        if let boldPattern = try? NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*") {
            result = boldPattern.stringByReplacingMatches(in: result, range: fullRange, withTemplate: "$1")
        }
        if let italicPattern = try? NSRegularExpression(pattern: "\\*(.*?)\\*") {
            result = italicPattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1")
        }
        result = result.replacingOccurrences(of: "\n- ", with: "\n")
        result = result.replacingOccurrences(of: "\n* ", with: "\n")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct LockedInsightCard: View {
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(KlunaWarm.warmBrown.opacity(0.04))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: icon).font(.system(size: 17)).foregroundStyle(KlunaWarm.warmBrown.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.28))
                Text(description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.18))
            }
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.14))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(KlunaWarm.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(KlunaWarm.warmBrown.opacity(0.03), lineWidth: 1)
                )
        )
    }
}

private struct StimmPatternV2: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let color: Color
    let confidence: Int
    let colorHint: String

    init(icon: String, title: String, description: String, color: Color, confidence: Int, colorKey: String = "orange") {
        self.icon = icon
        self.title = title
        self.description = description
        self.color = color
        self.confidence = confidence
        self.colorHint = colorKey
    }
}

// MARK: - Locked / Paywall

struct InsightsLockedView: View {
    let currentCount: Int
    let needed: Int

    var body: some View {
        VStack(spacing: 18) {
            Text("✨ \("insights.title_v2".localized)")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(KlunaWarm.warmBrown)
            Text(String(format: "insights.progress_of".localized, currentCount, needed))
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            Text(String(format: "insights.first_patterns_after".localized, needed))
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KlunaWarm.background.ignoresSafeArea())
    }
}

struct InsightsPaywallView: View {
    let entryCount: Int

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 42))
                .foregroundStyle(KlunaWarm.warmAccent)
            Text("insights.patterns_waiting".localized)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(KlunaWarm.warmBrown)
            Text(String(format: "insights.patterns_premium_teaser".localized, entryCount))
                .font(.system(.body, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
            Button("insights.premium_cta".localized) {}
                .buttonStyle(.borderedProminent)
                .tint(KlunaWarm.warmAccent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KlunaWarm.background.ignoresSafeArea())
    }
}

// MARK: - Mood Ring

struct MoodRingSection: View {
    let entries: [JournalEntry]
    let monthDate: Date
    let monthWord: String
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    @State private var selectedDay: Int?
    @State private var animationProgress: CGFloat = 0

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: monthDate)?.count ?? 30
    }

    var body: some View {
        WarmCard {
            VStack(spacing: 16) {
                HStack {
                    Button(action: onPreviousMonth) { Image(systemName: "chevron.left") }
                    Spacer()
                    Text("insights.your_month".localized)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Spacer()
                    Button(action: onNextMonth) { Image(systemName: "chevron.right") }
                }
                .tint(KlunaWarm.warmBrown)

                ZStack {
                    ForEach(0..<daysInMonth, id: \.self) { day in
                        MoodRingSegment(
                            day: day,
                            totalDays: daysInMonth,
                            entry: entryForDay(day),
                            isSelected: selectedDay == day,
                            animationProgress: animationProgress
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedDay = selectedDay == day ? nil : day
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        Text(monthWord)
                            .font(.system(.title2, design: .rounded).weight(.semibold))
                            .foregroundStyle(KlunaWarm.warmBrown)
                        Text(monthDate.formatted(.dateTime.month(.wide).year()))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    }

                    if let day = selectedDay, let entry = entryForDay(day) {
                        MoodRingPopup(entry: entry)
                            .offset(y: -120)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 280, height: 280)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            if value.translation.width < -40 { onNextMonth() }
                            if value.translation.width > 40 { onPreviousMonth() }
                        }
                )
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5)) { animationProgress = 1.0 }
                }
            }
        }
    }

    private func entryForDay(_ day: Int) -> JournalEntry? {
        let dayNum = day + 1
        return entries.first {
            Calendar.current.component(.day, from: $0.date) == dayNum
        }
    }
}

struct MoodRingSegment: View {
    let day: Int
    let totalDays: Int
    let entry: JournalEntry?
    let isSelected: Bool
    let animationProgress: CGFloat

    var body: some View {
        let rotation = Double(day) * (360.0 / Double(totalDays))
        let progressVisible = CGFloat(day + 1) / CGFloat(totalDays) <= animationProgress
        let c = entry?.stimmungsfarbe ?? KlunaWarm.warmBrown.opacity(0.06)
        return Circle()
            .trim(from: 0, to: (1.0 / CGFloat(totalDays)) - 0.004)
            .stroke(c, style: StrokeStyle(lineWidth: isSelected ? 28 : 22, lineCap: .round))
            .frame(width: 240, height: 240)
            .rotationEffect(.degrees(rotation - 90))
            .opacity(progressVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(Double(day) * 0.03), value: animationProgress)
    }
}

struct MoodRingPopup: View {
    let entry: JournalEntry

    var body: some View {
        VStack(spacing: 4) {
            Text(entry.date.formatted(.dateTime.day().month(.wide)))
                .font(.system(.caption, design: .rounded).weight(.semibold))
            Text(entry.moodLabel ?? entry.quadrant.label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            Text(String(entry.transcript.prefix(40)) + "…")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Week Overview

struct WeekOverviewSection: View {
    let weekStart: Date
    let weekEntries: [JournalEntry]
    let weekSummary: String
    let onPreviousWeek: () -> Void
    let onNextWeek: () -> Void
    @State private var selectedDayIndex: Int?
    @State private var appeared = false

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(action: onPreviousWeek) { Image(systemName: "chevron.left") }
                    Text("insights.your_week".localized)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                    Spacer()
                    Text(weekTitle)
                        .font(.system(.caption, design: .rounded))
                    Button(action: onNextWeek) { Image(systemName: "chevron.right") }
                }
                .foregroundStyle(KlunaWarm.warmBrown)

                HStack(spacing: 10) {
                    ForEach(0..<7, id: \.self) { index in
                        let entry = entryForWeekday(index)
                        VStack(spacing: 6) {
                            Text(weekdayLabel(index))
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                            DayMoodRing(entry: entry)
                                .scaleEffect(selectedDayIndex == index ? 1.18 : 1.0)
                                .scaleEffect(appeared ? 1.0 : 0.3)
                                .opacity(appeared ? 1.0 : 0)
                                .animation(.spring(response: 0.4).delay(Double(index) * 0.08), value: appeared)
                                .onTapGesture {
                                    guard entry != nil else { return }
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedDayIndex = selectedDayIndex == index ? nil : index
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 24)
                        .onEnded { value in
                            if value.translation.width < -40 { onNextWeek() }
                            if value.translation.width > 40 { onPreviousWeek() }
                        }
                )

                if let idx = selectedDayIndex, let entry = entryForWeekday(idx) {
                    ExpandedDayCard(entry: entry)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.quote")
                        .foregroundStyle(KlunaWarm.warmAccent)
                    Text(weekSummary)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.7))
                        .lineSpacing(4)
                }
            }
            .onAppear { appeared = true }
        }
    }

    private var weekTitle: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(weekStart.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private func entryForWeekday(_ index: Int) -> JournalEntry? {
        let day = Calendar.current.date(byAdding: .day, value: index, to: weekStart) ?? weekStart
        return weekEntries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) })
    }

    private func weekdayLabel(_ index: Int) -> String {
        let day = Calendar.current.date(byAdding: .day, value: index, to: weekStart) ?? weekStart
        return day.formatted(.dateTime.weekday(.narrow))
    }
}

struct DayMoodRing: View {
    let entry: JournalEntry?

    var body: some View {
        ZStack {
            Circle()
                .stroke(entry?.stimmungsfarbe ?? KlunaWarm.warmBrown.opacity(0.04), lineWidth: entry == nil ? 0.5 : 3)
                .frame(width: 40, height: 40)
            if let e = entry {
                let size = max(8, min(34, 34 * CGFloat(e.arousal / 100)))
                Circle()
                    .fill(e.stimmungsfarbe.opacity(0.3))
                    .frame(width: size, height: size)
            }
        }
    }
}

struct ExpandedDayCard: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(entry.stimmungsfarbe).frame(width: 10, height: 10)
                Text(entry.moodLabel ?? entry.quadrant.label)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Spacer()
                Text(entry.date.formatted(.dateTime.hour().minute()))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            }
            Text(entry.transcript)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            if let coach = entry.coachText, !coach.isEmpty {
                Text("✨ \(coach)")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(entry.stimmungsfarbe.opacity(0.08))
        )
    }
}

// MARK: - Graph

struct EmotionGraphSection: View {
    let entries: [JournalEntry]
    @State private var selectedEntry: JournalEntry?
    @State private var touchLocation: CGFloat?
    @State private var drawProgress: CGFloat = 0
    @State private var showEnergy = true
    @State private var graphWidth: CGFloat = 1

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("insights.your_trend".localized)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Spacer()
                    TogglePill(label: "Energie", isOn: $showEnergy, color: KlunaWarm.warmAccent)
                }

                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [KlunaWarm.warmAccent.opacity(0.03), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    if showEnergy {
                        SmoothCurve(dataPoints: entries.map { CGFloat($0.arousal / 100) }, color: KlunaWarm.warmAccent, progress: drawProgress)
                            .frame(height: 130)
                            .padding(.top, 10)
                    }

                    StimmungsFarbband(entries: entries)
                        .frame(height: 20)
                        .offset(y: -4)

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    touchLocation = value.location.x
                                    selectedEntry = entryAtX(value.location.x)
                                }
                                .onEnded { _ in
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        touchLocation = nil
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { selectedEntry = nil }
                                    }
                                }
                        )

                    if let entry = selectedEntry, let x = touchLocation {
                        GraphTooltip(entry: entry)
                            .position(x: min(max(x, 80), max(80, graphWidth - 80)), y: 20)
                    }

                    if let x = touchLocation {
                        Rectangle()
                            .fill(KlunaWarm.warmBrown.opacity(0.15))
                            .frame(width: 1, height: 160)
                            .offset(x: x)
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { graphWidth = geo.size.width }
                    }
                )
                .frame(height: 160)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5)) { drawProgress = 1.0 }
                }

                HStack(spacing: 16) {
                    if showEnergy {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(KlunaWarm.warmAccent)
                                .frame(width: 16, height: 2)
                            Text("dim.energy".localized)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                        }
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [KlunaWarm.begeistert, KlunaWarm.zufrieden, KlunaWarm.aufgewuehlt],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 16, height: 6)
                        Text("home.mood_fallback".localized)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    }
                }
            }
        }
    }

    private func entryAtX(_ x: CGFloat) -> JournalEntry? {
        guard !entries.isEmpty else { return nil }
        let clamped = max(0, min(graphWidth, x))
        let ratio = clamped / max(1, graphWidth)
        let idx = min(entries.count - 1, max(0, Int(ratio * CGFloat(entries.count))))
        return entries[idx]
    }
}

struct StimmungsFarbband: View {
    let entries: [JournalEntry]

    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 2) {
                ForEach(entries, id: \.id) { entry in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(entry.stimmungsfarbe)
                        .frame(maxWidth: .infinity)
                }
            }
            .clipShape(Capsule())
        }
    }
}

struct SmoothCurve: View {
    let dataPoints: [CGFloat]
    let color: Color
    let progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            Path { path in
                guard dataPoints.count > 1 else { return }
                let stepX = width / CGFloat(dataPoints.count - 1)
                path.move(to: CGPoint(x: 0, y: height * (1 - dataPoints[0])))
                for i in 1..<dataPoints.count {
                    let x = stepX * CGFloat(i)
                    let y = height * (1 - dataPoints[i])
                    let prevX = stepX * CGFloat(i - 1)
                    let prevY = height * (1 - dataPoints[i - 1])
                    let midX = (prevX + x) / 2
                    path.addCurve(
                        to: CGPoint(x: x, y: y),
                        control1: CGPoint(x: midX, y: prevY),
                        control2: CGPoint(x: midX, y: y)
                    )
                }
            }
            .trim(from: 0, to: progress)
            .stroke(
                LinearGradient(colors: [color.opacity(0.4), color], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )
        }
    }
}

struct GraphTooltip: View {
    let entry: JournalEntry

    var body: some View {
        VStack(spacing: 4) {
            Text(entry.date.formatted(.dateTime.day().month(.abbreviated)))
                .font(.system(.caption2, design: .rounded).weight(.semibold))
            HStack(spacing: 4) {
                Circle().fill(entry.stimmungsfarbe).frame(width: 6, height: 6)
                Text(entry.moodLabel ?? entry.quadrant.label)
                    .font(.system(.caption2, design: .rounded))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }
}

struct TogglePill: View {
    let label: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        Text(label)
            .font(.system(.caption2, design: .rounded).weight(.medium))
            .foregroundStyle(isOn ? Color.white : color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(isOn ? color : color.opacity(0.12)))
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isOn.toggle() }
            }
    }
}

// MARK: - Themes

struct VoiceTheme: Identifiable {
    let id: String
    let name: String
    let count: Int
    let averageMoodColor: Color
    let trend: ThemeTrend
    let relatedEntries: [JournalEntry]
    let averageArousal: Float
}

enum ThemeTrend {
    case improving
    case declining
    case stable

    init(raw: String) {
        switch raw.lowercased() {
        case "improving": self = .improving
        case "declining": self = .declining
        default: self = .stable
        }
    }

    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .declining: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .improving: return "Wird besser"
        case .declining: return "Belastet dich"
        case .stable: return "Stabil"
        }
    }
}

struct ThemeAggregate: Identifiable {
    let id: String
    let name: String
    let count: Int
    let dominantMoodLabel: String
    let dominantMoodColor: Color
    let trend: ThemeTrend
    let averageArousal: Float
    let relatedEntries: [JournalEntry]

    init(theme: VoiceTheme) {
        let entries = theme.relatedEntries
        let groupedByMood = Dictionary(grouping: entries) { $0.quadrant.rawValue }
        let dominant = groupedByMood.max(by: { $0.value.count < $1.value.count })?.value.first

        id = theme.id
        name = theme.name
        count = theme.count
        trend = theme.trend
        averageArousal = theme.averageArousal
        relatedEntries = entries
        dominantMoodLabel = dominant?.moodLabel ?? dominant?.quadrant.label ?? "Ausgeglichen"
        dominantMoodColor = dominant?.stimmungsfarbe ?? theme.averageMoodColor
    }
}

struct ThemeInsightsSection: View {
    let themes: [VoiceTheme]
    var onThemeSelected: (() -> Void)? = nil
    @State private var selectedThemeId: String?
    @State private var didAppear = false

    private let columns = [GridItem(.adaptive(minimum: 116), spacing: 10)]

    private var aggregates: [ThemeAggregate] {
        themes
            .map(ThemeAggregate.init)
            .sorted {
                if $0.count == $1.count {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("insights.theme_tags".localized)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)

                if aggregates.isEmpty {
                    Text("insights.no_themes".localized)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(Array(aggregates.enumerated()), id: \.element.id) { index, aggregate in
                            ThemeAggregateBubble(
                                aggregate: aggregate,
                                isSelected: selectedThemeId == aggregate.id,
                                isVisible: didAppear,
                                animationDelay: Double(index) * 0.05
                            )
                            .onTapGesture {
                                let willOpen = selectedThemeId != aggregate.id
                                if willOpen {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } else {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                }
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                    selectedThemeId = selectedThemeId == aggregate.id ? nil : aggregate.id
                                }
                                if selectedThemeId != nil {
                                    onThemeSelected?()
                                }
                            }
                        }
                    }
                }

                if let selected = aggregates.first(where: { $0.id == selectedThemeId }) {
                    ThemeAggregateDetailCard(aggregate: selected)
                        .id("theme-insights-detail-anchor")
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.84)) {
                didAppear = true
            }
        }
    }
}

struct ThemeAggregateBubble: View {
    let aggregate: ThemeAggregate
    let isSelected: Bool
    let isVisible: Bool
    let animationDelay: Double

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(aggregate.dominantMoodColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(aggregate.name)
                    .font(.system(size: 13 + sizeBoost, weight: isSelected ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 4) {
                    Image(systemName: aggregate.trend.icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(aggregate.count)x")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 42 + sizeBoost * 2)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 10)
        .animation(
            .spring(response: 0.48, dampingFraction: 0.83).delay(animationDelay),
            value: isVisible
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? aggregate.dominantMoodColor.opacity(0.14) : KlunaWarm.warmBrown.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected ? aggregate.dominantMoodColor.opacity(0.32) : .clear,
                            lineWidth: 1
                        )
                )
        )
    }

    private var sizeBoost: CGFloat {
        Swift.min(CGFloat(aggregate.count) * 1.2, 7)
    }
}

struct ThemeAggregateDetailCard: View {
    let aggregate: ThemeAggregate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(aggregate.name)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: aggregate.trend.icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(aggregate.trend.label)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(aggregate.dominantMoodColor)
            }

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(aggregate.count)x")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Text("insights.in_this_week".localized)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(aggregate.dominantMoodLabel)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(aggregate.dominantMoodColor)
                    Text("insights.dominant_mood".localized)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(aggregate.averageArousal.rounded()))")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Text("insights.avg_energy_short".localized)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                }
            }

            ForEach(aggregate.relatedEntries.prefix(2)) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(entry.stimmungsfarbe)
                            .frame(width: 6, height: 6)
                        Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    }
                    Text(entry.transcript)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.68))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(aggregate.dominantMoodColor.opacity(0.08))
        )
    }
}

// MARK: - Carousel

struct Insight: Identifiable {
    let id: String
    let icon: String
    let accentColor: Color
    let title: String
    let body: String
    let relatedEntryIds: [UUID]
}

struct InsightCarouselSection: View {
    let insights: [Insight]
    @State private var currentIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insights.kluna_says".localized)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(KlunaWarm.warmBrown)
                .padding(.horizontal, 6)

            TabView(selection: $currentIndex) {
                ForEach(insights.indices, id: \.self) { index in
                    InsightSlide(insight: insights[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 175)
        }
    }
}

struct InsightSlide: View {
    let insight: Insight

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(insight.accentColor)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(insight.accentColor.opacity(0.1)))
                    Text(insight.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                }
                Text(insight.body)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.75))
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Monthly Letter

struct MonthlyLetterTeaser: View {
    let month: String
    let text: String
    let openAction: () -> Void

    var body: some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("insights.monthly_letter".localized)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Text(month)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                Text(text)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.78))
                    .lineSpacing(5)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: openAction) {
                    Label("insights.open_monthly_letter".localized, systemImage: "doc.text")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(KlunaWarm.warmAccent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MonthlyLetterSheet: View {
    let month: String
    let monthWord: String
    let entries: [JournalEntry]
    let letterText: String
    let highlights: MonthHighlights

    @Environment(\.dismiss) private var dismiss
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text(String(format: "insights.your_month_named".localized, month))
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(KlunaWarm.warmBrown)
                        Text("insights.letter_from_kluna".localized)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    }
                    .padding(.top, 24)

                    MoodRingSection(
                        entries: entries,
                        monthDate: Date(),
                        monthWord: monthWord,
                        onPreviousMonth: {},
                        onNextMonth: {}
                    )
                    .allowsHitTesting(false)
                    .scaleEffect(0.84)

                    Text(letterText)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                        .lineSpacing(8)
                        .padding(.horizontal, 26)

                    VStack(spacing: 14) {
                        Text("insights.moments".localized)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(KlunaWarm.warmBrown)

                        if let best = highlights.bestDay {
                            HighlightCard(icon: "sun.max.fill", color: KlunaWarm.begeistert, title: "insights.best_day".localized, entry: best)
                        }
                        if let hardest = highlights.hardestDay {
                            HighlightCard(icon: "cloud.rain.fill", color: KlunaWarm.erschoepft, title: "insights.hardest_day".localized, entry: hardest)
                        }
                        if let turning = highlights.turningPoint {
                            HighlightCard(icon: "arrow.triangle.turn.up.right.diamond.fill", color: KlunaWarm.warmAccent, title: "insights.turning_point".localized, entry: turning)
                        }
                    }
                    .padding(.horizontal, 20)

                    Button {
                        let card = MonthlyLetterShareCard(month: month, monthWord: monthWord, text: letterText)
                        let renderer = ImageRenderer(content: card)
                        renderer.scale = UIScreen.main.scale
                        if let image = renderer.uiImage {
                            shareItems = [image]
                            showShare = true
                        } else {
                            shareItems = [letterText]
                            showShare = true
                        }
                    } label: {
                        Label("insights.share_monthly_letter".localized, systemImage: "square.and.arrow.up")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(KlunaWarm.warmAccent)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Capsule().stroke(KlunaWarm.warmAccent, lineWidth: 1))
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(KlunaWarm.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("home.done".localized) { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                ActivityViewController(items: shareItems)
            }
        }
    }
}

struct MonthlyLetterShareCard: View {
    let month: String
    let monthWord: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("insights.monthly_letter_share_title".localized)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(KlunaWarm.warmBrown)
            Text(month)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            Text(monthWord)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmAccent)
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.85))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 720, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(KlunaWarm.cardBackground)
        )
    }
}

struct HighlightCard: View {
    let icon: String
    let color: Color
    let title: String
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(Circle().fill(color.opacity(0.1)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(color)
                Text(entry.date.formatted(.dateTime.day().month(.wide)))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Text(String(entry.transcript.prefix(60)) + "…")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(color.opacity(0.06))
        )
    }
}

struct VoiceLandmapSection: View {
    let reactions: [MentionReaction]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("insights.voice_map".localized)
                .font(.system(.headline, design: .rounded))
                .foregroundColor(KlunaWarm.warmBrown)

            Text("insights.voice_map_subtitle".localized)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(KlunaWarm.warmBrown.opacity(0.3))

            ForEach(Array(reactions.prefix(6)), id: \.mention) { reaction in
                ReactionRow(reaction: reaction)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }
}

struct ReactionRow: View {
    let reaction: MentionReaction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: reaction.mentionType == .person ? "person.fill" : "tag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(KlunaWarm.warmBrown.opacity(0.2))
                Text(reaction.mention.capitalized)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(KlunaWarm.warmBrown)
                Spacer()
                Text("\(reaction.occurrences)x")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(KlunaWarm.warmBrown.opacity(0.2))
            }

            HStack(spacing: 8) {
                MicroDim(label: "An", value: reaction.averageDimensions.tension, color: Color(hex: "E85C5C"))
                MicroDim(label: "W", value: reaction.averageDimensions.warmth, color: Color(hex: "E8825C"))
                MicroDim(label: "E", value: reaction.averageDimensions.energy, color: Color(hex: "F5B731"))
                MicroDim(label: "L", value: reaction.averageDimensions.expressiveness, color: Color(hex: "6BC5A0"))
            }

            if let trend = reaction.trend, abs(trend) > 0.08 {
                HStack(spacing: 4) {
                    Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                    Text(trend > 0 ? "Anspannung steigt bei diesem Thema" : "Wird entspannter bei diesem Thema")
                        .font(.system(size: 10, design: .rounded))
                }
                .foregroundColor(
                    trend > 0
                        ? Color(hex: "E85C5C").opacity(0.5)
                        : Color(hex: "6BC5A0").opacity(0.5)
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(KlunaWarm.warmBrown.opacity(0.02))
        )
    }
}

struct MicroDim: View {
    let label: String
    let value: Float
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(KlunaWarm.warmBrown.opacity(0.2))

            Capsule()
                .fill(KlunaWarm.warmBrown.opacity(0.04))
                .frame(width: 40, height: 3)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.5))
                        .frame(width: 40 * CGFloat(max(0, min(1, value))), height: 3)
                }
        }
    }
}

struct MonthHighlights {
    let bestDay: JournalEntry?
    let hardestDay: JournalEntry?
    let turningPoint: JournalEntry?

    static func from(entries: [JournalEntry]) -> MonthHighlights {
        let sorted = entries.sorted(by: { $0.date < $1.date })
        let best = sorted.max(by: { $0.acousticValence < $1.acousticValence })
        let hardest = sorted.min(by: { $0.acousticValence < $1.acousticValence })

        var turning: JournalEntry?
        var biggestDelta: Float = 0
        if sorted.count >= 2 {
            for i in 1..<sorted.count {
                let delta = sorted[i].acousticValence - sorted[i - 1].acousticValence
                if delta > biggestDelta {
                    biggestDelta = delta
                    turning = sorted[i]
                }
            }
        }
        return .init(bestDay: best, hardestDay: hardest, turningPoint: turning)
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

