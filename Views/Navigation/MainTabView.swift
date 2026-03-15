import SwiftUI
import UIKit
import CoreData
import UserNotifications

extension Notification.Name {
    static let klunaOpenVoiceTab = Notification.Name("kluna_open_voice_tab")
    static let klunaOpenHomeTab = Notification.Name("kluna_open_home_tab")
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @ObservedObject private var badgeManager = BadgeManager.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("tab.home".localized)
                }
                .tag(0)

            JournalCalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("tab.calendar".localized)
                }
                .tag(1)

            MeView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("tab.me".localized)
                }
                .tag(2)

            JournalProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("tab.profile".localized)
                }
                .tag(3)
        }
        .tint(KlunaWarm.warmAccent)
        .onReceive(NotificationCenter.default.publisher(for: .klunaOpenVoiceTab)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedTab = 2
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .klunaOpenHomeTab)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                selectedTab = 0
            }
        }
        .onAppear {
            configureTabBarAppearance()
            MonthlyLetterManager.shared.checkForNewLetter()
        }
        .overlay {
            if let badge = badgeManager.newlyUnlocked {
                BadgeUnlockOverlay(
                    badge: badge,
                    onShare: {
                        ShareABManager.shared.trackTap(.milestone)
                        ShareImageGenerator.share(
                            content: .milestone(
                                MilestoneShareData(
                                    title: badge.title,
                                    subtitle: badge.description,
                                    icon: "star.fill",
                                    color: badge.category.color,
                                    date: badge.unlockedDate ?? Date(),
                                    streakCount: nil,
                                    entryCount: nil
                                )
                            )
                        )
                        badgeManager.dismissUnlockedBadge()
                    },
                    onDismiss: {
                        badgeManager.dismissUnlockedBadge()
                    }
                )
            }
        }
    }

    private func configureTabBarAppearance() {
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(KlunaWarm.cardBackground)

        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(KlunaWarm.warmBrown.opacity(0.4))
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(KlunaWarm.warmBrown.opacity(0.4)),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]

        let accentUI = UIColor(KlunaWarm.warmAccent)
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = accentUI
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: accentUI,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

struct BadgeUnlockOverlay: View {
    let badge: Badge
    let onShare: () -> Void
    let onDismiss: () -> Void

    @State private var showEmoji = false
    @State private var showTitle = false
    @State private var showDesc = false
    @State private var showButtons = false
    @State private var emojiScale: CGFloat = 0.1
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: CGFloat = 0.6
    @State private var particlesVisible = false

    var body: some View {
        ZStack {
            KlunaWarm.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [badge.category.color.opacity(0.06), .clear],
                center: .center,
                startRadius: 50,
                endRadius: 350
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        Circle()
                            .fill(badge.category.color.opacity(0.5))
                            .frame(width: 6, height: 6)
                            .offset(
                                x: particlesVisible ? cos(CGFloat(index) / 12 * .pi * 2) * 130 : 0,
                                y: particlesVisible ? sin(CGFloat(index) / 12 * .pi * 2) * 130 : 0
                            )
                            .opacity(particlesVisible ? 0 : 0.8)
                    }

                    Circle()
                        .stroke(badge.category.color.opacity(ringOpacity), lineWidth: 3)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [badge.category.color.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .opacity(showEmoji ? 1 : 0)

                    Text(badge.emoji)
                        .font(.system(size: 96))
                        .scaleEffect(emojiScale)
                }

                Spacer().frame(height: 36)

                Text(badge.title)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(KlunaWarm.warmBrown)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)

                Spacer().frame(height: 10)

                Text(badge.description)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(KlunaWarm.warmBrown.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 48)
                    .opacity(showDesc ? 1 : 0)
                    .offset(y: showDesc ? 0 : 15)

                if let date = badge.unlockedDate {
                    Text(date, format: .dateTime.day().month(.wide).year())
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(badge.category.color.opacity(0.4))
                        .padding(.top, 8)
                        .opacity(showDesc ? 1 : 0)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button(action: onShare) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Teilen")
                                .font(.system(.headline, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(badge.category.color)
                                .shadow(color: badge.category.color.opacity(0.3), radius: 12, x: 0, y: 6)
                        )
                    }
                    .padding(.horizontal, 48)

                    Button(action: onDismiss) {
                        Text("Weiter")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(KlunaWarm.warmBrown.opacity(0.25))
                    }
                }
                .opacity(showButtons ? 1 : 0)

                Spacer().frame(height: 60)
            }
        }
        .onAppear(perform: animateUnlock)
    }

    private func animateUnlock() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2)) {
            showEmoji = true
            emojiScale = 1.0
        }

        ringOpacity = 0.6
        withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
            ringScale = 2.5
            ringOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            particlesVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.7)) { showTitle = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.9)) { showDesc = true }
        withAnimation(.easeOut(duration: 0.4).delay(1.3)) { showButtons = true }
    }
}

struct VoiceView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var dataManager = KlunaDataManager.shared
    @State private var selectedSignatureEntryID: UUID?

    private var latestEntry: JournalEntry? {
        dataManager.entries.sorted(by: { $0.date > $1.date }).first
    }

    private var todayEntries: [JournalEntry] {
        dataManager.entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted(by: { $0.date > $1.date })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Text("Stimme")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let latestEntry {
                        let selected = selectedDimensions()
                        let normal = baselineDimensions()
                        SignatureSection(
                            todayEntries: todayEntries,
                            latestEntry: latestEntry,
                            selectedEntryID: $selectedSignatureEntryID
                        )

                        VoiceRadarSection(
                            dimensions: selected,
                            normal: normal,
                            trends: dimensionTrends(for: selected)
                        )

                        if subscriptionManager.isProUser {
                            VoiceComparisonSection(
                                today: selected,
                                lastWeekAvg: normal,
                                todayColor: latestEntry.stimmungsfarbe
                            )
                        } else {
                            PremiumTeaser(
                                title: "Stimm-Vergleich",
                                description: "Vergleiche deine Stimme mit letzter Woche."
                            )
                        }
                    } else {
                        EmptyVoiceView()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(KlunaWarm.background.ignoresSafeArea())
            .refreshable {
                reload()
            }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        dataManager.refresh(limit: 160)
    }

    private func averageDimensionsLastWeek() -> VoiceDimensions {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekEntries = dataManager.entries.filter { $0.date >= start }
        guard !weekEntries.isEmpty else {
            return .init(energy: 0.5, tension: 0.5, fatigue: 0.5, warmth: 0.5, expressiveness: 0.5, tempo: 0.5)
        }
        let dims = weekEntries.map(VoiceDimensions.from)
        let count = CGFloat(dims.count)
        return .init(
            energy: dims.map(\.energy).reduce(0, +) / count,
            tension: dims.map(\.tension).reduce(0, +) / count,
            fatigue: dims.map(\.fatigue).reduce(0, +) / count,
            warmth: dims.map(\.warmth).reduce(0, +) / count,
            expressiveness: dims.map(\.expressiveness).reduce(0, +) / count,
            tempo: dims.map(\.tempo).reduce(0, +) / count,
        )
    }

    private func baselineDimensions() -> VoiceDimensions {
        let nonToday = dataManager.entries.filter { !Calendar.current.isDateInToday($0.date) }
        let source = nonToday.isEmpty ? dataManager.entries : nonToday
        guard !source.isEmpty else {
            return .init(energy: 0.5, tension: 0.5, fatigue: 0.5, warmth: 0.5, expressiveness: 0.5, tempo: 0.5)
        }
        let dims = source.prefix(30).map(VoiceDimensions.from)
        let count = CGFloat(max(1, dims.count))
        return .init(
            energy: dims.map(\.energy).reduce(0, +) / count,
            tension: dims.map(\.tension).reduce(0, +) / count,
            fatigue: dims.map(\.fatigue).reduce(0, +) / count,
            warmth: dims.map(\.warmth).reduce(0, +) / count,
            expressiveness: dims.map(\.expressiveness).reduce(0, +) / count,
            tempo: dims.map(\.tempo).reduce(0, +) / count
        )
    }

    private func selectedDimensions() -> VoiceDimensions {
        if let id = selectedSignatureEntryID,
           let selected = dataManager.entries.first(where: { $0.id == id }) {
            return VoiceDimensions.from(selected)
        }
        if !todayEntries.isEmpty {
            let dims = todayEntries.map(VoiceDimensions.from)
            let count = CGFloat(max(1, dims.count))
            return .init(
                energy: dims.map(\.energy).reduce(0, +) / count,
                tension: dims.map(\.tension).reduce(0, +) / count,
                fatigue: dims.map(\.fatigue).reduce(0, +) / count,
                warmth: dims.map(\.warmth).reduce(0, +) / count,
                expressiveness: dims.map(\.expressiveness).reduce(0, +) / count,
                tempo: dims.map(\.tempo).reduce(0, +) / count
            )
        }
        if let latestEntry {
            return VoiceDimensions.from(latestEntry)
        }
        return .init(energy: 0.5, tension: 0.5, fatigue: 0.5, warmth: 0.5, expressiveness: 0.5, tempo: 0.5)
    }

    private func dimensionTrends(for current: VoiceDimensions) -> [String: VoiceDimensionTrend] {
        let source = dataManager.entries
            .filter { !Calendar.current.isDateInToday($0.date) }
            .sorted(by: { $0.date < $1.date })
            .map(VoiceDimensions.from)

        func ewmaStats(
            _ key: String,
            extract: (VoiceDimensions) -> CGFloat,
            currentValue: CGFloat
        ) -> VoiceDimensionTrend {
            let alpha: CGFloat = 0.1
            let minCount = 5
            guard !source.isEmpty else {
                return VoiceDimensionTrend(baseline: nil, zScore: nil)
            }
            var mean: CGFloat = 0
            var variance: CGFloat = 0
            var count = 0
            for dim in source {
                let value = extract(dim)
                if count == 0 {
                    mean = value
                    variance = 0
                    count = 1
                    continue
                }
                let diff = value - mean
                mean = mean + alpha * diff
                variance = (1 - alpha) * (variance + alpha * diff * diff)
                count += 1
            }
            guard count >= minCount else {
                return VoiceDimensionTrend(baseline: nil, zScore: nil)
            }
            let std = max(sqrt(max(variance, 0.0001)), 0.01)
            let z = (currentValue - mean) / std
            return VoiceDimensionTrend(baseline: mean, zScore: z)
        }

        return [
            "Energie": ewmaStats("Energie", extract: \.energy, currentValue: current.energy),
            "Anspannung": ewmaStats("Anspannung", extract: \.tension, currentValue: current.tension),
            "Müdigkeit": ewmaStats("Müdigkeit", extract: \.fatigue, currentValue: current.fatigue),
            "Wärme": ewmaStats("Wärme", extract: \.warmth, currentValue: current.warmth),
            "Lebendigkeit": ewmaStats("Lebendigkeit", extract: \.expressiveness, currentValue: current.expressiveness),
            "Tempo": ewmaStats("Tempo", extract: \.tempo, currentValue: current.tempo),
        ]
    }

    private func syntheticSegments(for entry: JournalEntry) -> [VoiceSegment] {
        let words = entry.transcript.split(separator: " ")
        let chunkSize = max(8, words.count / 4)
        let chunks = stride(from: 0, to: words.count, by: chunkSize).map { start -> String in
            let end = min(words.count, start + chunkSize)
            return words[start..<end].joined(separator: " ")
        }
        let base = VoiceDimensions.from(entry)
        return chunks.enumerated().map { idx, text in
            let drift = CGFloat(idx) * 0.05
            return VoiceSegment(
                startSecond: idx * 5,
                endSecond: idx * 5 + 5,
                energy: (base.energy + drift).clamped(to: 0...1),
                warmth: (base.warmth - drift * 0.4).clamped(to: 0...1),
                tension: (base.tension + drift * 0.20).clamped(to: 0...1),
                transcriptSnippet: text.isEmpty ? nil : text,
                dominantColor: entry.stimmungsfarbe
            )
        }
    }

    private func voiceSegments(for entry: JournalEntry) -> [VoiceSegment] {
        let stored = VoiceSegmentStore.load(for: entry.id)
        guard !stored.isEmpty else {
            return syntheticSegments(for: entry)
        }
        return stored.map { segment in
            VoiceSegment(
                startSecond: segment.startSecond,
                endSecond: segment.endSecond,
                energy: CGFloat(segment.energy).clamped(to: 0...1),
                warmth: CGFloat(segment.warmth).clamped(to: 0...1),
                tension: CGFloat(segment.stability).clamped(to: 0...1),
                transcriptSnippet: segment.transcriptSnippet,
                dominantColor: entry.stimmungsfarbe
            )
        }
    }
}

struct VoiceDimensions: Codable {
    let energy: CGFloat
    let tension: CGFloat
    let fatigue: CGFloat
    let warmth: CGFloat
    let expressiveness: CGFloat
    let tempo: CGFloat

    static func from(_ entry: JournalEntry) -> VoiceDimensions {
        let f0Range = CGFloat(entry.rawFeatures[FeatureKeys.f0RangeST] ?? entry.rawFeatures[FeatureKeys.f0Range] ?? 5)
        let f0Var = CGFloat(entry.rawFeatures[FeatureKeys.f0StdDev] ?? entry.rawFeatures[FeatureKeys.f0Variability] ?? 10)
        let jitter = CGFloat(entry.rawFeatures[FeatureKeys.jitter] ?? 0.025)
        let shimmer = CGFloat(entry.rawFeatures[FeatureKeys.shimmer] ?? 0.15)
        let hnr = CGFloat(entry.rawFeatures[FeatureKeys.hnr] ?? 3.5)
        let speechRate = CGFloat(entry.rawFeatures[FeatureKeys.speechRate] ?? 4.0)
        let articulation = CGFloat(entry.rawFeatures[FeatureKeys.articulationRate] ?? 7.0)
        let pauseDur = CGFloat(entry.rawFeatures[FeatureKeys.meanPauseDuration] ?? entry.rawFeatures[FeatureKeys.pauseDuration] ?? 0.4)
        let dynamicRange = CGFloat(entry.rawFeatures[FeatureKeys.loudnessDynamicRangeOriginal] ?? entry.rawFeatures[FeatureKeys.loudnessDynamicRange] ?? 30.0)
        let spectralWarmth = CGFloat(entry.rawFeatures["spectralWarmthRatio"] ?? 0.5)

        let e1 = map(speechRate, min: 2.5, max: 6.0)
        let e2 = map(f0Var, min: 4, max: 18)
        let e3 = map(articulation, min: 4, max: 9)
        let e4 = map(dynamicRange, min: 15, max: 40)
        let energy = e1 * 0.30 + e2 * 0.25 + e3 * 0.20 + e4 * 0.25

        let t1 = map(jitter * 40, min: 0.4, max: 1.2)
        let t2 = map(shimmer, min: 0.10, max: 0.25)
        let t3 = map(1 - hnr / 8, min: 0, max: 1)
        let t4 = map(1 - pauseDur, min: 0, max: 1)
        let t5 = map(speechRate, min: 3, max: 6)
        let tension = t1 * 0.25 + t2 * 0.20 + t3 * 0.20 + t4 * 0.15 + t5 * 0.20

        let f1 = 1 - map(f0Range, min: 2, max: 10)
        let f2 = 1 - map(speechRate, min: 2.5, max: 6)
        let f3 = map(pauseDur, min: 0.2, max: 1.0)
        let f4 = map(shimmer, min: 0.10, max: 0.25)
        let f5 = 1 - map(dynamicRange, min: 15, max: 40)
        let fatigue = f1 * 0.25 + f2 * 0.25 + f3 * 0.20 + f4 * 0.15 + f5 * 0.15

        let w1 = map(hnr, min: 1.5, max: 8.0)
        let w2 = map(1 - shimmer * 5, min: 0, max: 1)
        let w3 = map(spectralWarmth, min: 0.3, max: 0.7)
        let warmth = w1 * 0.40 + w2 * 0.30 + w3 * 0.30

        let x1 = map(f0Range, min: 2, max: 10)
        let x2 = map(f0Var, min: 4, max: 18)
        let x3 = map(dynamicRange, min: 15, max: 40)
        let x4 = 1 - map(pauseDur, min: 0.2, max: 0.8)
        let expressiveness = x1 * 0.35 + x2 * 0.30 + x3 * 0.20 + x4 * 0.15

        let tempo = map(speechRate, min: 2.5, max: 6.5)

        return VoiceDimensions(
            energy: energy.clamped(to: 0...1),
            tension: tension.clamped(to: 0...1),
            fatigue: fatigue.clamped(to: 0...1),
            warmth: warmth.clamped(to: 0...1),
            expressiveness: expressiveness.clamped(to: 0...1),
            tempo: tempo.clamped(to: 0...1)
        )
    }

    private static func map(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        guard max > min else { return 0.5 }
        return ((value - min) / (max - min)).clamped(to: 0...1)
    }
}

struct SignatureSection: View {
    let todayEntries: [JournalEntry]
    let latestEntry: JournalEntry
    @Binding var selectedEntryID: UUID?

    private var recentEntries: [JournalEntry] {
        todayEntries.isEmpty ? [latestEntry] : todayEntries
    }

    private var averageRepresentative: JournalEntry {
        guard !recentEntries.isEmpty else { return latestEntry }
        let avg = averagedDimensions(for: recentEntries)
        return recentEntries.min(by: {
            distance(VoiceDimensions.from($0), avg) < distance(VoiceDimensions.from($1), avg)
        }) ?? latestEntry
    }

    private var activeEntry: JournalEntry {
        if let selectedEntryID, let selected = recentEntries.first(where: { $0.id == selectedEntryID }) {
            return selected
        }
        return averageRepresentative
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Deine Stimm-Signatur")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)

            VoiceSignatureV2(entry: activeEntry, size: 220)

            Text(activeEntry.moodLabel ?? MoodCategory.resolve(activeEntry.mood)?.rawValue.capitalized ?? activeEntry.quadrant.label)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundStyle(activeEntry.stimmungsfarbe)

            Text(
                selectedEntryID == nil
                ? "Heute · \(recentEntries.count) Einträge"
                : activeEntry.date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute())
            )
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))

            let payload = SignatureShareData(
                signatureData: .fromDimensions(VoiceDimensions.from(activeEntry)),
                moodLabel: activeEntry.moodLabel ?? activeEntry.quadrant.label,
                color: activeEntry.stimmungsfarbe,
                date: activeEntry.date
            )
            KlunaShareButton(action: {
                ShareABManager.shared.trackTap(.signature)
                ShareImageGenerator.share(content: .signature(payload))
            })
            .onAppear {
                ShareABManager.shared.trackShown(.signature)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(KlunaWarm.warmAccent.opacity(selectedEntryID == nil ? 0.9 : 0.3))
                            .frame(width: 44, height: 44)
                            .overlay(Text("Ø").font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(.white))
                            .overlay(
                                Circle()
                                    .stroke(selectedEntryID == nil ? KlunaWarm.warmAccent : .clear, lineWidth: 2)
                                    .frame(width: 48, height: 48)
                            )
                        Text("Heute")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                    }
                    .opacity(selectedEntryID == nil ? 1 : 0.6)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            selectedEntryID = nil
                        }
                    }

                    ForEach(Array(recentEntries.prefix(6))) { entry in
                        VStack(spacing: 4) {
                            VoiceSignatureV2Mini(entry: entry, size: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedEntryID == entry.id ? entry.stimmungsfarbe : .clear, lineWidth: 2)
                                        .frame(width: 48, height: 48)
                                )
                            Text(signatureLabel(for: entry))
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                        }
                        .opacity(selectedEntryID == entry.id ? 1 : 0.6)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                selectedEntryID = entry.id
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }

    private func signatureLabel(for entry: JournalEntry) -> String {
        let sameDayCount = recentEntries.filter {
            Calendar.current.isDate($0.date, inSameDayAs: entry.date)
        }.count
        if sameDayCount > 1 {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: entry.date)
        }
        let f = DateFormatter()
        f.dateFormat = "d. MMM"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: entry.date)
    }

    private func averagedDimensions(for entries: [JournalEntry]) -> VoiceDimensions {
        let dims = entries.map(VoiceDimensions.from)
        let count = CGFloat(max(1, dims.count))
        return .init(
            energy: dims.map(\.energy).reduce(0, +) / count,
            tension: dims.map(\.tension).reduce(0, +) / count,
            fatigue: dims.map(\.fatigue).reduce(0, +) / count,
            warmth: dims.map(\.warmth).reduce(0, +) / count,
            expressiveness: dims.map(\.expressiveness).reduce(0, +) / count,
            tempo: dims.map(\.tempo).reduce(0, +) / count
        )
    }

    private func distance(_ lhs: VoiceDimensions, _ rhs: VoiceDimensions) -> CGFloat {
        abs(lhs.energy - rhs.energy)
            + abs(lhs.tension - rhs.tension)
            + abs(lhs.fatigue - rhs.fatigue)
            + abs(lhs.warmth - rhs.warmth)
            + abs(lhs.expressiveness - rhs.expressiveness)
            + abs(lhs.tempo - rhs.tempo)
    }
}

struct VoiceSignatureV2: View {
    let entry: JournalEntry
    let size: CGFloat
    @State private var isExploded = false
    @State private var highlightedArm: Int?
    @State private var breathScale: CGFloat = 1.0

    private var dims: VoiceDimensions { VoiceDimensions.from(entry) }
    private let armLabels = ["Energie", "Anspannung", "Müdigkeit", "Wärme", "Tempo", "Lebendigkeit"]
    private var armValues: [CGFloat] { [dims.energy, dims.tension, dims.fatigue, dims.warmth, dims.tempo, dims.expressiveness] }

    private func armAngle(_ index: Int) -> CGFloat {
        (CGFloat(index) / 6.0) * .pi * 2 - .pi / 2
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                if !isExploded {
                    organicShape()
                        .fill(entry.stimmungsfarbe.opacity(0.08))
                        .blur(radius: 15)
                        .scaleEffect(1.15 * breathScale)

                    organicShape()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    entry.stimmungsfarbe.opacity(0.75),
                                    entry.stimmungsfarbe.opacity(0.35),
                                ]),
                                center: .init(x: 0.4, y: 0.35),
                                startRadius: 0,
                                endRadius: size * 0.4
                            )
                        )
                        .scaleEffect(breathScale)

                    organicShape()
                        .stroke(entry.stimmungsfarbe.opacity(0.3), lineWidth: 1.5)
                        .scaleEffect(breathScale)

                    organicShape()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [.white.opacity(0.2), .clear]),
                                center: .init(x: 0.35, y: 0.3),
                                startRadius: 0,
                                endRadius: size * 0.3
                            )
                        )
                        .scaleEffect(breathScale)

                    ForEach(0..<6, id: \.self) { i in
                        let angle = armAngle(i)
                        let labelR = size * (0.40 + (0.16 * armValues[i]))
                        Text(armLabels[i])
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
                            .position(
                                x: size / 2 + labelR * cos(angle),
                                y: size / 2 + labelR * sin(angle)
                            )
                    }
                } else {
                    ForEach(0..<6, id: \.self) { i in
                        ExplodedArm(
                            index: i,
                            angle: armAngle(i),
                            value: armValues[i],
                            label: armLabels[i],
                            color: entry.stimmungsfarbe,
                            size: size,
                            isHighlighted: highlightedArm == i || highlightedArm == nil,
                            delay: Double(i) * 0.12
                        )
                    }

                    Circle()
                        .fill(entry.stimmungsfarbe.opacity(0.15))
                        .frame(width: 24, height: 24)
                        .position(x: size / 2, y: size / 2)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isExploded.toggle()
                    if !isExploded { highlightedArm = nil }
                }
                if isExploded {
                    animateArmHighlights()
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    breathScale = 1.03
                }
            }

            if isExploded, let arm = highlightedArm {
                VStack(spacing: 4) {
                    Text(armLabels[arm])
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(entry.stimmungsfarbe)
                    Text(armDescription(arm))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                    Text(valueWord(armValues[arm]))
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if !isExploded {
                Text("Tippe für Details")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.15))
            }
        }
    }

    private func organicShape() -> Path {
        Path { path in
            let center = CGPoint(x: size / 2, y: size / 2)
            let points = 300
            for i in 0...points {
                let t = CGFloat(i) / CGFloat(points)
                let angle = t * .pi * 2
                var radius: CGFloat = 0
                for armIdx in 0..<6 {
                    let armAng = armAngle(armIdx)
                    let angleDiff = abs(angleDifference(angle, armAng))
                    let armWidth: CGFloat = 0.5
                    let influence = exp(-angleDiff * angleDiff / (2 * armWidth * armWidth))
                    let armLength = size * 0.15 + size * 0.22 * armValues[armIdx]
                    radius += armLength * influence
                }
                let minRadius = size * 0.12
                radius = max(radius, minRadius)
                let seed = entry.date.timeIntervalSince1970
                let noise = sin(angle * 7 + CGFloat(seed.truncatingRemainder(dividingBy: 10))) * size * 0.01
                let noise2 = cos(angle * 11 + 2.3) * size * 0.008
                radius += noise + noise2
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.closeSubpath()
        }
    }

    private func angleDifference(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        atan2(sin(a - b), cos(a - b))
    }

    private func animateArmHighlights() {
        for i in 0..<6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.75 + 0.45) {
                withAnimation(.easeOut(duration: 0.42)) { highlightedArm = i }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            withAnimation(.easeOut(duration: 0.35)) { highlightedArm = nil }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                isExploded = false
                highlightedArm = nil
            }
        }
    }

    private func armDescription(_ index: Int) -> String {
        let value = armValues[index]
        switch index {
        case 0:
            switch value {
            case 0..<0.3: return "Wenig Kraft in deiner Stimme. Ruhig und gedämpft."
            case 0.3..<0.5: return "Moderate Energie. Entspannt aber präsent."
            case 0.5..<0.7: return "Lebendige Energie. Du bist da."
            default: return "Richtig viel Power. Deine Stimme strahlt Kraft aus."
            }
        case 1:
            switch value {
            case 0..<0.3: return "Entspannt. Keine Spur von Stress in deiner Stimme."
            case 0.3..<0.5: return "Leichte Grundspannung. Normal für den Alltag."
            case 0.5..<0.7: return "Deutliche Anspannung. Deine Stimme verrät Stress."
            default: return "Hohe Anspannung. Deine Stimme zittert und du redest durch."
            }
        case 2:
            switch value {
            case 0..<0.3: return "Wach und klar. Keine Müdigkeit hörbar."
            case 0.3..<0.5: return "Leicht ermüdet. Deine Stimme wird etwas flacher."
            case 0.5..<0.7: return "Deutlich müde. Weniger Melodie, längere Pausen."
            default: return "Erschöpft. Deine Stimme hat kaum noch Kraft."
            }
        case 3:
            switch value {
            case 0..<0.3: return "Kühl und distanziert. Sachlicher Ton."
            case 0.3..<0.5: return "Neutral. Weder kalt noch besonders warm."
            case 0.5..<0.7: return "Angenehm warm. Deine Stimme klingt einladend."
            default: return "Sehr warm. Man hört, dass du dich wohl fühlst."
            }
        case 4:
            switch value {
            case 0..<0.3: return "Langsam und bedacht. Jedes Wort wird gewählt."
            case 0.3..<0.5: return "Gemütliches Tempo. Entspannt aber flüssig."
            case 0.5..<0.7: return "Zügig. Du weißt, was du sagen willst."
            default: return "Schnell. Die Worte sprudeln raus."
            }
        default:
            switch value {
            case 0..<0.3: return "Monoton. Wenig Melodie in der Stimme."
            case 0.3..<0.5: return "Etwas gleichförmig. Ruhiger Ausdruck."
            case 0.5..<0.7: return "Lebendig. Natürliche Melodie im Sprechen."
            default: return "Sehr ausdrucksstark. Deine Stimme erzählt mit."
            }
        }
    }

    private func valueWord(_ v: CGFloat) -> String {
        switch v {
        case 0..<0.2: return "sehr niedrig"
        case 0.2..<0.4: return "niedrig"
        case 0.4..<0.6: return "mittel"
        case 0.6..<0.8: return "hoch"
        default: return "sehr hoch"
        }
    }
}

struct VoiceSignatureV2Mini: View {
    let entry: JournalEntry
    let size: CGFloat

    private var dims: VoiceDimensions { VoiceDimensions.from(entry) }
    private var armValues: [CGFloat] { [dims.energy, dims.tension, dims.fatigue, dims.warmth, dims.tempo, dims.expressiveness] }

    private func armAngle(_ index: Int) -> CGFloat {
        (CGFloat(index) / 6.0) * .pi * 2 - .pi / 2
    }

    var body: some View {
        ZStack {
            organicShape()
                .fill(entry.stimmungsfarbe.opacity(0.4))
            organicShape()
                .stroke(entry.stimmungsfarbe.opacity(0.2), lineWidth: 0.5)
        }
        .frame(width: size, height: size)
    }

    private func organicShape() -> Path {
        Path { path in
            let center = CGPoint(x: size / 2, y: size / 2)
            let points = 220
            for i in 0...points {
                let t = CGFloat(i) / CGFloat(points)
                let angle = t * .pi * 2
                var radius: CGFloat = 0
                for armIdx in 0..<6 {
                    let armAng = armAngle(armIdx)
                    let angleDiff = abs(atan2(sin(angle - armAng), cos(angle - armAng)))
                    let armWidth: CGFloat = 0.5
                    let influence = exp(-angleDiff * angleDiff / (2 * armWidth * armWidth))
                    let armLength = size * 0.15 + size * 0.22 * armValues[armIdx]
                    radius += armLength * influence
                }
                radius = max(radius, size * 0.12)
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.closeSubpath()
        }
    }
}

struct ExplodedArm: View {
    let index: Int
    let angle: CGFloat
    let value: CGFloat
    let label: String
    let color: Color
    let size: CGFloat
    let isHighlighted: Bool
    let delay: Double

    @State private var appeared = false

    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let armLength = size * 0.15 + size * 0.25 * value
        let endPoint = CGPoint(
            x: center.x + armLength * cos(angle),
            y: center.y + armLength * sin(angle)
        )

        ZStack {
            Path { path in
                path.move(to: center)
                path.addLine(to: endPoint)
            }
            .stroke(
                color.opacity(isHighlighted ? 0.6 : 0.15),
                style: StrokeStyle(lineWidth: isHighlighted ? 3 : 1.5, lineCap: .round)
            )

            Circle()
                .fill(color.opacity(isHighlighted ? 0.8 : 0.2))
                .frame(width: isHighlighted ? 14 : 8, height: isHighlighted ? 14 : 8)
                .position(endPoint)
                .shadow(color: isHighlighted ? color.opacity(0.3) : .clear, radius: 6)

            Text(label)
                .font(.system(size: isHighlighted ? 11 : 9, weight: isHighlighted ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isHighlighted ? color : KlunaWarm.warmBrown.opacity(0.3))
                .position(
                    x: center.x + (armLength + 20) * cos(angle),
                    y: center.y + (armLength + 20) * sin(angle)
                )

            if isHighlighted {
                Text(valueWord(value))
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(color.opacity(0.7)))
                    .position(
                        x: center.x + (armLength * 0.6) * cos(angle) + 15 * cos(angle + .pi / 2),
                        y: center.y + (armLength * 0.6) * sin(angle) + 15 * sin(angle + .pi / 2)
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(delay), value: appeared)
        .animation(.easeOut(duration: 0.3), value: isHighlighted)
        .onAppear { appeared = true }
    }

    private func valueWord(_ v: CGFloat) -> String {
        switch v {
        case 0..<0.2: return "sehr niedrig"
        case 0.2..<0.4: return "niedrig"
        case 0.4..<0.6: return "mittel"
        case 0.6..<0.8: return "hoch"
        default: return "sehr hoch"
        }
    }
}

struct VoiceComparisonSection: View {
    let today: VoiceDimensions
    let lastWeekAvg: VoiceDimensions
    let todayColor: Color

    var body: some View {
        VStack(spacing: 16) {
            Text("Dein Vergleich")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    CompactRadarChart(dimensions: today, color: todayColor)
                        .frame(width: 120, height: 120)
                    Text("Heute")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 8) {
                    CompactRadarChart(dimensions: lastWeekAvg, color: KlunaWarm.warmBrown.opacity(0.3))
                        .frame(width: 120, height: 120)
                    Text("Dein Normal")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)

            HStack(spacing: 10) {
                ViewThatFits {
                    HStack(spacing: 10) {
                        ForEach(
                            Array(zip(["E", "A", "M", "W", "T", "L"], ["Energie", "Anspannung", "Müdigkeit", "Wärme", "Tempo", "Lebendigkeit"])),
                            id: \.0
                        ) { short, full in
                            HStack(spacing: 2) {
                                Text(short)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
                                Text("= \(full)")
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        HStack(spacing: 10) {
                            legendItem(short: "E", full: "Energie")
                            legendItem(short: "A", full: "Anspannung")
                            legendItem(short: "M", full: "Müdigkeit")
                        }
                        HStack(spacing: 10) {
                            legendItem(short: "W", full: "Wärme")
                            legendItem(short: "T", full: "Tempo")
                            legendItem(short: "L", full: "Lebendigkeit")
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }

    private func legendItem(short: String, full: String) -> some View {
        HStack(spacing: 2) {
            Text(short)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
            Text("= \(full)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
        }
    }
}

struct VoiceRadarSection: View {
    let dimensions: VoiceDimensions
    let normal: VoiceDimensions
    let trends: [String: VoiceDimensionTrend]
    @State private var appeared = false

    private let items: [(label: String, value: KeyPath<VoiceDimensions, CGFloat>, color: Color, emoji: String)] = [
        ("Energie", \.energy, Color(hex: "F5B731"), "⚡"),
        ("Anspannung", \.tension, Color(hex: "E85C5C"), "🔴"),
        ("Müdigkeit", \.fatigue, Color(hex: "8B9DAF"), "😴"),
        ("Wärme", \.warmth, Color(hex: "E8825C"), "🔥"),
        ("Lebendigkeit", \.expressiveness, Color(hex: "6BC5A0"), "✨"),
        ("Tempo", \.tempo, Color(hex: "7BA7C4"), "🎵"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Dein Stimm-Profil")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                VoiceRadarDimensionRow(
                    label: item.label,
                    emoji: item.emoji,
                    value: dimensions[keyPath: item.value],
                    baseline: trends[item.label]?.baseline ?? normal[keyPath: item.value],
                    zScore: trends[item.label]?.zScore,
                    color: item.color,
                    delay: Double(index) * 0.06,
                    appeared: appeared
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
    }
}

private struct VoiceRadarDimensionRow: View {
    let label: String
    let emoji: String
    let value: CGFloat
    let baseline: CGFloat
    let zScore: CGFloat?
    let color: Color
    let delay: Double
    let appeared: Bool

    @State private var animatedValue: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(emoji).font(.system(size: 14))
                Text(label)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Spacer()
                Text("\(Int((value * 100).rounded()))%")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(KlunaWarm.warmBrown.opacity(0.04))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * animatedValue)
                    Rectangle()
                        .fill(KlunaWarm.warmBrown.opacity(0.22))
                        .frame(width: 2, height: 14)
                        .offset(x: geo.size.width * baseline - 1)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())

            Text(trendText())
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(trendColor().opacity(0.85))
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78).delay(delay)) {
                animatedValue = value
            }
        }
    }

    private func trendText() -> String {
        guard let zScore else {
            let diff = value - baseline
            if abs(diff) < 0.07 { return "→ wie gewohnt" }
            let higherWorse = label == "Anspannung" || label == "Müdigkeit"
            let intensity = abs(diff) < 0.14 ? "leicht" : abs(diff) < 0.24 ? "deutlich" : "stark"
            if diff > 0 {
                return higherWorse ? "↑ \(intensity) erhöht" : "↑ \(intensity) höher als sonst"
            }
            return higherWorse ? "↓ \(intensity) niedriger als sonst" : "↓ \(intensity) niedriger"
        }
        if abs(zScore) < 0.8 { return "→ wie gewohnt" }
        let higherWorse = label == "Anspannung" || label == "Müdigkeit"
        let intensity = abs(zScore) < 1.3 ? "leicht" : abs(zScore) < 2.0 ? "deutlich" : "stark"
        if zScore > 0 {
            return higherWorse ? "↑ \(intensity) erhöht" : "↑ \(intensity) höher als sonst"
        }
        return higherWorse ? "↓ \(intensity) niedriger als sonst" : "↓ \(intensity) niedriger als sonst"
    }

    private func trendColor() -> Color {
        let delta: CGFloat = zScore ?? (value - baseline)
        if abs(delta) < 0.8 && zScore != nil { return KlunaWarm.warmBrown.opacity(0.45) }
        if abs(delta) < 0.07 && zScore == nil { return KlunaWarm.warmBrown.opacity(0.45) }
        let higherWorse = label == "Anspannung" || label == "Müdigkeit"
        if delta > 0 {
            return higherWorse ? Color(hex: "E85C5C") : Color(hex: "6BC5A0")
        }
        return higherWorse ? Color(hex: "6BC5A0") : Color(hex: "E85C5C")
    }
}

struct VoiceDimensionTrend {
    let baseline: CGFloat?
    let zScore: CGFloat?
}

struct CompactRadarChart: View {
    let dimensions: VoiceDimensions
    let color: Color
    @State private var scale: CGFloat = 0

    private let labels = ["E", "A", "M", "W", "T", "L"]
    private var values: [CGFloat] {
        [dimensions.energy, dimensions.tension, dimensions.fatigue, dimensions.warmth, dimensions.tempo, dimensions.expressiveness]
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxR = min(geo.size.width, geo.size.height) / 2 - 12

            ZStack {
                ForEach([0.33, 0.66, 1.0], id: \.self) { level in
                    radarPath(values: Array(repeating: CGFloat(level), count: 6), center: center, maxR: maxR)
                        .stroke(KlunaWarm.warmBrown.opacity(0.04), lineWidth: 0.5)
                }

                radarPath(values: values, center: center, maxR: maxR)
                    .fill(color.opacity(0.15))
                    .scaleEffect(scale)

                radarPath(values: values, center: center, maxR: maxR)
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
                    .scaleEffect(scale)

                ForEach(0..<6, id: \.self) { i in
                    let angle = (CGFloat(i) / 6) * .pi * 2 - .pi / 2
                    let r = maxR * values[i] * scale
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .position(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                }

                ForEach(0..<6, id: \.self) { i in
                    let angle = (CGFloat(i) / 6) * .pi * 2 - .pi / 2
                    let labelR = maxR + 10
                    Text(labels[i])
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                        .position(x: center.x + labelR * cos(angle), y: center.y + labelR * sin(angle))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                scale = 1
            }
        }
    }

    private func radarPath(values: [CGFloat], center: CGPoint, maxR: CGFloat) -> Path {
        Path { path in
            for i in 0...values.count {
                let idx = i % values.count
                let angle = (CGFloat(idx) / CGFloat(values.count)) * .pi * 2 - .pi / 2
                let r = maxR * values[idx]
                let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
    }
}

struct VoiceSegment {
    let startSecond: Int
    let endSecond: Int
    let energy: CGFloat
    let warmth: CGFloat
    let tension: CGFloat
    let transcriptSnippet: String?
    let dominantColor: Color
}

struct VoiceHighlightsSection: View {
    let segments: [VoiceSegment]
    let transcript: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deine Stimm-Reise")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)
            Text("So hat sich deine Stimme während des Eintrags verändert")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
            VStack(spacing: 0) {
                ForEach(segments.indices, id: \.self) { i in
                    let segment = segments[i]
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle().fill(segment.dominantColor).frame(width: 10, height: 10)
                            if i < segments.count - 1 {
                                LinearGradient(
                                    colors: [segment.dominantColor.opacity(0.3), segments[i + 1].dominantColor.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(width: 2, height: 40)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(segment.startSecond)s – \(segment.endSecond)s")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                            if let text = segment.transcriptSnippet {
                                Text("\"\(text)\"")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.7))
                                    .italic()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack(spacing: 8) {
                                MicroBar(label: "E", value: segment.energy, color: segment.dominantColor)
                                MicroBar(label: "W", value: segment.warmth, color: segment.dominantColor)
                                MicroBar(label: "A", value: segment.tension, color: segment.dominantColor)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
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

struct MicroBar: View {
    let label: String
    let value: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            Capsule()
                .fill(color.opacity(0.4))
                .frame(width: 24 * value.clamped(to: 0...1), height: 3)
        }
    }
}

struct PremiumTeaser: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)
            Text(description)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
            Label("Premium", systemImage: "sparkles")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(KlunaWarm.warmAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(KlunaWarm.warmAccent.opacity(0.08)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 10, x: 0, y: 5)
        )
    }
}

struct EmptyVoiceView: View {
    var body: some View {
        VStack(spacing: 12) {
            Circle()
                .stroke(KlunaWarm.warmBrown.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4]))
                .frame(width: 200, height: 200)
            Text("Sprich etwas ein und sieh deine Stimm-Signatur")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Me Tab

struct MeView: View {
    @ObservedObject private var dataManager = KlunaDataManager.shared
    @ObservedObject private var memory = KlunaMemory.shared
    @ObservedObject private var monthlyLetters = MonthlyLetterManager.shared
    @State private var selectedDate: Date = Date()
    @State private var cardIdentity: Date = Calendar.current.startOfDay(for: Date())
    @State private var showFullLetter = false

    private var todayCard: DailyCard? {
        DailyCardManager.shared.cardForDate(Date())
    }

    private var selectedCard: DailyCard? {
        DailyCardManager.shared.cardForDate(selectedDate)
    }

    private var timelineDays: [(date: Date, card: DailyCard?)] {
        (0..<30).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return (date, DailyCardManager.shared.cardForDate(date))
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ZStack {
                    if let card = Calendar.current.isDateInToday(selectedDate) ? todayCard : selectedCard {
                        DailyCardView(card: card)
                            .frame(width: 300, height: 420)
                            .padding(.top, 8)
                            .id(cardIdentity)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.97)), removal: .opacity))
                    }
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.84), value: cardIdentity)

                HStack {
                    Button(action: { navigateDay(-1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#3D3229").opacity(0.15))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(dateLabel(selectedDate))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.3))

                    Spacer()

                    Button(action: { navigateDay(1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(
                                Calendar.current.isDateInToday(selectedDate)
                                    ? Color(hex: "#3D3229").opacity(0.04)
                                    : Color(hex: "#3D3229").opacity(0.15)
                            )
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(Calendar.current.isDateInToday(selectedDate))
                }
                .padding(.horizontal, 20)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(timelineDays.enumerated()), id: \.offset) { index, day in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedDate = day.date
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }) {
                                    VStack(spacing: 4) {
                                        if let card = day.card {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(
                                                    LinearGradient(
                                                        colors: card.atmosphereColors,
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 32, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .fill(card.primaryColor)
                                                        .frame(width: 8, height: 8)
                                                )
                                                .overlay(alignment: .topTrailing) {
                                                    if card.rarity != .common {
                                                        Circle()
                                                            .fill(card.rarity.color)
                                                            .frame(width: 4, height: 4)
                                                            .offset(x: -2, y: 2)
                                                    }
                                                }
                                                .overlay(alignment: .topLeading) {
                                                    if isWeeklyMilestone(day.date) {
                                                        Text(isGerman ? "W" : "W")
                                                            .font(.system(size: 7, weight: .bold, design: .rounded))
                                                            .foregroundColor(.white.opacity(0.8))
                                                            .padding(.horizontal, 3)
                                                            .padding(.vertical, 1)
                                                            .background(Capsule().fill(Color(hex: "#F5B731").opacity(0.8)))
                                                            .offset(x: 2, y: 2)
                                                    }
                                                }
                                        } else {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(hex: "#3D3229").opacity(0.03))
                                                .frame(width: 32, height: 44)
                                        }

                                        Text(shortDayLabel(day.date))
                                            .font(
                                                .system(
                                                    size: 9,
                                                    weight: Calendar.current.isDate(day.date, inSameDayAs: selectedDate) ? .bold : .regular,
                                                    design: .rounded
                                                )
                                            )
                                            .foregroundColor(
                                                Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
                                                    ? Color(hex: "#E8825C")
                                                    : Color(hex: "#3D3229").opacity(0.15)
                                            )
                                    }
                                    .opacity(Calendar.current.isDate(day.date, inSameDayAs: selectedDate) ? 1.0 : 0.7)
                                }
                                .buttonStyle(.plain)
                                .id(dayKey(day.date))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .onAppear {
                        proxy.scrollTo(dayKey(selectedDate), anchor: .center)
                    }
                    .onChange(of: selectedDate) { _, newDate in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(dayKey(newDate), anchor: .center)
                        }
                    }
                }

                if let letter = monthlyLetters.latestLetter() {
                    MeMonthlyLetterTeaser(letter: letter) {
                        showFullLetter = true
                    }
                    .padding(.horizontal, 20)
                } else {
                    let entryCount = KlunaDataManager.shared.entries.count
                    if entryCount >= 5 && entryCount < 15 {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#E8825C").opacity(0.15))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(isGerman ? "Dein erster Monatsbrief" : "Your first monthly letter")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(Color(hex: "#3D3229").opacity(0.2))
                                Text(isGerman ? "Noch \(15 - entryCount) Einträge" : "\(15 - entryCount) more entries to go")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(Color(hex: "#3D3229").opacity(0.1))
                            }

                            Spacer()

                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.06))
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: Color(hex: "#3D3229").opacity(0.02), radius: 6, x: 0, y: 3)
                        )
                        .padding(.horizontal, 20)
                    }
                }

                if let surprise = dailySurprise() {
                    SurpriseCardView(surprise: surprise)
                        .padding(.horizontal, 20)
                }

                if memory.entryCount > 0 {
                    MeMemoryLayersView(memory: memory)
                        .padding(.horizontal, 20)
                }

                if !memory.emotionalMap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    PeopleMapView(emotionalMap: memory.emotionalMap)
                        .padding(.horizontal, 20)
                }

                if dataManager.entries.count >= 10 {
                    MeChangeView(entries: dataManager.entries)
                        .padding(.horizontal, 20)
                }

                let activeLayers = memory.layersForUI.filter {
                    !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }.count
                MeLockedFeaturesView(entryCount: memory.entryCount, activeMemoryLayers: activeLayers)
                    .padding(.horizontal, 20)

                Spacer().frame(height: 100)
            }
            .padding(.top, 16)
        }
        .background(KlunaWarm.background.ignoresSafeArea())
        .onChange(of: selectedDate) { _, newDate in
            cardIdentity = Calendar.current.startOfDay(for: newDate)
        }
        .sheet(isPresented: $showFullLetter) {
            if let letter = monthlyLetters.latestLetter() {
                MeMonthlyLetterFullView(letter: letter)
            }
        }
    }

    private func dailySurprise() -> SurpriseCardView.DailySurprise? {
        let entries = dataManager.entries.sorted(by: { $0.date < $1.date })
        guard entries.count >= 5 else { return nil }

        let today = entries.filter { Calendar.current.isDateInToday($0.date) }
        if let todayEntry = today.first,
           let firstTheme = todayEntry.themes.first,
           todayEntry.warmth > 0.6 {
            return .init(
                text: String(format: "me.surprise.warmth_topic".localized, firstTheme),
                type: .warmth
            )
        }

        let week = dataManager.lastNDaysEntries(7).filter { $0.entryCount > 0 }
        if week.count >= 4 {
            let split = max(1, week.count / 2)
            let firstHalf = week.prefix(split)
            let secondHalf = week.suffix(week.count - split)
            if !firstHalf.isEmpty, !secondHalf.isEmpty {
                let firstTension = firstHalf.map(\.avgTension).reduce(0, +) / Float(firstHalf.count)
                let secondTension = secondHalf.map(\.avgTension).reduce(0, +) / Float(secondHalf.count)
                if firstTension - secondTension > 0.08 {
                    return .init(text: "me.surprise.tension_drop".localized, type: .change)
                }
            }
        }

        let mondays = entries.filter { Calendar.current.component(.weekday, from: $0.date) == 2 }
        if mondays.count >= 3 {
            let mondayAvg = mondays.map(\.stability).reduce(0, +) / Float(mondays.count)
            let allAvg = entries.map(\.stability).reduce(0, +) / Float(entries.count)
            if mondayAvg < allAvg - 0.08 {
                return .init(text: "me.surprise.monday_pattern".localized, type: .pattern)
            }
        }

        if let todayEntry = today.first {
            let allWarmth = entries.map(\.warmth)
            if todayEntry.warmth >= (allWarmth.max() ?? 0) - 0.02 {
                return .init(text: "me.surprise.warmest_record".localized, type: .record)
            }
        }
        return nil
    }

    private func navigateDay(_ offset: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate),
              newDate <= Date() else { return }
        withAnimation(.spring(response: 0.3)) {
            selectedDate = newDate
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func dateLabel(_ date: Date) -> String {
        let isGerman = Locale.current.language.languageCode?.identifier == "de"
        if Calendar.current.isDateInToday(date) { return isGerman ? "Heute" : "Today" }
        if Calendar.current.isDateInYesterday(date) { return isGerman ? "Gestern" : "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private func shortDayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return Locale.current.language.languageCode?.identifier == "de" ? "Heu" : "Tod"
        }
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "EE"
        return String(fmt.string(from: date).prefix(2))
    }

    private var isGerman: Bool {
        Locale.current.language.languageCode?.identifier == "de"
    }

    private func dayKey(_ date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        return String(Int(day.timeIntervalSince1970))
    }

    private func isWeeklyMilestone(_ date: Date) -> Bool {
        let cal = Calendar.current
        let daysWithEntries = Set(dataManager.entries.map { cal.startOfDay(for: $0.date) })
        let day = cal.startOfDay(for: date)
        guard daysWithEntries.contains(day) else { return false }
        for i in 0..<7 {
            guard let check = cal.date(byAdding: .day, value: -i, to: day),
                  daysWithEntries.contains(check) else { return false }
        }
        return true
    }
}

struct MonthlyLetter: Codable, Identifiable {
    let date: Date
    let monthName: String
    let text: String
    let entryCount: Int
    let activeDays: Int
    let dominantMood: String
    let legendaryCards: Int
    let rareCards: Int
    let avgDims: VoiceDimensions
    let longestStreak: Int

    var id: Date { date }
}

@MainActor
final class MonthlyLetterManager: ObservableObject {
    static let shared = MonthlyLetterManager()
    @Published private var lettersCache: [MonthlyLetter] = []

    private let lastLetterKey = "kluna_last_monthly_letter"
    private let lettersKey = "kluna_monthly_letters"
    private let firstLetterThreshold = 15

    private init() {
        lettersCache = loadAllLetters()
    }

    func checkForNewLetter() {
        let lastLetterDate = UserDefaults.standard.object(forKey: lastLetterKey) as? Date
        let calendar = Calendar.current
        let entryCount = KlunaDataManager.shared.entries.count

        if let lastDate = lastLetterDate {
            let monthsSince = calendar.dateComponents([.month], from: lastDate, to: Date()).month ?? 0
            if monthsSince >= 1 && entryCount > 0 {
                generateLetter()
            }
        } else if entryCount >= firstLetterThreshold {
            generateLetter()
        }
    }

    func generateLetter() {
        Task {
            let letter = await buildAndGenerateLetter()
            if let letter {
                await MainActor.run {
                    saveLetter(letter)
                    UserDefaults.standard.set(Date(), forKey: lastLetterKey)
                    showLetterNotification()
                }
            }
        }
    }

    func latestLetter() -> MonthlyLetter? {
        lettersCache.first
    }

    func loadAllLetters() -> [MonthlyLetter] {
        guard let data = UserDefaults.standard.data(forKey: lettersKey),
              let letters = try? JSONDecoder().decode([MonthlyLetter].self, from: data) else {
            return []
        }
        return letters.sorted { $0.date > $1.date }
    }

    func saveLetter(_ letter: MonthlyLetter) {
        var letters = loadAllLetters()
        let alreadyForMonth = letters.contains { lhs in
            Calendar.current.isDate(lhs.date, equalTo: letter.date, toGranularity: .month) &&
            Calendar.current.isDate(lhs.date, equalTo: letter.date, toGranularity: .year)
        }
        if alreadyForMonth { return }
        letters.append(letter)
        if let data = try? JSONEncoder().encode(letters) {
            UserDefaults.standard.set(data, forKey: lettersKey)
            lettersCache = letters.sorted { $0.date > $1.date }
        }
        KlunaAnalytics.shared.track("monthly_letter_generated")
    }

    private var isGerman: Bool {
        Locale.current.language.languageCode?.identifier == "de"
    }

    private var monthlyLetterPrompt: String {
        """
        Du schreibst einen persönlichen Monatsbrief von Kluna an eine Person. Kluna hat einen Monat lang zugehört. Jetzt fasst Kluna zusammen, was es gehört hat.

        Das ist KEIN Report. KEIN Dashboard. KEIN Bericht. Es ist ein BRIEF. Von einem Freund.

        SPRACHE: \(isGerman ? "Deutsch" : "English")

        FORMAT:
        Reiner Fließtext. Keine Bulletpoints. Keine Labels. Keine Markdown-Formatierung.

        STRUKTUR:
        1. Eröffnung (persönlich, warm)
        2. Die Reise über den Monat (Veränderungen)
        3. Besondere Momente (wärmster/angespanntester Tag, Karten, Durchbrüche)
        4. Muster, die Kluna erkennt
        5. Abschluss mit Ausblick

        LÄNGE: 150-250 Wörter.
        TON: Warm, konkret, menschlich, ehrlich.
        VERMEIDE: Therapeuten-Sprache, Analyse-Jargon, Aufzählungen.
        """
    }

    private func buildAndGenerateLetter() async -> MonthlyLetter? {
        let input = buildMonthlyLetterInput()
        guard !input.isEmpty else { return nil }

        do {
            let response = try await CoachAPIManager.requestInsights(
                payload: input,
                systemPrompt: monthlyLetterPrompt,
                maxTokens: 450,
                apiKey: Config.claudeAPIKey
            )
            let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let cleaned = stripMarkdown(text)

            let entries = KlunaDataManager.shared.entriesForLastMonth()
            let cards = DailyCardManager.shared.cardsForLastMonth()
            let avgDims = DailyCardManager.shared.averageDims(entries)
            let moods = entries.compactMap { $0.moodLabel ?? $0.mood }
            let dominantMood = moods.mostFrequent() ?? "ruhig"
            let activeDays = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count

            return MonthlyLetter(
                date: Date(),
                monthName: Date().formatted(.dateTime.month(.wide).year()),
                text: cleaned,
                entryCount: entries.count,
                activeDays: activeDays,
                dominantMood: dominantMood,
                legendaryCards: cards.filter { $0.rarity == .legendary }.count,
                rareCards: cards.filter { $0.rarity == .rare }.count,
                avgDims: avgDims,
                longestStreak: calculateLongestStreakInMonth(entries)
            )
        } catch {
            print("📨 Monthly letter generation failed: \(error)")
            return nil
        }
    }

    private func buildMonthlyLetterInput() -> String {
        let entries = KlunaDataManager.shared.entriesForLastMonth().sorted(by: { $0.date < $1.date })
        let memory = KlunaMemory.shared.fullMemory
        let userName = UserDefaults.standard.string(forKey: "kluna_profile_name") ?? ""
        guard entries.count >= 5 else { return "" }

        var input = ""
        if !userName.isEmpty { input += "NAME: \(userName)\n\n" }
        if !memory.isEmpty { input += "GEDAECHTNIS:\n\(memory)\n\n" }

        let firstDate = entries.first?.date ?? Date()
        let lastDate = entries.last?.date ?? Date()
        input += "ZEITRAUM: \(firstDate.formatted(.dateTime.month(.wide).year()))\n"
        input += "VON: \(firstDate.formatted(.dateTime.day().month(.abbreviated)))\n"
        input += "BIS: \(lastDate.formatted(.dateTime.day().month(.abbreviated)))\n\n"

        input += "STATISTIK:\n"
        input += "Einträge: \(entries.count)\n"
        let uniqueDays = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
        input += "Aktive Tage: \(uniqueDays)\n"
        let totalSeconds = entries.map(\.duration).reduce(0, +)
        input += "Gesprochen: \(Int(totalSeconds / 60)) Minuten\n"

        let moods = entries.compactMap { $0.moodLabel ?? $0.mood }
        let moodCounts = Dictionary(grouping: moods, by: { $0 }).mapValues(\.count).sorted { $0.value > $1.value }
        input += "\nSTIMMUNGEN:\n"
        for (mood, count) in moodCounts {
            let pct = moods.isEmpty ? 0 : Int(Double(count) / Double(moods.count) * 100.0)
            input += "\(mood): \(count)x (\(pct)%)\n"
        }

        let avgDims = DailyCardManager.shared.averageDims(entries)
        input += "\nDURCHSCHNITT:\n"
        input += "Energie: \(Int(avgDims.energy * 100))%\n"
        input += "Anspannung: \(Int(avgDims.tension * 100))%\n"
        input += "Müdigkeit: \(Int(avgDims.fatigue * 100))%\n"
        input += "Wärme: \(Int(avgDims.warmth * 100))%\n"
        input += "Lebendigkeit: \(Int(avgDims.expressiveness * 100))%\n"

        let firstWeek = Array(entries.prefix(min(7, entries.count)))
        let lastWeek = Array(entries.suffix(min(7, entries.count)))
        let firstDims = DailyCardManager.shared.averageDims(firstWeek)
        let lastDims = DailyCardManager.shared.averageDims(lastWeek)
        input += "\nVERÄNDERUNG (Anfang → Ende):\n"
        input += "Anspannung: \(Int(firstDims.tension * 100))% → \(Int(lastDims.tension * 100))%\n"
        input += "Wärme: \(Int(firstDims.warmth * 100))% → \(Int(lastDims.warmth * 100))%\n"
        input += "Energie: \(Int(firstDims.energy * 100))% → \(Int(lastDims.energy * 100))%\n"
        input += "Müdigkeit: \(Int(firstDims.fatigue * 100))% → \(Int(lastDims.fatigue * 100))%\n"

        let warmestDay = entries.max(by: { $0.warmth < $1.warmth })
        let tensestDay = entries.max(by: { $0.stability < $1.stability })
        let calmestDay = entries.min(by: { $0.stability < $1.stability })
        input += "\nBESONDERE TAGE:\n"
        if let w = warmestDay { input += "Wärmster Tag: \(w.date.formatted(.dateTime.day().month(.abbreviated)))\n" }
        if let t = tensestDay { input += "Angespanntester Tag: \(t.date.formatted(.dateTime.day().month(.abbreviated)))\n" }
        if let c = calmestDay { input += "Ruhigster Tag: \(c.date.formatted(.dateTime.day().month(.abbreviated)))\n" }

        let allThemes = entries.flatMap(\.themes)
        let themeCounts = Dictionary(grouping: allThemes, by: { $0 }).mapValues(\.count).sorted { $0.value > $1.value }
        if !themeCounts.isEmpty {
            input += "\nTHEMEN:\n"
            for (theme, count) in themeCounts.prefix(5) {
                input += "\(theme): \(count)x\n"
            }
        }

        let cards = DailyCardManager.shared.cardsForLastMonth()
        let rarities = Dictionary(grouping: cards, by: { $0.rarity }).mapValues(\.count)
        input += "\nKARTEN:\n"
        input += "Gesamt: \(cards.count)\n"
        if let leg = rarities[.legendary] { input += "Legendär: \(leg)\n" }
        if let rare = rarities[.rare] { input += "Selten: \(rare)\n" }
        if let unc = rarities[.uncommon] { input += "Besonders: \(unc)\n" }

        let contradictions = entries.filter { ContradictionStore.load(for: $0.id) != nil }
        input += "Widersprüche entdeckt: \(contradictions.count)\n"
        input += "Längster Streak: \(calculateLongestStreakInMonth(entries)) Tage\n"

        return input
    }

    private func calculateLongestStreakInMonth(_ entries: [JournalEntry]) -> Int {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return 0 }
        var maxStreak = 1
        var current = 1
        for idx in 1..<days.count {
            let prev = days[idx - 1]
            let cur = days[idx]
            let diff = calendar.dateComponents([.day], from: prev, to: cur).day ?? 99
            if diff == 1 {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 1
            }
        }
        return maxStreak
    }

    private func stripMarkdown(_ text: String) -> String {
        var cleaned = text.replacingOccurrences(of: "```", with: "")
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "__", with: "")
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showLetterNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Kluna"
        content.body = isGerman
            ? "Dein Monatsbrief ist da. Kluna hat einen Monat lang zugehört."
            : "Your monthly letter is here. Kluna has been listening for a month."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "kluna_monthly_letter", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

private struct MeMonthlyLetterTeaser: View {
    let letter: MonthlyLetter
    let onTap: () -> Void
    private var isGerman: Bool { Locale.current.language.languageCode?.identifier == "de" }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#E8825C").opacity(0.4))
                        Text(isGerman ? "Dein Monatsbrief" : "Your Monthly Letter")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#3D3229"))
                    }
                    Spacer()
                    Text(letter.monthName)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.15))
                }

                Text(String(letter.text.prefix(80)) + "...")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.3))
                    .lineSpacing(3)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    MeLetterMiniStat(value: "\(letter.entryCount)", label: isGerman ? "Einträge" : "Entries")
                    MeLetterMiniStat(value: "\(letter.activeDays)", label: isGerman ? "Tage" : "Days")
                    MeLetterMiniStat(value: "\(letter.longestStreak)", label: "Streak")
                    if letter.legendaryCards > 0 {
                        MeLetterMiniStat(value: "⭐ \(letter.legendaryCards)", label: isGerman ? "Legendär" : "Legendary")
                    }
                }

                Text(isGerman ? "Brief lesen →" : "Read letter →")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#E8825C").opacity(0.5))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MeLetterMiniStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.5))
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.15))
        }
    }
}

private struct MeMonthlyLetterFullView: View {
    let letter: MonthlyLetter
    @State private var appeared = false
    @State private var textPhase = 0
    @Environment(\.dismiss) private var dismiss
    private var isGerman: Bool { Locale.current.language.languageCode?.identifier == "de" }

    private var paragraphs: [String] {
        letter.text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFF8F0"), KlunaWarm.moodColor(for: letter.dominantMood, fallbackQuadrant: .zufrieden).opacity(0.03), Color(hex: "#FFF8F0")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    VStack(spacing: 8) {
                        Text(letter.monthName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#E8825C").opacity(0.4))
                            .tracking(2)
                            .opacity(appeared ? 1 : 0)

                        Text(isGerman ? "Dein Monatsbrief" : "Your Monthly Letter")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#3D3229"))
                            .opacity(appeared ? 1 : 0)
                    }

                    Spacer().frame(height: 40)

                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                            Text(paragraph)
                                .font(.system(size: 17, design: .serif))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.6))
                                .lineSpacing(8)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(textPhase > index ? 1 : 0)
                                .offset(y: textPhase > index ? 0 : 15)
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 40)

                    if textPhase >= paragraphs.count {
                        MeLetterStatsCard(letter: letter)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        Spacer().frame(height: 24)

                        Button(action: {
                            let data = MonthlyLetterShareData(
                                monthName: letter.monthName,
                                excerpt: shareExcerpt(from: letter.text),
                                entryCount: letter.entryCount,
                                activeDays: letter.activeDays,
                                longestStreak: letter.longestStreak,
                                dominantMood: letter.dominantMood,
                                legendaryCards: letter.legendaryCards,
                                rareCards: letter.rareCards
                            )
                            ShareImageGenerator.share(content: .monthlyLetter(data))
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                                Text(isGerman ? "Brief teilen" : "Share letter")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(Color(hex: "#E8825C").opacity(0.5))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color(hex: "#E8825C").opacity(0.06)))
                        }
                        .transition(.opacity)

                        Spacer().frame(height: 16)

                        Button(action: { dismiss() }) {
                            Text(isGerman ? "Schließen" : "Close")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.15))
                        }
                        .transition(.opacity)
                    }

                    Spacer().frame(height: 80)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appeared = true }
            for i in 0..<paragraphs.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(i) * 0.8) {
                    withAnimation(.easeOut(duration: 0.6)) { textPhase = i + 1 }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(paragraphs.count) * 0.8 + 0.5) {
                withAnimation(.easeOut(duration: 0.6)) { textPhase = paragraphs.count + 1 }
            }
            KlunaAnalytics.shared.track("monthly_letter_read")
        }
    }

    private func shareExcerpt(from text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLen = 140
        if cleaned.count <= maxLen { return cleaned }
        let idx = cleaned.index(cleaned.startIndex, offsetBy: maxLen)
        return String(cleaned[..<idx]) + "…"
    }
}

private struct MeLetterStatsCard: View {
    let letter: MonthlyLetter
    private var isGerman: Bool { Locale.current.language.languageCode?.identifier == "de" }

    var body: some View {
        VStack(spacing: 16) {
            Text(isGerman ? "Dein \(letter.monthName) in Zahlen" : "Your \(letter.monthName) in numbers")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.2))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                MeLetterStat(value: "\(letter.entryCount)", label: isGerman ? "Einträge" : "Entries", icon: "waveform")
                MeLetterStat(value: "\(letter.activeDays)", label: isGerman ? "Aktive Tage" : "Active Days", icon: "calendar")
                MeLetterStat(value: "\(letter.longestStreak)", label: isGerman ? "Bester Streak" : "Best Streak", icon: "flame.fill")
            }

            if letter.legendaryCards > 0 || letter.rareCards > 0 {
                HStack(spacing: 16) {
                    if letter.legendaryCards > 0 {
                        HStack(spacing: 4) {
                            Text("⭐")
                                .font(.system(size: 12))
                            Text("\(letter.legendaryCards) \(isGerman ? "Legendär" : "Legendary")")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#F5B731").opacity(0.6))
                        }
                    }
                    if letter.rareCards > 0 {
                        HStack(spacing: 4) {
                            Text("💎")
                                .font(.system(size: 12))
                            Text("\(letter.rareCards) \(isGerman ? "Selten" : "Rare")")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "#7BA7C4").opacity(0.6))
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(KlunaWarm.moodColor(for: letter.dominantMood, fallbackQuadrant: .zufrieden))
                    .frame(width: 10, height: 10)
                Text(isGerman ? "Am häufigsten: \(letter.dominantMood.capitalized)" : "Most common: \(letter.dominantMood.capitalized)")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.25))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }
}

private struct MeLetterStat: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#E8825C").opacity(0.3))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229"))
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.15))
        }
    }
}

struct MeDayEntry: Identifiable {
    var id: Date { date }
    let date: Date
    let dominantMood: String
    let avgEnergy: Float
    let avgTension: Float
    let avgWarmth: Float
    let avgExpressiveness: Float
    let entryCount: Int
}

@MainActor
final class DailyCardManager {
    static let shared = DailyCardManager()
    private init() {}

    func cardForDate(_ date: Date) -> DailyCard? {
        let dayEntries = KlunaDataManager.shared.entriesForDate(date).sorted(by: { $0.date < $1.date })
        guard !dayEntries.isEmpty else { return nil }

        let avgDims = averageDims(dayEntries)
        let avgRaw = averageRawFeatures(dayEntries)
        let dominantMoodRaw = dayEntries.compactMap { $0.moodLabel ?? $0.mood }.mostFrequent() ?? "ruhig"
        let baseline = baselineDims(excluding: date)
        let zScores = pseudoZScores(for: avgDims, baseline: baseline)
        let title = CardTitleGenerator.generate(dims: avgDims, mood: dominantMoodRaw)
        let primaryColor = KlunaWarm.moodColor(for: dominantMoodRaw, fallbackQuadrant: .zufrieden)
        let atmosphere = generateAtmosphere(dims: avgDims, primaryColor: primaryColor, entryCount: dayEntries.count)
        let rarity = calculateRarity(zScores: zScores)
        let indicators = generateIndicators(dims: avgDims, baseline: baseline)
        let sentence = generateDaySentence(entries: dayEntries, avgDims: avgDims, baseline: baseline)
        let latestEntry = dayEntries.last
        let warmestMoment = dayEntries.max(by: { VoiceDimensions.from($0).warmth < VoiceDimensions.from($1).warmth })?.themes.first

        let moments: [DayMoment] = dayEntries.map { entry in
            DayMoment(
                time: entry.date,
                mood: entry.moodLabel ?? entry.mood ?? "ruhig",
                coachText: entry.coachText ?? "",
                dims: VoiceDimensions.from(entry)
            )
        }

        return DailyCard(
            date: Calendar.current.startOfDay(for: date),
            mood: localizedMood(dominantMoodRaw),
            title: title,
            sentence: sentence,
            insight: latestEntry?.prompt,
            dims: avgDims,
            baseline: baseline,
            primaryColor: primaryColor,
            atmosphereColors: atmosphere,
            rarity: rarity,
            indicators: indicators,
            rawFeatures: avgRaw,
            voiceObservation: latestEntry?.voiceObservation,
            lastSimilarDate: findLastSimilarDate(avgDims, before: date),
            lastSimilarMood: nil,
            warmestMoment: warmestMoment,
            entryNumber: dayEntries.count,
            moments: moments
        )
    }

    func averageDims(_ entries: [JournalEntry]) -> VoiceDimensions {
        let dims = entries.map(VoiceDimensions.from)
        let c = CGFloat(max(1, dims.count))
        return VoiceDimensions(
            energy: dims.map(\.energy).reduce(0, +) / c,
            tension: dims.map(\.tension).reduce(0, +) / c,
            fatigue: dims.map(\.fatigue).reduce(0, +) / c,
            warmth: dims.map(\.warmth).reduce(0, +) / c,
            expressiveness: dims.map(\.expressiveness).reduce(0, +) / c,
            tempo: dims.map(\.tempo).reduce(0, +) / c
        )
    }

    func cardsForLastMonth() -> [DailyCard] {
        let entries = KlunaDataManager.shared.entriesForLastMonth()
        let days = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })
        return days
            .sorted(by: >)
            .compactMap { cardForDate($0) }
    }

    private func averageRawFeatures(_ entries: [JournalEntry]) -> DailyCard.RawFeatures {
        func avg(_ key: String, fallback: Float) -> Float {
            let values = entries.compactMap { $0.rawFeatures[key] }.map(Float.init)
            guard !values.isEmpty else { return fallback }
            return values.reduce(0, +) / Float(values.count)
        }
        return DailyCard.RawFeatures(
            jitter: avg(FeatureKeys.jitter, fallback: 0.02),
            shimmer: avg(FeatureKeys.shimmer, fallback: 0.15),
            hnr: avg(FeatureKeys.hnr, fallback: 3.5),
            speechRate: avg(FeatureKeys.speechRate, fallback: 4.0),
            f0Range: avg(FeatureKeys.f0RangeST, fallback: 5.0),
            pauseDur: avg(FeatureKeys.meanPauseDuration, fallback: avg(FeatureKeys.pauseDuration, fallback: 0.4))
        )
    }

    private func generateDaySentence(entries: [JournalEntry], avgDims: VoiceDimensions, baseline: VoiceDimensions?) -> String {
        let isGerman = Locale.current.language.languageCode?.identifier == "de"
        let count = entries.count
        if count == 1 {
            return entries.first?.coachText ?? (isGerman ? "Dein erster Moment heute." : "Your first moment today.")
        }
        guard let first = entries.first, let last = entries.last else {
            return isGerman ? "Dein Tag in deiner Stimme." : "Your day in your voice."
        }
        let firstMood = localizedMood(first.moodLabel ?? first.mood ?? "ruhig")
        let lastMood = localizedMood(last.moodLabel ?? last.mood ?? "ruhig")
        let firstDims = VoiceDimensions.from(first)
        let lastDims = VoiceDimensions.from(last)
        let tensionChange = lastDims.tension - firstDims.tension
        let warmthChange = lastDims.warmth - firstDims.warmth

        if isGerman {
            if tensionChange < -0.12 && warmthChange > 0.08 {
                return "\(count) Einträge. Von \(firstMood) zu \(lastMood). Der Tag wurde wärmer und ruhiger."
            } else if tensionChange > 0.12 {
                return "\(count) Einträge. \(firstMood) am Anfang, \(lastMood) am Ende. Die Anspannung hat zugenommen."
            } else if warmthChange > 0.12 {
                return "\(count) Einträge. Dein wärmster Tag seit langem."
            } else if warmthChange < -0.12 {
                return "\(count) Einträge. Von \(firstMood) zu \(lastMood)."
            } else {
                return "\(count) Einträge. Durchgehend \(lastMood)."
            }
        }

        if tensionChange < -0.12 && warmthChange > 0.08 {
            return "\(count) entries. From \(firstMood) to \(lastMood). The day got warmer and calmer."
        } else if tensionChange > 0.12 {
            return "\(count) entries. \(firstMood) at first, \(lastMood) at the end. Tension building."
        } else if warmthChange > 0.12 {
            return "\(count) entries. Your warmest day in a while."
        } else {
            return "\(count) entries. Consistently \(lastMood)."
        }
    }

    private func generateIndicators(dims: VoiceDimensions, baseline: VoiceDimensions?) -> [DailyCard.Indicator] {
        guard let base = baseline else { return [] }
        let isGerman = Locale.current.language.languageCode?.identifier == "de"
        var all: [(String, CGFloat, Color)] = [
            (isGerman ? "Energie" : "Energy", dims.energy - base.energy, Color(hex: "F5B731")),
            (isGerman ? "Anspannung" : "Tension", dims.tension - base.tension, Color(hex: "E85C5C")),
            (isGerman ? "Müdigkeit" : "Fatigue", dims.fatigue - base.fatigue, Color(hex: "8B9DAF")),
            (isGerman ? "Wärme" : "Warmth", dims.warmth - base.warmth, Color(hex: "E8825C")),
            (isGerman ? "Lebendigkeit" : "Liveliness", dims.expressiveness - base.expressiveness, Color(hex: "6BC5A0")),
            ("Tempo", dims.tempo - base.tempo, Color(hex: "7BA7C4"))
        ]
        all.sort { abs($0.1) > abs($1.1) }
        return all.prefix(3).map { label, diff, color in
            let arrow: String
            if diff > 0.15 { arrow = "↑↑" }
            else if diff > 0.06 { arrow = "↑" }
            else if diff < -0.15 { arrow = "↓↓" }
            else if diff < -0.06 { arrow = "↓" }
            else { arrow = "→" }
            return DailyCard.Indicator(label: label, arrow: arrow, color: color)
        }
    }

    private func generateAtmosphere(dims: VoiceDimensions, primaryColor: Color, entryCount: Int) -> [Color] {
        var colors: [Color] = [primaryColor.opacity(0.8)]
        if dims.warmth > 0.5 { colors.append(Color(hex: "E8825C").opacity(0.6)) }
        else { colors.append(Color(hex: "8B9DAF").opacity(0.5)) }
        if entryCount >= 3 {
            if dims.energy > 0.5 { colors.append(Color(hex: "F5B731").opacity(0.4)) }
            else { colors.append(Color(hex: "6BC5A0").opacity(0.3)) }
        }
        colors.append(Color(hex: "1A1A2E").opacity(0.5))
        return colors
    }

    private func calculateRarity(zScores: [String: Float]) -> CardRarity {
        let extreme = zScores.values.filter { abs($0) > 1.5 }.count
        let veryExtreme = zScores.values.filter { abs($0) > 2.5 }.count
        if veryExtreme >= 2 { return .legendary }
        if extreme >= 3 { return .rare }
        if extreme >= 1 { return .uncommon }
        return .common
    }

    private func baselineDims(excluding date: Date) -> VoiceDimensions? {
        let calendar = Calendar.current
        let source = KlunaDataManager.shared.entries
            .filter { !calendar.isDate($0.date, inSameDayAs: date) }
            .sorted(by: { $0.date > $1.date })
        let window = Array(source.prefix(30))
        guard window.count >= 5 else { return nil }
        return averageDims(window)
    }

    private func pseudoZScores(for dims: VoiceDimensions, baseline: VoiceDimensions?) -> [String: Float] {
        guard let baseline else { return [:] }
        let scale: CGFloat = 0.18
        return [
            "energy": Float((dims.energy - baseline.energy) / scale),
            "tension": Float((dims.tension - baseline.tension) / scale),
            "fatigue": Float((dims.fatigue - baseline.fatigue) / scale),
            "warmth": Float((dims.warmth - baseline.warmth) / scale),
            "expressiveness": Float((dims.expressiveness - baseline.expressiveness) / scale),
            "tempo": Float((dims.tempo - baseline.tempo) / scale)
        ]
    }

    private func findLastSimilarDate(_ dims: VoiceDimensions, before date: Date) -> String? {
        let calendar = Calendar.current
        let allDays = Set(
            KlunaDataManager.shared.entries
                .filter { $0.date < date }
                .map { calendar.startOfDay(for: $0.date) }
        )
        let sortedDays = allDays.sorted(by: >)
        for day in sortedDays {
            let dayEntries = KlunaDataManager.shared.entriesForDate(day)
            guard !dayEntries.isEmpty else { continue }
            let dayDims = averageDims(dayEntries)
            let distance = abs(dayDims.energy - dims.energy)
                + abs(dayDims.tension - dims.tension)
                + abs(dayDims.warmth - dims.warmth)
                + abs(dayDims.expressiveness - dims.expressiveness)
            if distance < 0.42 {
                return day.formatted(.dateTime.day().month(.wide))
            }
        }
        return nil
    }

    private func localizedMood(_ mood: String) -> String {
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        guard !isGerman else { return mood.capitalized }
        switch mood.lowercased() {
        case "begeistert": return "Excited"
        case "aufgekratzt": return "Energized"
        case "aufgewühlt", "aufgewuehlt": return "Stirred"
        case "angespannt": return "Tense"
        case "frustriert": return "Frustrated"
        case "erschöpft", "erschoepft": return "Exhausted"
        case "verletzlich": return "Vulnerable"
        case "ruhig": return "Calm"
        case "zufrieden": return "Content"
        case "nachdenklich": return "Reflective"
        default: return mood.capitalized
        }
    }
}

struct DailyCard {
    let date: Date
    let mood: String
    let title: String
    let sentence: String
    let insight: String?
    let dims: VoiceDimensions
    let baseline: VoiceDimensions?
    let primaryColor: Color
    let atmosphereColors: [Color]
    let rarity: CardRarity
    let indicators: [Indicator]
    let rawFeatures: RawFeatures?
    let voiceObservation: String?
    let lastSimilarDate: String?
    let lastSimilarMood: String?
    let warmestMoment: String?
    let entryNumber: Int
    let isWeekly: Bool
    let moments: [DayMoment]

    init(
        date: Date,
        mood: String,
        title: String,
        sentence: String,
        insight: String?,
        dims: VoiceDimensions,
        baseline: VoiceDimensions?,
        primaryColor: Color,
        atmosphereColors: [Color],
        rarity: CardRarity,
        indicators: [Indicator],
        rawFeatures: RawFeatures?,
        voiceObservation: String?,
        lastSimilarDate: String?,
        lastSimilarMood: String?,
        warmestMoment: String?,
        entryNumber: Int,
        isWeekly: Bool = false,
        moments: [DayMoment] = []
    ) {
        self.date = date
        self.mood = mood
        self.title = title
        self.sentence = sentence
        self.insight = insight
        self.dims = dims
        self.baseline = baseline
        self.primaryColor = primaryColor
        self.atmosphereColors = atmosphereColors
        self.rarity = rarity
        self.indicators = indicators
        self.rawFeatures = rawFeatures
        self.voiceObservation = voiceObservation
        self.lastSimilarDate = lastSimilarDate
        self.lastSimilarMood = lastSimilarMood
        self.warmestMoment = warmestMoment
        self.entryNumber = entryNumber
        self.isWeekly = isWeekly
        self.moments = moments
    }

    struct RawFeatures {
        let jitter: Float
        let shimmer: Float
        let hnr: Float
        let speechRate: Float
        let f0Range: Float
        let pauseDur: Float
    }

    struct Indicator {
        let label: String
        let arrow: String
        let color: Color
    }
}

struct DayMoment {
    let time: Date
    let mood: String
    let coachText: String
    let dims: VoiceDimensions
}

enum CardRarity: String, Equatable {
    case common, uncommon, rare, legendary

    var label: String {
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        switch self {
        case .common: return isGerman ? "NORMAL" : "COMMON"
        case .uncommon: return isGerman ? "BESONDERS" : "UNCOMMON"
        case .rare: return isGerman ? "SELTEN" : "RARE"
        case .legendary: return isGerman ? "LEGENDÄR" : "LEGENDARY"
        }
    }

    var color: Color {
        switch self {
        case .common: return .white.opacity(0.5)
        case .uncommon: return Color(hex: "6BC5A0")
        case .rare: return Color(hex: "7BA7C4")
        case .legendary: return Color(hex: "F5B731")
        }
    }
}

struct CardPatternView: View {
    let features: CardFeatures
    let primaryColor: Color
    let secondaryColor: Color

    struct CardFeatures {
        let jitter: Float
        let hnr: Float
        let speechRate: Float
        let f0Range: Float
        let pauseDur: Float
        let shimmer: Float
        let energy: Float
        let warmth: Float
        let tension: Float
        let expressiveness: Float
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let seed = CGFloat(features.jitter * 1000 + features.hnr * 100 + features.speechRate * 10)
            drawRings(context: &context, size: size, center: center, seed: seed)
            drawRadials(context: &context, size: size, center: center, seed: seed)
            drawDots(context: &context, size: size, center: center, seed: seed)
            drawBloom(context: &context, center: center, seed: seed)
        }
    }

    private func drawRings(context: inout GraphicsContext, size: CGSize, center: CGPoint, seed: CGFloat) {
        let ringCount = max(3, Int(3 + features.expressiveness * 4))
        let maxRadius = min(size.width, size.height) * 0.34
        for idx in 0..<ringCount {
            let progress = CGFloat(idx) / CGFloat(max(1, ringCount - 1))
            let radius = 34 + maxRadius * progress
            let wobble = CGFloat(features.f0Range) * 4
            let ellipse = CGRect(
                x: center.x - radius - wobble * 0.3,
                y: center.y - radius + sin(seed + CGFloat(idx)) * wobble * 0.2,
                width: (radius * 2) + wobble * 0.6,
                height: radius * 2
            )
            let opacity = 0.03 + Double(1 - progress) * 0.09
            context.stroke(Path(ellipseIn: ellipse), with: .color(primaryColor.opacity(opacity)), lineWidth: 0.8 + CGFloat(features.warmth))
        }
    }

    private func drawRadials(context: inout GraphicsContext, size: CGSize, center: CGPoint, seed: CGFloat) {
        let lineCount = max(6, Int(6 + features.speechRate * 5))
        let innerR: CGFloat = 28 + CGFloat(features.pauseDur) * 12
        let outerR: CGFloat = min(size.width, size.height) * (0.18 + CGFloat(features.energy) * 0.14)
        for idx in 0..<lineCount {
            let angle = (CGFloat(idx) / CGFloat(lineCount)) * .pi * 2 + seed * 0.002
            let offset = sin(seed * 0.01 + CGFloat(idx)) * CGFloat(features.tension) * 0.2
            let start = CGPoint(x: center.x + cos(angle) * innerR, y: center.y + sin(angle) * innerR)
            let end = CGPoint(x: center.x + cos(angle + offset) * outerR, y: center.y + sin(angle + offset) * outerR)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(secondaryColor.opacity(0.04 + Double(features.tension) * 0.05)), lineWidth: 0.8)
        }
    }

    private func drawDots(context: inout GraphicsContext, size: CGSize, center: CGPoint, seed: CGFloat) {
        let dotCount = max(5, Int(5 + features.expressiveness * 10))
        for idx in 0..<dotCount {
            let t = CGFloat(idx) / CGFloat(dotCount)
            let angle = t * .pi * 2 + seed * 0.003
            let radius = min(size.width, size.height) * (0.12 + 0.22 * t)
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            let dotSize = CGFloat(1.6 + features.shimmer * 2.4)
            let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Circle().path(in: rect), with: .color(primaryColor.opacity(0.06 + Double(features.expressiveness) * 0.1)))
        }
    }

    private func drawBloom(context: inout GraphicsContext, center: CGPoint, seed: CGFloat) {
        let petals = max(4, Int(4 + features.warmth * 3))
        for idx in 0..<petals {
            let angle = CGFloat(idx) / CGFloat(petals) * .pi * 2 + seed * 0.001
            let length: CGFloat = 20 + CGFloat(features.energy) * 26
            let width: CGFloat = 8 + CGFloat(features.warmth) * 10
            let end = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
            let cp1 = CGPoint(x: center.x + cos(angle - 0.35) * width, y: center.y + sin(angle - 0.35) * width)
            let cp2 = CGPoint(x: center.x + cos(angle + 0.35) * width, y: center.y + sin(angle + 0.35) * width)
            var path = Path()
            path.move(to: center)
            path.addQuadCurve(to: end, control: cp1)
            path.addQuadCurve(to: center, control: cp2)
            context.fill(path, with: .color(primaryColor.opacity(0.03 + Double(features.warmth) * 0.07)))
        }
    }
}

struct DailyCardView: View {
    let card: DailyCard
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var holographicPhase: CGFloat = 0
    @State private var touchLocation: CGPoint?
    @State private var isTouching = false
    @State private var showShareSheet = false
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        ZStack { isFlipped ? AnyView(cardBack) : AnyView(cardFront) }
            .frame(width: 300, height: 420)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(isTouching ? Double(dragOffset.width) * 0.08 : 0), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(isTouching ? Double(-dragOffset.height) * 0.08 : 0), axis: (x: 1, y: 0, z: 0))
            .shadow(color: card.primaryColor.opacity(0.15), radius: isTouching ? 30 : 20, x: dragOffset.width * 0.1, y: dragOffset.height * 0.1 + 10)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragOffset = value.translation
                        touchLocation = value.location
                        if !isTouching {
                            withAnimation(.spring(response: 0.3)) { isTouching = true }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            dragOffset = .zero
                            isTouching = false
                            touchLocation = nil
                        }
                    }
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { holographicPhase = 1 }
                print("🎨 CARD PATTERN DEBUG:")
                print("🎨 rawFeatures nil: \(card.rawFeatures == nil)")
                if let f = card.rawFeatures {
                    print("🎨 jitter: \(f.jitter), hnr: \(f.hnr), sr: \(f.speechRate)")
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [shareText()])
            }
    }

    private var cardFront: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: card.atmosphereColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.03))

            if let features = card.rawFeatures {
                CardPatternView(
                    features: CardPatternView.CardFeatures(
                        jitter: features.jitter,
                        hnr: features.hnr,
                        speechRate: features.speechRate,
                        f0Range: features.f0Range,
                        pauseDur: features.pauseDur,
                        shimmer: features.shimmer,
                        energy: Float(card.dims.energy),
                        warmth: Float(card.dims.warmth),
                        tension: Float(card.dims.tension),
                        expressiveness: Float(card.dims.expressiveness)
                    ),
                    primaryColor: .white,
                    secondaryColor: card.primaryColor
                )
                .allowsHitTesting(false)
            }

            if isTouching {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0), Color.white.opacity(0.15), Color.white.opacity(0)],
                            startPoint: UnitPoint(x: ((touchLocation?.x ?? 150) / 300) - 0.3, y: ((touchLocation?.y ?? 210) / 420) - 0.3),
                            endPoint: UnitPoint(x: ((touchLocation?.x ?? 150) / 300) + 0.3, y: ((touchLocation?.y ?? 210) / 420) + 0.3)
                        )
                    )
            }

            RoundedRectangle(cornerRadius: 24)
                .fill(
                    AngularGradient(
                        colors: [Color.clear, Color.white.opacity(0.04), Color.clear, Color.white.opacity(0.02), Color.clear],
                        center: .center,
                        startAngle: .degrees(holographicPhase * 360),
                        endAngle: .degrees(holographicPhase * 720)
                    )
                )

            VStack(spacing: 0) {
                HStack {
                    if card.entryNumber > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.system(size: 9))
                            Text("×\(card.entryNumber)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.25))
                        .padding(.top, 20)
                        .padding(.leading, 20)
                    }
                    Spacer()
                    RarityBadge(rarity: card.rarity).padding(.top, 20).padding(.trailing, 20)
                }
                Spacer()
                ZStack {
                    Circle().stroke(card.primaryColor.opacity(0.15), lineWidth: 1.5).frame(width: 90, height: 90)
                    Circle().fill(RadialGradient(colors: [card.primaryColor.opacity(0.2), .clear], center: .center, startRadius: 20, endRadius: 60)).frame(width: 120, height: 120)
                    Circle().fill(RadialGradient(colors: [card.primaryColor.opacity(0.7), card.primaryColor], center: .init(x: 0.35, y: 0.35), startRadius: 0, endRadius: 32)).frame(width: 64, height: 64)
                    Circle().fill(RadialGradient(colors: [Color.white.opacity(0.35), .clear], center: .init(x: 0.3, y: 0.3), startRadius: 0, endRadius: 22)).frame(width: 64, height: 64)
                }
                Spacer().frame(height: 20)
                Text(card.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                Spacer().frame(height: 8)
                Text(card.mood)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Spacer().frame(height: 6)
                Spacer()

                if !card.indicators.isEmpty {
                    HStack(spacing: 16) {
                        ForEach(Array(card.indicators.prefix(3).enumerated()), id: \.offset) { _, indicator in
                            BaselineIndicator(indicator: indicator)
                        }
                    }
                    .padding(.bottom, 16)
                }
                HStack {
                    Text(card.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.25))
                    Spacer()
                    Button(action: flipCard) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                            Text(isGerman ? "Umdrehen" : "Flip")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var cardBack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Spacer().frame(height: 20)

                    HStack {
                        Text(card.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.2))
                        Spacer()
                        if card.entryNumber > 1 {
                            Text(isGerman ? "\(card.entryNumber) Einträge" : "\(card.entryNumber) entries")
                            .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.white.opacity(0.12))
                        }
                    }
                    .padding(.horizontal, 20)

                    if card.moments.count > 1 {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(isGerman ? "DEIN TAG" : "YOUR DAY")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(2)
                                .foregroundColor(.white.opacity(0.12))
                                .padding(.bottom, 10)

                            ForEach(Array(card.moments.enumerated()), id: \.offset) { index, moment in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(spacing: 0) {
                                        Circle()
                                            .fill(KlunaWarm.moodColor(for: moment.mood, fallbackQuadrant: .zufrieden))
                                            .frame(width: 10, height: 10)

                                        if index < card.moments.count - 1 {
                                            Rectangle()
                                                .fill(.white.opacity(0.06))
                                                .frame(width: 1.5)
                                                .frame(minHeight: 30)
                                        }
                                    }
                                    .frame(width: 10)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(moment.time.formatted(.dateTime.hour().minute()))
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.3))

                                            Text(localizedMood(moment.mood))
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(KlunaWarm.moodColor(for: moment.mood, fallbackQuadrant: .zufrieden).opacity(0.6))
                                        }

                                        if !moment.coachText.isEmpty {
                                            Text(moment.coachText)
                                                .font(.system(size: 12, design: .rounded))
                                                .foregroundColor(.white.opacity(0.2))
                                                .lineLimit(2)
                                                .lineSpacing(2)
                                        }
                                    }
                                    .padding(.bottom, index < card.moments.count - 1 ? 8 : 0)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        Rectangle().fill(.white.opacity(0.04)).frame(height: 1).padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(isGerman ? "DEINE STIMME VS. NORMAL" : "YOUR VOICE VS. NORMAL")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.12))

                        BaselineDimBar(label: isGerman ? "Energie" : "Energy", value: Float(card.dims.energy), baseline: card.baseline.map { Float($0.energy) }, color: Color(hex: "F5B731"))
                        BaselineDimBar(label: isGerman ? "Anspannung" : "Tension", value: Float(card.dims.tension), baseline: card.baseline.map { Float($0.tension) }, color: Color(hex: "E85C5C"))
                        BaselineDimBar(label: isGerman ? "Müdigkeit" : "Fatigue", value: Float(card.dims.fatigue), baseline: card.baseline.map { Float($0.fatigue) }, color: Color(hex: "8B9DAF"))
                        BaselineDimBar(label: isGerman ? "Wärme" : "Warmth", value: Float(card.dims.warmth), baseline: card.baseline.map { Float($0.warmth) }, color: Color(hex: "E8825C"))
                        BaselineDimBar(label: isGerman ? "Lebendigkeit" : "Liveliness", value: Float(card.dims.expressiveness), baseline: card.baseline.map { Float($0.expressiveness) }, color: Color(hex: "6BC5A0"))
                        BaselineDimBar(label: "Tempo", value: Float(card.dims.tempo), baseline: card.baseline.map { Float($0.tempo) }, color: Color(hex: "7BA7C4"))
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        if let voice = card.voiceObservation, !voice.isEmpty {
                            InsightRow(icon: "waveform", text: voice, color: card.primaryColor)
                        }
                        if let warm = card.warmestMoment, !warm.isEmpty {
                            InsightRow(
                                icon: "heart.fill",
                                text: isGerman ? "Am wärmsten bei: \"\(warm)\"" : "Warmest at: \"\(warm)\"",
                                color: Color(hex: "E8825C")
                            )
                        }
                        if let lastDate = card.lastSimilarDate {
                            InsightRow(
                                icon: "clock.arrow.circlepath",
                                text: isGerman ? "Klingt ähnlich wie am \(lastDate)" : "Sounds similar to \(lastDate)",
                                color: Color(hex: "7BA7C4")
                            )
                        }
                        if let lastMood = card.lastSimilarMood, !lastMood.isEmpty {
                            InsightRow(
                                icon: "face.smiling",
                                text: isGerman ? "Ähnliche Stimmung: \(lastMood)" : "Similar mood: \(lastMood)",
                                color: Color(hex: "6BC5A0")
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 12)

                    HStack {
                        Button(action: shareCard) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 11))
                                Text(isGerman ? "Teilen" : "Share")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.25))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.05)))
                        }

                        Spacer()

                        Button(action: flipCard) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                Text(isGerman ? "Zurück" : "Back")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.25))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.05)))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 20)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
    }

    private func baselineText(for indicator: DailyCard.Indicator) -> String {
        switch indicator.arrow {
        case "↑↑": return isGerman ? "deutlich über Basis" : "well above baseline"
        case "↑": return isGerman ? "über Basis" : "above baseline"
        case "↓↓": return isGerman ? "deutlich unter Basis" : "well below baseline"
        case "↓": return isGerman ? "unter Basis" : "below baseline"
        default: return isGerman ? "nah an Basis" : "near baseline"
        }
    }

    private func shareCard() {
        showShareSheet = true
        KlunaAnalytics.shared.track("share_triggered", value: "dailyCard")
    }

    private func flipCard() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { isFlipped.toggle() }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func shareText() -> String {
        let date = card.date.formatted(.dateTime.day().month(.wide))
        return isGerman
            ? "Meine Kluna Daily Card (\(date)): \(card.title) · \(card.mood) · \(card.sentence)"
            : "My Kluna Daily Card (\(date)): \(card.title) · \(card.mood) · \(card.sentence)"
    }

    private func localizedMood(_ mood: String) -> String {
        let normalized = mood.lowercased()
        if isGerman { return mood.capitalized }
        switch normalized {
        case "begeistert": return "Excited"
        case "aufgekratzt": return "Energized"
        case "aufgewühlt", "aufgewuehlt": return "Stirred"
        case "angespannt": return "Tense"
        case "frustriert": return "Frustrated"
        case "erschöpft", "erschoepft": return "Exhausted"
        case "verletzlich": return "Vulnerable"
        case "ruhig": return "Calm"
        case "zufrieden": return "Content"
        case "nachdenklich": return "Reflective"
        default: return mood.capitalized
        }
    }

}

struct DailyCardDimensionBar: View {
    let label: String
    let value: CGFloat
    let baseline: CGFloat?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                if let baseline {
                    let diff = value - baseline
                    if abs(diff) > 0.08 {
                        HStack(spacing: 3) {
                            Image(systemName: diff > 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                            Text(abs(diff) > 0.15 ? (diff > 0 ? "++" : "--") : (diff > 0 ? "+" : "-"))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(color.opacity(0.6))
                    } else {
                        Text("=").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.15))
                    }
                }
            }
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.06)).frame(height: 6)
                if let baseline {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 2, height: 12)
                            .offset(x: geo.size.width * baseline - 1, y: -3)
                    }
                    .frame(height: 6)
                }
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.4), color.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, value * 240), height: 6)
            }
        }
    }
}

struct RarityBadge: View {
    let rarity: CardRarity

    var body: some View {
        Text(rarity.label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(1.5)
            .foregroundColor(rarity.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(rarity.color.opacity(0.12))
                    .overlay(Capsule().stroke(rarity.color.opacity(0.2), lineWidth: 0.5))
            )
    }
}

struct BaselineIndicator: View {
    let indicator: DailyCard.Indicator

    var body: some View {
        VStack(spacing: 4) {
            Text(indicator.arrow)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(indicator.color)
            Text(indicator.label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
        }
    }
}

struct InsightRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color.opacity(0.4))
                .frame(width: 16, alignment: .center)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.white.opacity(0.35))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct BaselineDimBar: View {
    let label: String
    let value: Float
    let baseline: Float?
    let color: Color
    private var isGerman: Bool { Locale.current.language.languageCode?.identifier == "de" }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))

                Spacer()

                if let base = baseline {
                    let diff = value - base
                    if abs(diff) > 0.06 {
                        Text(diff > 0 ? (isGerman ? "über Normal" : "above normal") : (isGerman ? "unter Normal" : "below normal"))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(color.opacity(0.4))
                    } else {
                        Text(isGerman ? "normal" : "normal")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.15))
                    }
                }
            }

            GeometryReader { geo in
                let barWidth = geo.size.width

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.05))
                        .frame(height: 6)

                    if let base = baseline {
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 2, height: 14)
                            .offset(x: barWidth * CGFloat(base) - 1, y: -4)
                    }

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, barWidth * CGFloat(value)), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct MiniDimBar: View {
    let label: String
    let value: Float
    let baseline: Float?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
                if let b = baseline {
                    let diff = value - b
                    if abs(diff) > 0.08 {
                        Image(systemName: diff > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(color.opacity(0.5))
                    }
                }
            }

            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.04)).frame(height: 4)
                if let b = baseline {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 1.5, height: 8)
                            .offset(x: geo.size.width * CGFloat(b) - 0.75, y: -2)
                    }
                    .frame(height: 4)
                }
                Capsule()
                    .fill(color.opacity(0.5))
                    .frame(width: max(3, CGFloat(value) * 80), height: 4)
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CardGalleryView: View {
    let cards: [DailyCard]
    @State private var currentIndex: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                Button(action: {
                    guard currentIndex > 0 else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentIndex -= 1
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(
                            currentIndex > 0
                                ? Color(hex: "#3D3229").opacity(0.15)
                                : Color(hex: "#3D3229").opacity(0.04)
                        )
                        .frame(width: 36, height: 420)
                        .contentShape(Rectangle())
                }
                .disabled(currentIndex == 0)

                TabView(selection: $currentIndex) {
                    ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                        DailyCardView(card: card)
                            .frame(width: 300, height: 420)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: 300, height: 440)
                .onChange(of: currentIndex) { _, _ in
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }

                Button(action: {
                    guard currentIndex < cards.count - 1 else { return }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        currentIndex += 1
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(
                            currentIndex < cards.count - 1
                                ? Color(hex: "#3D3229").opacity(0.15)
                                : Color(hex: "#3D3229").opacity(0.04)
                        )
                        .frame(width: 36, height: 420)
                        .contentShape(Rectangle())
                }
                .disabled(currentIndex >= cards.count - 1)
            }

            if cards.count > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<min(cards.count, 20), id: \.self) { i in
                        Circle()
                            .fill(
                                i == currentIndex
                                    ? (i < cards.count ? cards[i].primaryColor : Color(hex: "E8825C"))
                                    : Color(hex: "3D3229").opacity(0.08)
                            )
                            .frame(width: i == currentIndex ? 7 : 4, height: i == currentIndex ? 7 : 4)
                    }
                }
            }

            if currentIndex < cards.count {
                let current = cards[currentIndex]
                VStack(spacing: 2) {
                    Text(current.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.2))
                    Text("\(currentIndex + 1) / \(cards.count)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.1))
                }
            }
        }
    }
}

struct SoulTimelineView: View {
    struct DailySnapshot: Identifiable {
        var id: Date { date }
        let date: Date
        let dims: VoiceDimensions
        let mood: String
        let subtitle: String
        let entryCount: Int
    }

    let dailySnapshots: [DailySnapshot]
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(spacing: 0) {
            if selectedIndex < dailySnapshots.count, selectedIndex >= 0 {
                let snap = dailySnapshots[selectedIndex]
                SoulView(dims: snap.dims, mood: snap.mood, subtitle: snap.subtitle, entryCount: snap.entryCount)
            }

            Spacer().frame(height: 20)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(dailySnapshots.enumerated()), id: \.offset) { index, snap in
                            let isSelected = index == selectedIndex
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    selectedIndex = index
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(KlunaWarm.moodColor(for: snap.mood, fallbackQuadrant: .zufrieden).opacity(isSelected ? 0.14 : 0.04))
                                            .frame(width: 36, height: 36)
                                        Circle()
                                            .fill(KlunaWarm.moodColor(for: snap.mood, fallbackQuadrant: .zufrieden).opacity(isSelected ? 1.0 : 0.35))
                                            .frame(width: isSelected ? 18 : 10, height: isSelected ? 18 : 10)
                                    }
                                    Text(dayLabel(snap.date))
                                        .font(.system(size: 10, weight: isSelected ? .bold : .regular, design: .rounded))
                                        .foregroundStyle(isSelected ? KlunaWarm.warmBrown.opacity(0.55) : KlunaWarm.warmBrown.opacity(0.2))
                                }
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .background(Color.clear)
    }

    private func dayLabel(_ date: Date) -> String {
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        if Calendar.current.isDateInToday(date) { return isGerman ? "Heute" : "Today" }
        if Calendar.current.isDateInYesterday(date) { return isGerman ? "Gestern" : "Yesterday" }
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "EE"
        return fmt.string(from: date)
    }
}

struct SoulView: View {
    let dims: VoiceDimensions
    let mood: String
    let subtitle: String
    let entryCount: Int

    @State private var phase: CGFloat = 0
    @State private var breathe: CGFloat = 1.0
    @State private var appeared = false
    @State private var touchLocation: CGPoint?
    @State private var isTouching = false
    @State private var isLongPressing = false
    @State private var showDimensionWords = false
    @State private var ripples: [RippleState] = []
    @State private var showHint = false
    @State private var showTouchHint = false
    @AppStorage("kluna_seen_blob_hint") private var hasSeenHint = false
    @AppStorage("kluna_seen_touch_hint") private var hasSeenTouchHint = false

    private var primaryColor: Color { KlunaWarm.moodColor(for: mood, fallbackQuadrant: .zufrieden) }
    private var secondaryColor: Color {
        if dims.warmth > 0.6 { return Color(hex: "E8825C") }
        if dims.tension > 0.6 { return Color(hex: "E85C5C") }
        if dims.fatigue > 0.6 { return Color(hex: "8B9DAF") }
        if dims.energy > 0.6 { return Color(hex: "F5B731") }
        return Color(hex: "6BC5A0")
    }

    private var blobSize: CGFloat { 120 + dims.energy * 30 + dims.expressiveness * 20 }

    private var animationSpeed: Double {
        let base = 4.0
        let tempoFactor = Double(1.0 - dims.fatigue) * 2.0
        return max(1.8, base - tempoFactor)
    }

    private var distortion: CGFloat { dims.tension * 20 }
    private var touchElasticity: CGFloat { 0.7 + dims.energy * 0.6 }
    private var touchViscosity: CGFloat { 0.6 + dims.fatigue * 0.8 }
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    private var normalizedTouch: CGPoint {
        guard let touchLocation else { return CGPoint(x: 0.5, y: 0.5) }
        let frame = blobSize * 1.8
        return CGPoint(
            x: max(0, min(1, touchLocation.x / frame)),
            y: max(0, min(1, touchLocation.y / frame))
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    BlobShape(
                        phase: phase + CGFloat(i) * 0.3,
                        distortion: distortion * 0.3,
                        touchPoint: normalizedTouch,
                        touchIntensity: isTouching ? 0.3 : 0,
                        elasticity: touchElasticity,
                        viscosity: touchViscosity
                    )
                        .fill(
                            RadialGradient(
                                colors: [primaryColor.opacity(0.06 - Double(i) * 0.015), Color.clear],
                                center: .center,
                                startRadius: blobSize * 0.3,
                                endRadius: blobSize * (0.9 + CGFloat(i) * 0.2)
                            )
                        )
                        .frame(
                            width: blobSize * (1.3 + CGFloat(i) * 0.2) * breathe,
                            height: blobSize * (1.3 + CGFloat(i) * 0.2) * breathe
                        )
                }

                ForEach(ripples) { ripple in
                    Circle()
                        .stroke(primaryColor.opacity(ripple.opacity), lineWidth: 2)
                        .frame(
                            width: blobSize * 0.3 + ripple.scale * blobSize * 0.9,
                            height: blobSize * 0.3 + ripple.scale * blobSize * 0.9
                        )
                        .position(ripple.position)
                }

                BlobShape(
                    phase: phase,
                    distortion: isTouching ? distortion * 2.0 : distortion,
                    touchPoint: normalizedTouch,
                    touchIntensity: isTouching ? 0.6 : 0,
                    elasticity: touchElasticity,
                    viscosity: touchViscosity
                )
                    .fill(blobFill())
                    .frame(
                        width: blobSize * breathe * (isTouching ? 1.12 : 1.0),
                        height: blobSize * breathe * (isTouching ? 1.12 : 1.0)
                    )
                    .shadow(color: primaryColor.opacity(isTouching ? 0.25 : 0.15), radius: isTouching ? 40 : 30, x: 0, y: 15)

                BlobShape(
                    phase: phase + 1.0,
                    distortion: distortion * 0.5,
                    touchPoint: normalizedTouch,
                    touchIntensity: isTouching ? 0.3 : 0,
                    elasticity: touchElasticity,
                    viscosity: touchViscosity
                )
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(isTouching ? 0.35 : 0.25), Color.clear],
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: blobSize * 0.4
                        )
                    )
                    .frame(width: blobSize * 0.8 * breathe, height: blobSize * 0.7 * breathe)
                    .offset(x: -blobSize * 0.05, y: -blobSize * 0.08)

                if dims.expressiveness > 0.3 || isTouching {
                    let particleCount = isTouching ? 12 : max(3, Int(dims.expressiveness * 8))
                    ForEach(0..<particleCount, id: \.self) { i in
                        Circle()
                            .fill(i.isMultiple(of: 2) ? primaryColor.opacity(0.2) : secondaryColor.opacity(0.15))
                            .frame(width: 3 + CGFloat((i % 4)), height: 3 + CGFloat((i % 4)))
                            .offset(
                                x: cos(phase * (1.2 + CGFloat(i) * 0.15) + CGFloat(i) * 1.1) * blobSize * (isTouching ? 0.7 : 0.5),
                                y: sin(phase * (1.0 + CGFloat(i) * 0.12) + CGFloat(i) * 0.8) * blobSize * (isTouching ? 0.6 : 0.45)
                            )
                            .blur(radius: 0.5)
                    }
                }

                if showDimensionWords {
                    DimensionWordsOverlay(
                        dims: dims,
                        blobSize: blobSize,
                        phase: phase,
                        primaryColor: primaryColor
                    )
                    .transition(.opacity)
                }
            }
            .frame(width: blobSize * 1.6, height: blobSize * 1.6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        touchLocation = value.location
                        if !isTouching {
                            let response = max(0.2, 0.25 + Double(touchViscosity - 1.0) * 0.16)
                            let damping = max(0.35, min(0.75, 0.52 - Double(touchElasticity - 1.0) * 0.18 + Double(touchViscosity - 1.0) * 0.22))
                            withAnimation(.spring(response: response, dampingFraction: damping)) {
                                isTouching = true
                            }
                            if !hasSeenTouchHint { hasSeenTouchHint = true }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            triggerRipples(at: value.location)
                        }
                    }
                    .onEnded { _ in
                        let response = max(0.3, 0.4 + Double(touchViscosity - 1.0) * 0.2)
                        let damping = max(0.35, min(0.75, 0.4 + Double(touchViscosity - 1.0) * 0.14))
                        withAnimation(.spring(response: response, dampingFraction: damping)) {
                            isTouching = false
                            touchLocation = nil
                            isLongPressing = false
                        }
                        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                            showDimensionWords = false
                        }
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showDimensionWords = true
                            isLongPressing = true
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
            )
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.6)

            Text(mood)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryColor.opacity(0.75))
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 6)

            Text(subtitle)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)

            if !hasSeenHint && showHint {
                Text(isGerman
                    ? "Das bist du. Dein Stimmwesen verändert sich mit dir."
                    : "This is you. Your soul shape changes with you.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation { hasSeenHint = true; showHint = false }
                        }
                    }
            }

            if !hasSeenTouchHint && showHint && appeared {
                VStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.1))
                        .offset(y: showTouchHint ? 0 : -4)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: showTouchHint)
                    Text(isGerman ? "Berühr mich" : "Touch me")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.1))
                }
                .padding(.top, 8)
                .onAppear { showTouchHint = true }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(Color.clear)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.12)) { appeared = true }
            if !hasSeenHint {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showHint = true }
                }
            }
            withAnimation(.easeInOut(duration: animationSpeed + Double(touchViscosity - 1.0) * 0.6).repeatForever(autoreverses: true)) {
                breathe = 1.05
            }
            withAnimation(.linear(duration: animationSpeed * 3).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }

    private func blobFill() -> AnyShapeStyle {
        if #available(iOS 18.0, *) {
            return AnyShapeStyle(
                MeshGradient(
                    width: 3,
                    height: 3,
                    points: [
                        SIMD2<Float>(0, 0), SIMD2<Float>(0.5 + Float(sin(phase) * 0.1), 0), SIMD2<Float>(1, 0),
                        SIMD2<Float>(0, 0.5 + Float(cos(phase) * 0.1)), SIMD2<Float>(0.5, 0.5), SIMD2<Float>(1, 0.5 + Float(sin(phase * 0.7) * 0.1)),
                        SIMD2<Float>(0, 1), SIMD2<Float>(0.5 + Float(cos(phase * 0.5) * 0.1), 1), SIMD2<Float>(1, 1),
                    ],
                    colors: [
                        primaryColor.opacity(0.7), primaryColor, secondaryColor.opacity(0.6),
                        secondaryColor.opacity(0.5), primaryColor.opacity(0.9), primaryColor.opacity(0.6),
                        secondaryColor.opacity(0.4), primaryColor.opacity(0.5), secondaryColor.opacity(0.7),
                    ]
                )
            )
        }
        return AnyShapeStyle(
            RadialGradient(
                colors: [primaryColor.opacity(0.7), primaryColor, secondaryColor.opacity(0.5)],
                center: .init(x: 0.4 + sin(phase) * 0.1, y: 0.4 + cos(phase) * 0.1),
                startRadius: 0,
                endRadius: blobSize * 0.5
            )
        )
    }

    private func triggerRipples(at position: CGPoint) {
        for delay in [0.0, 0.15, 0.3] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let ripple = RippleState(position: position, scale: 0.3, opacity: 0.3)
                ripples.append(ripple)
                withAnimation(.easeOut(duration: 1.0)) {
                    if let idx = ripples.firstIndex(where: { $0.id == ripple.id }) {
                        ripples[idx].scale = 1.5
                        ripples[idx].opacity = 0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ripples.removeAll(where: { $0.id == ripple.id })
                }
            }
        }
    }
}

private struct RippleState: Identifiable {
    let id = UUID()
    var position: CGPoint
    var scale: CGFloat
    var opacity: Double
}

struct BlobShape: Shape {
    var phase: CGFloat
    var distortion: CGFloat
    var touchPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var touchIntensity: CGFloat = 0
    var elasticity: CGFloat = 1.0
    var viscosity: CGFloat = 1.0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, distortion) }
        set { phase = newValue.first; distortion = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let points = 120
        var path = Path()
        for i in 0...points {
            let angle = (CGFloat(i) / CGFloat(points)) * .pi * 2
            let noise1 = sin(angle * 3 + phase) * distortion * 0.15
            let noise2 = cos(angle * 2 + phase * 0.7) * distortion * 0.1
            let noise3 = sin(angle * 5 + phase * 1.3) * distortion * 0.05
            let noise4 = cos(angle * 7 + phase * 0.5) * distortion * 0.03
            var r = radius + noise1 + noise2 + noise3 + noise4

            if touchIntensity > 0 {
                let pointOnCircle = CGPoint(x: 0.5 + cos(angle) * 0.5, y: 0.5 + sin(angle) * 0.5)
                let dx = pointOnCircle.x - touchPoint.x
                let dy = pointOnCircle.y - touchPoint.y
                let distance = sqrt(dx * dx + dy * dy)
                let influence = max(0, 1.0 - distance * 2.5) * touchIntensity
                let stretch = 0.18 + (elasticity - 1.0) * 0.15
                let drag = 0.12 + (viscosity - 1.0) * 0.10
                r += influence * radius * stretch
                let oppositeInfluence = max(0, distance - 0.7) * touchIntensity * drag
                r -= oppositeInfluence * radius * (0.08 + (viscosity - 1.0) * 0.06)
            }

            let x = center.x + cos(angle) * r
            let y = center.y + sin(angle) * r
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}

struct DimensionWordsOverlay: View {
    let dims: VoiceDimensions
    let blobSize: CGFloat
    let phase: CGFloat
    let primaryColor: Color
    @State private var wordAppeared = false
    private let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"

    private var words: [(String, CGFloat, CGFloat)] {
        [
            (isGerman ? "warm" : "warm", dims.warmth, 0),
            (isGerman ? "lebendig" : "alive", dims.expressiveness, .pi * 0.33),
            (isGerman ? "ruhig" : "calm", 1.0 - dims.tension, .pi * 0.67),
            (isGerman ? "stark" : "strong", dims.energy, .pi),
            (isGerman ? "klar" : "clear", 1.0 - dims.fatigue, .pi * 1.33),
            (isGerman ? "schnell" : "fast", dims.tempo, .pi * 1.67)
        ].filter { $0.1 > 0.4 }
    }

    var body: some View {
        ForEach(Array(words.enumerated()), id: \.offset) { index, word in
            let (text, value, baseAngle) = word
            let angle = baseAngle + sin(phase * 0.3 + CGFloat(index)) * 0.15
            let radius = blobSize * (0.65 + value * 0.15)
            Text(text)
                .font(.system(size: 12 + value * 10, weight: value > 0.65 ? .bold : .medium, design: .rounded))
                .foregroundStyle(primaryColor.opacity(value * 0.7))
                .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                .scaleEffect(wordAppeared ? 1.0 : 0.5)
                .opacity(wordAppeared ? 1.0 : 0)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(Double(index) * 0.06), value: phase)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { wordAppeared = true }
        }
        .onDisappear { wordAppeared = false }
    }
}

struct SoulDimDot: View {
    let label: String
    let value: Float
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(color.opacity(0.06)).frame(width: 28, height: 28)
                Circle()
                    .fill(color.opacity(Double(value) * 0.5 + 0.1))
                    .frame(width: CGFloat(8 + value * 16), height: CGFloat(8 + value * 16))
            }
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
        }
    }
}

struct EmotionalWeekView: View {
    let entries: [MeDayEntry]
    @Binding var selectedDay: Date?
    @State private var rowNudge: CGFloat = 0

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("me.week.title".localized)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Spacer()
                Text(weekRange())
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
            }

            ZStack {
                Capsule()
                    .fill(KlunaWarm.warmBrown.opacity(0.06))
                    .frame(height: 2)
                    .padding(.horizontal, 26)
                    .offset(y: 6)

                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { dayOffset in
                        let date = Calendar.current.date(byAdding: .day, value: dayOffset - 6, to: Date()) ?? Date()
                        let dayData = entries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
                        let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: date) } == true
                        VStack(spacing: 6) {
                            Text(dayAbbrev(date))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Calendar.current.isDateInToday(date) ? KlunaWarm.warmAccent : KlunaWarm.warmBrown.opacity(0.2))

                            Button {
                                guard dayData != nil else { return }
                            let previousDay = selectedDay.map { Calendar.current.startOfDay(for: $0) }
                            let targetDay = Calendar.current.startOfDay(for: date)
                            let direction: CGFloat = {
                                guard let previousDay else { return 1 }
                                return targetDay >= previousDay ? 1 : -1
                            }()

                            withAnimation(.easeOut(duration: 0.12)) {
                                rowNudge = direction * -8
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                    rowNudge = 0
                                }
                            }

                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    selectedDay = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: date) ? nil : date } ?? date
                                }
                            if previousDay == nil {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } else if direction >= 0 {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            } else {
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            }
                            } label: {
                                if let dayData {
                                    let color = KlunaWarm.moodColor(for: dayData.dominantMood, fallbackQuadrant: .zufrieden)
                                    let size: CGFloat = 28 + CGFloat(dayData.avgExpressiveness) * 20
                                    ZStack {
                                        if isSelected {
                                            Circle()
                                                .fill(color.opacity(0.12))
                                                .frame(width: size + 16, height: size + 16)
                                        }
                                        Circle()
                                            .fill(
                                                RadialGradient(
                                                    colors: [color.opacity(0.7), color],
                                                    center: .init(x: 0.35, y: 0.35),
                                                    startRadius: 0,
                                                    endRadius: size / 2
                                                )
                                            )
                                            .frame(width: size, height: size)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
                                            )
                                    }
                                    .scaleEffect(isSelected ? 1.05 : 1.0)
                                    .frame(width: 48, height: 48)
                                } else {
                                    Circle()
                                        .fill(KlunaWarm.warmBrown.opacity(0.04))
                                        .frame(width: 28, height: 28)
                                        .frame(width: 48, height: 48)
                                }
                            }
                            .buttonStyle(.plain)

                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.16))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .offset(x: rowNudge)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.05), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(KlunaWarm.warmBrown.opacity(0.04), lineWidth: 1)
        )
    }

    private func dayAbbrev(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale.current
        return String(formatter.string(from: date).prefix(2))
    }

    private func weekRange() -> String {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -6, to: end) ?? end
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.setLocalizedDateFormatFromTemplate("d MMM")
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }
}

struct DayCardView: View {
    let entries: [JournalEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let first = entries.first {
                Text(first.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
            }

            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(entry.date.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                        Text(entry.moodLabel ?? entry.mood ?? "mood.ruhig".localized)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(entry.stimmungsfarbe.opacity(0.8))
                    }
                    if let text = entry.coachText, !text.isEmpty {
                        Text(text)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmAccent.opacity(0.8))
                            .lineSpacing(4)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)

                        CoachFeedbackView(entry: entry)
                    }
                }
                if entry.id != entries.last?.id {
                    Rectangle()
                        .fill(KlunaWarm.warmBrown.opacity(0.04))
                        .frame(height: 1)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.05), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(KlunaWarm.warmBrown.opacity(0.04), lineWidth: 1)
        )
    }
}

struct HighlightCardView: View {
    struct WeeklyHighlight {
        let text: String
        let icon: String
        let color: Color
    }

    let highlight: WeeklyHighlight

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(highlight.color.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: highlight.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(highlight.color.opacity(0.8))
            }
            Text(highlight.text)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                .lineSpacing(4)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

struct SurpriseCardView: View {
    enum SurpriseType {
        case warmth, change, pattern, record
    }

    struct DailySurprise {
        let text: String
        let type: SurpriseType
    }

    let surprise: DailySurprise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("✨")
                Text("me.surprise.header".localized)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: "F5B731"))
            }
            Text(surprise.text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                .lineSpacing(5)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "F5B731").opacity(0.05), KlunaWarm.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: KlunaWarm.warmBrown.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "F5B731").opacity(0.22), lineWidth: 1)
        )
    }
}

struct MeMemoryLayersView: View {
    let memory: KlunaMemory
    @State private var expandedLayer: Int?

    var body: some View {
        let layers = memory.layersForUI
        VStack(alignment: .leading, spacing: 14) {
            Text("me.memory.title".localized)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)

            ForEach(Array(layers.enumerated()), id: \.offset) { index, layer in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            expandedLayer = (expandedLayer == index) ? nil : index
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: layer.icon)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(KlunaWarm.warmAccent.opacity(0.75))
                            Text(layer.title)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown)
                            Spacer()
                            Image(systemName: expandedLayer == index ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
                        }
                    }
                    .buttonStyle(.plain)

                    if expandedLayer == index {
                        Text(layer.text)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if index < layers.count - 1 {
                    Rectangle()
                        .fill(KlunaWarm.warmBrown.opacity(0.04))
                        .frame(height: 1)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.05), radius: 12, x: 0, y: 6)
        )
    }
}

struct PeopleMapView: View {
    let emotionalMap: String
    @State private var expanded = false

    private var people: [(name: String, reaction: String)] {
        let sentences = emotionalMap.components(separatedBy: ". ")
        return sentences.compactMap { sentence in
            if let beiRange = sentence.range(of: "Bei "),
               let colonRange = sentence.range(of: ":") {
                let name = String(sentence[beiRange.upperBound..<colonRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let reaction = String(sentence[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (name, reaction)
            }
            if let withRange = sentence.range(of: "With "),
               let colonRange = sentence.range(of: ":") {
                let name = String(sentence[withRange.upperBound..<colonRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let reaction = String(sentence[colonRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (name, reaction)
            }
            return nil
        }
    }

    var body: some View {
        if !people.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("me.people.title".localized)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Spacer()
                    Text("\(people.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "6BC5A0").opacity(0.6))
                }

                ForEach(Array(people.prefix(expanded ? people.count : 3).enumerated()), id: \.offset) { _, person in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(reactionColor(person.reaction).opacity(0.12))
                                .frame(width: 38, height: 38)
                            Text(String(person.name.prefix(1)))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(reactionColor(person.reaction))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown)
                            Text(person.reaction)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                }

                if people.count > 3 {
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { expanded.toggle() }
                    } label: {
                        Text(expanded ? "me.people.less".localized : String(format: "me.people.show_all".localized, people.count))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmAccent.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: KlunaWarm.warmBrown.opacity(0.05), radius: 12, x: 0, y: 6)
            )
        }
    }

    private func reactionColor(_ reaction: String) -> Color {
        let lower = reaction.lowercased()
        if lower.contains("warm") { return KlunaWarm.warmAccent }
        if lower.contains("angespannt") || lower.contains("eng") || lower.contains("tense") { return Color(hex: "E85C5C") }
        if lower.contains("ruhig") || lower.contains("leise") || lower.contains("calm") { return Color(hex: "8B9DAF") }
        return Color(hex: "6BC5A0")
    }
}

struct MeChangeView: View {
    let entries: [JournalEntry]

    var body: some View {
        let sorted = entries.sorted(by: { $0.date < $1.date })
        let first5 = Array(sorted.prefix(5))
        let last5 = Array(sorted.suffix(5))
        let avgStabilityBefore = first5.map(\.stability).reduce(0, +) / Float(max(1, first5.count))
        let avgStabilityNow = last5.map(\.stability).reduce(0, +) / Float(max(1, last5.count))
        let avgWarmthBefore = first5.map(\.warmth).reduce(0, +) / Float(max(1, first5.count))
        let avgWarmthNow = last5.map(\.warmth).reduce(0, +) / Float(max(1, last5.count))
        let avgEnergyBefore = first5.map(\.energy).reduce(0, +) / Float(max(1, first5.count))
        let avgEnergyNow = last5.map(\.energy).reduce(0, +) / Float(max(1, last5.count))

        return VStack(alignment: .leading, spacing: 14) {
            Text("me.change.title".localized)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)
            Text("me.change.subtitle".localized)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
            VStack(spacing: 10) {
                MeChangeBar(label: "me.change.stability".localized, before: avgStabilityBefore, now: avgStabilityNow, goodDirection: .up)
                MeChangeBar(label: "dim.warmth".localized, before: avgWarmthBefore, now: avgWarmthNow, goodDirection: .up)
                MeChangeBar(label: "dim.energy".localized, before: avgEnergyBefore, now: avgEnergyNow, goodDirection: .up)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.05), radius: 12, x: 0, y: 6)
        )
    }
}

private enum GoodDirection { case up, down }

private struct MeChangeBar: View {
    let label: String
    let before: Float
    let now: Float
    let goodDirection: GoodDirection

    private var change: Float { now - before }
    private var isGood: Bool { goodDirection == .up ? change > 0 : change < 0 }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                .frame(width: 90, alignment: .leading)

            Capsule().fill(KlunaWarm.warmBrown.opacity(0.1)).frame(width: max(4, CGFloat(before) * 90), height: 6)
            Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "equal")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isGood ? Color(hex: "6BC5A0") : Color(hex: "E85C5C").opacity(0.6))
            Capsule().fill(isGood ? Color(hex: "6BC5A0").opacity(0.6) : Color(hex: "E85C5C").opacity(0.35)).frame(width: max(4, CGFloat(now) * 90), height: 6)
            Spacer(minLength: 0)
        }
    }
}

struct MeLockedFeaturesView: View {
    let entryCount: Int
    let activeMemoryLayers: Int

    var body: some View {
        VStack(spacing: 10) {
            if entryCount < 5 && activeMemoryLayers < 3 {
                LockedRow(title: "me.locked.patterns".localized, color: Color(hex: "E85C5C"), current: entryCount, needed: 5, icon: "heart.fill")
            }
            if entryCount < 5 && activeMemoryLayers < 4 {
                LockedRow(title: "me.locked.predictions".localized, color: Color(hex: "F5B731"), current: entryCount, needed: 5, icon: "eye.fill")
            }
            if entryCount < 10 && activeMemoryLayers < 5 {
                LockedRow(title: "me.locked.identity".localized, color: Color(hex: "B088A8"), current: entryCount, needed: 10, icon: "sparkles")
            }
            if entryCount < 7 {
                LockedRow(title: "me.locked.weekly".localized, color: Color(hex: "7BA7C4"), current: entryCount, needed: 7, icon: "calendar")
            }
        }
    }
}

private struct LockedRow: View {
    let title: String
    let color: Color
    let current: Int
    let needed: Int
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color.opacity(0.25))
                .frame(width: 22)
            Text(title)
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
            Spacer()
            Text(String(format: "me.locked.remaining".localized, max(0, needed - current)))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(color.opacity(0.35))
            Image(systemName: "lock.fill")
                .font(.system(size: 9))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.15))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.02), radius: 4, x: 0, y: 2)
        )
    }
}

@MainActor
extension KlunaDataManager {
    func entriesForLastMonth() -> [JournalEntry] {
        let calendar = Calendar.current
        let now = Date()
        guard
            let thisMonth = calendar.dateInterval(of: .month, for: now),
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: thisMonth.start)
        else {
            let fallbackStart = calendar.date(byAdding: .day, value: -30, to: now) ?? .distantPast
            return entries.filter { $0.date >= fallbackStart && $0.date <= now }.sorted(by: { $0.date < $1.date })
        }
        let previousMonthInterval = DateInterval(start: previousMonthStart, end: thisMonth.start)
        let monthEntries = entries
            .filter { previousMonthInterval.contains($0.date) }
            .sorted(by: { $0.date < $1.date })
        if monthEntries.isEmpty {
            let fallbackStart = calendar.date(byAdding: .day, value: -30, to: now) ?? .distantPast
            return entries.filter { $0.date >= fallbackStart && $0.date <= now }.sorted(by: { $0.date < $1.date })
        }
        return monthEntries
    }

    func entriesForDate(_ date: Date) -> [JournalEntry] {
        entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted(by: { $0.date > $1.date })
    }

    func lastNDaysEntries(_ days: Int) -> [MeDayEntry] {
        guard days > 0 else { return [] }
        let end = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        let grouped = Dictionary(grouping: entries.filter { $0.date >= start && $0.date <= Date() }) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return grouped.map { day, dayEntries in
            let count = Float(max(1, dayEntries.count))
            let avgEnergy = dayEntries.map(\.energy).reduce(0, +) / count
            let avgTension = dayEntries.map(\.stability).reduce(0, +) / count
            let avgWarmth = dayEntries.map(\.warmth).reduce(0, +) / count
            let avgExpressiveness = dayEntries.map { Float(VoiceDimensions.from($0).expressiveness) }.reduce(0, +) / count
            let dominantMood = dayEntries
                .sorted(by: { $0.date > $1.date })
                .compactMap { $0.moodLabel ?? $0.mood }
                .first ?? "ruhig"
            return MeDayEntry(
                date: day,
                dominantMood: dominantMood,
                avgEnergy: avgEnergy,
                avgTension: avgTension,
                avgWarmth: avgWarmth,
                avgExpressiveness: avgExpressiveness,
                entryCount: dayEntries.count
            )
        }
        .sorted(by: { $0.date < $1.date })
    }

    func dailySnapshots(last days: Int) -> [SoulTimelineView.DailySnapshot] {
        guard days > 0 else { return [] }
        var snapshots: [SoulTimelineView.DailySnapshot] = []
        let calendar = Calendar.current
        for dayOffset in 0..<days {
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date())
            let dayEntries = entries
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .sorted(by: { $0.date < $1.date })

            if let latest = dayEntries.last {
                let dims = VoiceDimensions.from(latest)
                let mood = latest.moodLabel ?? latest.mood ?? "ruhig"
                let previousDims = snapshots.last?.dims
                let subtitle = SoulSubtitleGenerator.generate(
                    dims: dims,
                    mood: mood,
                    previousDims: previousDims,
                    weekData: snapshots
                )
                snapshots.append(
                    .init(
                        date: day,
                        dims: dims,
                        mood: mood,
                        subtitle: subtitle,
                        entryCount: dayEntries.count
                    )
                )
            } else {
                snapshots.append(
                    .init(
                        date: day,
                        dims: VoiceDimensions(energy: 0, tension: 0, fatigue: 0, warmth: 0, expressiveness: 0, tempo: 0),
                        mood: "",
                        subtitle: "",
                        entryCount: 0
                    )
                )
            }
        }
        return snapshots
    }

    func recentDailyCards(last days: Int) -> [DailyCard] {
        guard days > 0 else { return [] }
        let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date())) ?? .distantPast
        return entries
            .filter { $0.date >= cutoff }
            .sorted(by: { $0.date > $1.date })
            .map { dailyCard(from: $0) }
    }

    func allDailyCards() -> [DailyCard] {
        var cards = entries
            .sorted(by: { $0.date > $1.date })
            .map { dailyCard(from: $0) }
        if let weekly = WeeklyCardGenerator.generate(weekCards: cards) {
            cards.insert(weekly, at: 0)
        }
        return cards
    }

    private func dailyCard(from entry: JournalEntry) -> DailyCard {
        let dims = VoiceDimensions.from(entry)
        let moodRaw = entry.moodLabel ?? entry.mood ?? "ruhig"
        let baseline = cardBaseline(excluding: entry.date)
        let zScores = pseudoZScores(for: dims, baseline: baseline)
        let generated = DailyCardGenerator.generate(
            entry: entry,
            dims: dims,
            baseline: baseline,
            zScores: zScores,
            mood: moodRaw,
            coachText: entry.coachText
        )
        let title = entry.cardTitle ?? generated.title
        let rarity = CardRarity(rawValue: entry.cardRarity ?? "") ?? generated.rarity
        let atmosphere = parseAtmosphereColors(entry.cardAtmosphereHex, fallbackMood: moodRaw, dims: dims)

        return DailyCard(
            date: entry.date,
            mood: localizedMood(moodRaw),
            title: title,
            sentence: generated.sentence,
            insight: generated.insight,
            dims: dims,
            baseline: baseline,
            primaryColor: generated.primaryColor,
            atmosphereColors: atmosphere,
            rarity: rarity,
            indicators: DailyCardGenerator.generateIndicators(dims: dims, baseline: baseline),
            rawFeatures: DailyCard.RawFeatures(
                jitter: Float(entry.rawFeatures[FeatureKeys.jitter] ?? 0.02),
                shimmer: Float(entry.rawFeatures[FeatureKeys.shimmer] ?? 0.15),
                hnr: Float(entry.rawFeatures[FeatureKeys.hnr] ?? 3.5),
                speechRate: Float(entry.rawFeatures[FeatureKeys.speechRate] ?? 4.0),
                f0Range: Float(entry.rawFeatures[FeatureKeys.f0RangeST] ?? entry.rawFeatures[FeatureKeys.f0Range] ?? 5.0),
                pauseDur: Float(entry.rawFeatures[FeatureKeys.meanPauseDuration] ?? entry.rawFeatures[FeatureKeys.pauseDuration] ?? 0.4)
            ),
            voiceObservation: entry.voiceObservation,
            lastSimilarDate: lastSimilarDate(for: entry),
            lastSimilarMood: lastSimilarMood(for: entry),
            warmestMoment: warmestMomentFromSegments(for: entry),
            entryNumber: entryNumber(for: entry),
            isWeekly: false
        )
    }

    private func entryNumber(for entry: JournalEntry) -> Int {
        entries.filter { $0.date <= entry.date }.count
    }

    private func lastSimilarDate(for entry: JournalEntry) -> String? {
        let targetMood = (entry.moodLabel ?? entry.mood ?? "").lowercased()
        guard !targetMood.isEmpty else { return nil }
        let similar = entries
            .filter { $0.id != entry.id }
            .filter { ($0.moodLabel ?? $0.mood ?? "").lowercased() == targetMood && $0.date < entry.date }
            .sorted(by: { $0.date > $1.date })
            .first
        guard let date = similar?.date else { return nil }
        return date.formatted(.dateTime.day().month(.wide))
    }

    private func lastSimilarMood(for entry: JournalEntry) -> String? {
        let targetMood = (entry.moodLabel ?? entry.mood ?? "").lowercased()
        guard !targetMood.isEmpty else { return nil }
        let similar = entries
            .filter { $0.id != entry.id }
            .filter { ($0.moodLabel ?? $0.mood ?? "").lowercased() == targetMood && $0.date < entry.date }
            .sorted(by: { $0.date > $1.date })
            .first
        return similar?.moodLabel ?? similar?.mood
    }

    private func warmestMomentFromSegments(for entry: JournalEntry) -> String? {
        let segments = VoiceSegmentStore.load(for: entry.id)
        if let best = segments.max(by: { $0.warmth < $1.warmth }),
           let snippet = best.transcriptSnippet?.trimmingCharacters(in: .whitespacesAndNewlines),
           !snippet.isEmpty {
            return String(snippet.prefix(64))
        }
        let trimmed = entry.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(64))
    }

    private func parseAtmosphereColors(_ raw: String?, fallbackMood: String, dims: VoiceDimensions) -> [Color] {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return DailyCardGenerator.atmosphereHexes(dims: dims, mood: fallbackMood).map { Color(hex: $0) }
        }
        let parsed = raw
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { Color(hex: $0) }
        if parsed.isEmpty {
            return DailyCardGenerator.atmosphereHexes(dims: dims, mood: fallbackMood).map { Color(hex: $0) }
        }
        return parsed
    }

    private func localizedMood(_ mood: String) -> String {
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        guard !isGerman else { return mood.capitalized }
        switch mood.lowercased() {
        case "begeistert": return "Excited"
        case "aufgekratzt": return "Energized"
        case "aufgewühlt", "aufgewuehlt": return "Stirred"
        case "angespannt": return "Tense"
        case "frustriert": return "Frustrated"
        case "erschöpft", "erschoepft": return "Exhausted"
        case "verletzlich": return "Vulnerable"
        case "ruhig": return "Calm"
        case "zufrieden": return "Content"
        case "nachdenklich": return "Reflective"
        default: return mood.capitalized
        }
    }

    private func averageVoiceDimensions(from dayEntries: [JournalEntry]) -> VoiceDimensions {
        let values = dayEntries.map(VoiceDimensions.from)
        let count = CGFloat(max(1, values.count))
        return VoiceDimensions(
            energy: values.map(\.energy).reduce(0, +) / count,
            tension: values.map(\.tension).reduce(0, +) / count,
            fatigue: values.map(\.fatigue).reduce(0, +) / count,
            warmth: values.map(\.warmth).reduce(0, +) / count,
            expressiveness: values.map(\.expressiveness).reduce(0, +) / count,
            tempo: values.map(\.tempo).reduce(0, +) / count
        )
    }

    private func cardBaseline(excluding date: Date) -> VoiceDimensions? {
        let calendar = Calendar.current
        let candidates = entries
            .filter { !calendar.isDate($0.date, inSameDayAs: date) }
            .sorted(by: { $0.date > $1.date })
        let window = Array(candidates.prefix(30))
        guard window.count >= 5 else { return nil }
        return averageVoiceDimensions(from: window)
    }

    private func pseudoZScores(for dims: VoiceDimensions, baseline: VoiceDimensions?) -> [String: Float] {
        guard let baseline else { return [:] }
        let scale: CGFloat = 0.18
        return [
            "energy": Float((dims.energy - baseline.energy) / scale),
            "tension": Float((dims.tension - baseline.tension) / scale),
            "fatigue": Float((dims.fatigue - baseline.fatigue) / scale),
            "warmth": Float((dims.warmth - baseline.warmth) / scale),
            "expressiveness": Float((dims.expressiveness - baseline.expressiveness) / scale),
            "tempo": Float((dims.tempo - baseline.tempo) / scale)
        ]
    }
}

enum DailyCardGenerator {
    static func generate(
        entry: JournalEntry,
        dims: VoiceDimensions,
        baseline: VoiceDimensions?,
        zScores: [String: Float],
        mood: String,
        coachText: String?
    ) -> DailyCard {
        let atmosphereHex = atmosphereHexes(dims: dims, mood: mood)
        return DailyCard(
            date: entry.date,
            mood: localizedMood(mood),
            title: CardTitleGenerator.generate(dims: dims, mood: mood),
            sentence: sentence(from: coachText, dims: dims, mood: mood),
            insight: entry.prompt,
            dims: dims,
            baseline: baseline,
            primaryColor: Color(hex: atmosphereHex.first ?? "E8825C"),
            atmosphereColors: atmosphereHex.map { Color(hex: $0) },
            rarity: calculateRarity(zScores: zScores),
            indicators: generateIndicators(dims: dims, baseline: baseline),
            rawFeatures: DailyCard.RawFeatures(
                jitter: Float(entry.rawFeatures[FeatureKeys.jitter] ?? 0.02),
                shimmer: Float(entry.rawFeatures[FeatureKeys.shimmer] ?? 0.15),
                hnr: Float(entry.rawFeatures[FeatureKeys.hnr] ?? 3.5),
                speechRate: Float(entry.rawFeatures[FeatureKeys.speechRate] ?? 4.0),
                f0Range: Float(entry.rawFeatures[FeatureKeys.f0RangeST] ?? entry.rawFeatures[FeatureKeys.f0Range] ?? 5.0),
                pauseDur: Float(entry.rawFeatures[FeatureKeys.meanPauseDuration] ?? entry.rawFeatures[FeatureKeys.pauseDuration] ?? 0.4)
            ),
            voiceObservation: nil,
            lastSimilarDate: nil,
            lastSimilarMood: nil,
            warmestMoment: nil,
            entryNumber: 0,
            isWeekly: false
        )
    }

    private static func localizedMood(_ mood: String) -> String {
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        guard !isGerman else { return mood.capitalized }
        switch mood.lowercased() {
        case "begeistert": return "Excited"
        case "aufgekratzt": return "Energized"
        case "aufgewühlt", "aufgewuehlt": return "Stirred"
        case "angespannt": return "Tense"
        case "frustriert": return "Frustrated"
        case "erschöpft", "erschoepft": return "Exhausted"
        case "verletzlich": return "Vulnerable"
        case "ruhig": return "Calm"
        case "zufrieden": return "Content"
        case "nachdenklich": return "Reflective"
        default: return mood.capitalized
        }
    }

    static func atmosphereHexes(dims: VoiceDimensions, mood: String) -> [String] {
        let primaryHex = primaryHexForMood(mood)
        var colors: [String] = [primaryHex]
        colors.append(dims.warmth > 0.5 ? "E8825C" : "8B9DAF")
        if dims.energy > 0.6 {
            colors.append("F5B731")
        } else if dims.fatigue > 0.6 {
            colors.append("2C2C3A")
        } else {
            colors.append(primaryHex)
        }
        colors.append("1A1A2E")
        return colors
    }

    private static func primaryHexForMood(_ mood: String) -> String {
        switch mood.lowercased() {
        case "begeistert", "aufgekratzt", "excited", "energized":
            return "F5B731"
        case "aufgewühlt", "aufgewuehlt", "angespannt", "frustriert", "stirred", "tense", "frustrated":
            return "E85C5C"
        case "erschöpft", "erschoepft", "verletzlich", "exhausted", "vulnerable":
            return "8B9DAF"
        case "zufrieden", "ruhig", "nachdenklich", "content", "calm", "reflective":
            return "6BC5A0"
        default:
            return "E8825C"
        }
    }

    private static func generateTitle(dims: VoiceDimensions, mood: String) -> String {
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        let e = dims.energy
        let t = dims.tension
        let f = dims.fatigue
        let w = dims.warmth
        let x = dims.expressiveness
        let s = dims.tempo

        let ranked: [(String, CGFloat)] = [
            ("energy", e), ("tension", t), ("fatigue", f),
            ("warmth", w), ("expressiveness", x), ("tempo", s)
        ].sorted { $0.1 > $1.1 }

        let top = ranked.first?.0 ?? "energy"
        let second = ranked.dropFirst().first?.0 ?? "warmth"
        let key = "\(top)_\(second)"

        let titles: [String: (de: String, en: String)] = [
            "energy_warmth": ("Goldenes Feuer", "Golden Fire"),
            "energy_expressiveness": ("Wilder Funke", "Wild Spark"),
            "energy_tempo": ("Volle Kraft", "Full Force"),
            "energy_tension": ("Elektrische Luft", "Electric Air"),
            "energy_fatigue": ("Letztes Aufbäumen", "Last Surge"),

            "tension_energy": ("Innerer Sturm", "Inner Storm"),
            "tension_tempo": ("Unter Strom", "Under Voltage"),
            "tension_fatigue": ("Schwere See", "Rough Sea"),
            "tension_warmth": ("Verborgene Stärke", "Hidden Strength"),
            "tension_expressiveness": ("Aufgewühlte Wellen", "Stirred Waves"),

            "warmth_energy": ("Strahlende Wärme", "Radiant Warmth"),
            "warmth_expressiveness": ("Offenes Herz", "Open Heart"),
            "warmth_fatigue": ("Sanfte Glut", "Gentle Ember"),
            "warmth_tension": ("Warmer Trotz", "Warm Defiance"),
            "warmth_tempo": ("Fließende Güte", "Flowing Kindness"),

            "fatigue_warmth": ("Müde Flamme", "Tired Flame"),
            "fatigue_tension": ("Stille Last", "Quiet Burden"),
            "fatigue_energy": ("Erschöpfter Held", "Exhausted Hero"),
            "fatigue_expressiveness": ("Traumwandler", "Sleepwalker"),
            "fatigue_tempo": ("Schwerer Atem", "Heavy Breath"),

            "expressiveness_warmth": ("Leuchtende Seele", "Luminous Soul"),
            "expressiveness_energy": ("Tanzende Stimme", "Dancing Voice"),
            "expressiveness_tension": ("Emotionales Gewitter", "Emotional Storm"),
            "expressiveness_fatigue": ("Melancholische Melodie", "Melancholic Melody"),
            "expressiveness_tempo": ("Lebendiger Strom", "Living Current"),

            "tempo_energy": ("Windschnell", "Windswept"),
            "tempo_expressiveness": ("Rasender Puls", "Racing Pulse"),
            "tempo_tension": ("Getriebenes Herz", "Driven Heart"),
            "tempo_warmth": ("Eilige Zärtlichkeit", "Hurried Tenderness"),
            "tempo_fatigue": ("Letzter Sprint", "Final Sprint")
        ]

        if let title = titles[key] {
            return isGerman ? title.de : title.en
        }

        let moodTitles: [String: (de: String, en: String)] = [
            "begeistert": ("Feuer und Licht", "Fire and Light"),
            "aufgekratzt": ("Knisternde Luft", "Crackling Air"),
            "aufgewühlt": ("Tosende Brandung", "Roaring Surf"),
            "aufgewuehlt": ("Tosende Brandung", "Roaring Surf"),
            "angespannt": ("Gespannte Saite", "Taut String"),
            "frustriert": ("Steiniger Pfad", "Rocky Path"),
            "erschöpft": ("Abendnebel", "Evening Mist"),
            "erschoepft": ("Abendnebel", "Evening Mist"),
            "verletzlich": ("Gläsernes Herz", "Glass Heart"),
            "ruhig": ("Stiller See", "Still Lake"),
            "zufrieden": ("Sonniger Hafen", "Sunny Harbor"),
            "nachdenklich": ("Tiefer Brunnen", "Deep Well"),
            "excited": ("Feuer und Licht", "Fire and Light"),
            "energized": ("Knisternde Luft", "Crackling Air"),
            "stirred_up": ("Tosende Brandung", "Roaring Surf"),
            "tense": ("Gespannte Saite", "Taut String"),
            "frustrated": ("Steiniger Pfad", "Rocky Path"),
            "exhausted": ("Abendnebel", "Evening Mist"),
            "vulnerable": ("Gläsernes Herz", "Glass Heart"),
            "calm": ("Stiller See", "Still Lake"),
            "content": ("Sonniger Hafen", "Sunny Harbor"),
            "reflective": ("Tiefer Brunnen", "Deep Well")
        ]

        if let title = moodTitles[mood.lowercased()] {
            return isGerman ? title.de : title.en
        }

        return isGerman ? "Dein Moment" : "Your Moment"
    }

    private static func calculateRarity(zScores: [String: Float]) -> CardRarity {
        let extremeCount = zScores.values.filter { abs($0) > 1.5 }.count
        let veryExtremeCount = zScores.values.filter { abs($0) > 2.5 }.count
        if veryExtremeCount >= 2 { return .legendary }
        if extremeCount >= 3 { return .rare }
        if extremeCount >= 1 { return .uncommon }
        return .common
    }

    static func generateIndicators(dims: VoiceDimensions, baseline: VoiceDimensions?) -> [DailyCard.Indicator] {
        guard let baseline else { return [] }
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        var all: [(String, CGFloat, Color)] = [
            (isGerman ? "Energie" : "Energy", dims.energy - baseline.energy, Color(hex: "F5B731")),
            (isGerman ? "Anspannung" : "Tension", dims.tension - baseline.tension, Color(hex: "E85C5C")),
            (isGerman ? "Müdigkeit" : "Fatigue", dims.fatigue - baseline.fatigue, Color(hex: "8B9DAF")),
            (isGerman ? "Wärme" : "Warmth", dims.warmth - baseline.warmth, Color(hex: "E8825C")),
            (isGerman ? "Lebendigkeit" : "Liveliness", dims.expressiveness - baseline.expressiveness, Color(hex: "6BC5A0")),
            ("Tempo", dims.tempo - baseline.tempo, Color(hex: "7BA7C4"))
        ]
        all.sort { abs($0.1) > abs($1.1) }
        return all.prefix(3).map { label, diff, color in
            let arrow: String
            if diff > 0.15 { arrow = "↑↑" }
            else if diff > 0.06 { arrow = "↑" }
            else if diff < -0.15 { arrow = "↓↓" }
            else if diff < -0.06 { arrow = "↓" }
            else { arrow = "→" }
            return DailyCard.Indicator(label: label, arrow: arrow, color: color)
        }
    }

    private static func sentence(from coachText: String?, dims: VoiceDimensions, mood: String) -> String {
        if let coachText, !coachText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return coachText
        }
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        if dims.warmth > 0.65 && dims.tension < 0.45 {
            return isGerman ? "Heute klingt deine Stimme weich und offen." : "Your voice sounds soft and open today."
        }
        if dims.tension > 0.65 {
            return isGerman ? "Da ist Spannung da, aber auch Klarheit." : "There is tension, but also clarity."
        }
        if dims.fatigue > 0.65 {
            return isGerman ? "Du klingst müde. Gönn dir Ruhe." : "You sound tired. Give yourself rest."
        }
        return isGerman ? "Dein Klang heute." : "Your sound today."
    }
}

struct CardTitleGenerator {
    enum EnergyLevel { case low, mid, high }
    enum Valence { case dark, neutral, bright }
    enum Intensity { case gentle, moderate, strong }

    struct Title {
        let de: String
        let en: String
    }

    static func generate(dims: VoiceDimensions, mood: String) -> String {
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        let energy: EnergyLevel = dims.energy > 0.65 ? .high : (dims.energy < 0.35 ? .low : .mid)
        let positivity = (dims.warmth + dims.expressiveness) / 2.0
        let negativity = (dims.tension + dims.fatigue) / 2.0
        let valence: Valence
        if positivity > negativity + 0.1 { valence = .bright }
        else if negativity > positivity + 0.1 { valence = .dark }
        else { valence = .neutral }
        let maxDim = max(dims.energy, dims.tension, dims.warmth, dims.expressiveness)
        let intensity: Intensity = maxDim > 0.7 ? .strong : (maxDim < 0.4 ? .gentle : .moderate)
        let selector = Int((dims.energy * 1000 + dims.tension * 100 + dims.warmth * 10).truncatingRemainder(dividingBy: 10))
        let titles = getTitles(energy: energy, valence: valence, intensity: intensity)
        let index = titles.isEmpty ? 0 : abs(selector) % titles.count
        if titles.isEmpty { return (Locale.current.language.languageCode?.identifier == "de") ? "Dein Moment" : "Your Moment" }
        return isGerman ? titles[index].de : titles[index].en
    }

    static func getTitles(energy: EnergyLevel, valence: Valence, intensity: Intensity) -> [Title] {
        switch (energy, valence, intensity) {
        case (.low, .dark, .gentle):
            return [Title(de: "Samtener Nebel", en: "Velvet Fog"), Title(de: "Leise Schwere", en: "Quiet Weight"), Title(de: "Winterschlaf", en: "Winter Sleep"), Title(de: "Gedämpftes Echo", en: "Muffled Echo"), Title(de: "Abenddämmerung", en: "Dusk")]
        case (.low, .dark, .moderate):
            return [Title(de: "Stille Last", en: "Silent Burden"), Title(de: "Tiefer Brunnen", en: "Deep Well"), Title(de: "Schwere Luft", en: "Heavy Air"), Title(de: "Dunkler Hafen", en: "Dark Harbor"), Title(de: "Graue Stunde", en: "Grey Hour")]
        case (.low, .dark, .strong):
            return [Title(de: "Gefrorene Träne", en: "Frozen Tear"), Title(de: "Eiserner Schatten", en: "Iron Shadow"), Title(de: "Stummer Schrei", en: "Silent Scream"), Title(de: "Schwarzes Wasser", en: "Black Water"), Title(de: "Tonnenschwer", en: "Crushing Weight")]
        case (.low, .neutral, .gentle):
            return [Title(de: "Weicher Nebel", en: "Soft Fog"), Title(de: "Ruhiges Wasser", en: "Still Water"), Title(de: "Mondschein", en: "Moonlight"), Title(de: "Stille Weite", en: "Quiet Expanse"), Title(de: "Weiches Grau", en: "Soft Grey")]
        case (.low, .neutral, .moderate):
            return [Title(de: "Nachdenkliche Stille", en: "Thoughtful Silence"), Title(de: "Ruhender Fluss", en: "Resting River"), Title(de: "Stiller Beobachter", en: "Quiet Observer"), Title(de: "Sanfter Mittag", en: "Gentle Noon"), Title(de: "Innere Einkehr", en: "Inner Return")]
        case (.low, .neutral, .strong):
            return [Title(de: "Tiefe Stille", en: "Deep Stillness"), Title(de: "Verwurzelter Baum", en: "Rooted Tree"), Title(de: "Fels im Meer", en: "Rock in the Sea"), Title(de: "Konzentrierte Ruhe", en: "Focused Calm"), Title(de: "Anker", en: "Anchor")]
        case (.low, .bright, .gentle):
            return [Title(de: "Warmer Morgen", en: "Warm Morning"), Title(de: "Sanftes Lächeln", en: "Gentle Smile"), Title(de: "Leise Freude", en: "Quiet Joy"), Title(de: "Honigstille", en: "Honey Silence"), Title(de: "Weiches Gold", en: "Soft Gold")]
        case (.low, .bright, .moderate):
            return [Title(de: "Zufriedene Ruhe", en: "Contented Calm"), Title(de: "Sonniger Hafen", en: "Sunny Harbor"), Title(de: "Warme Decke", en: "Warm Blanket"), Title(de: "Stille Dankbarkeit", en: "Quiet Gratitude"), Title(de: "Abendgold", en: "Evening Gold")]
        case (.low, .bright, .strong):
            return [Title(de: "Tiefe Wärme", en: "Deep Warmth"), Title(de: "Leuchtende Stille", en: "Luminous Silence"), Title(de: "Goldener Anker", en: "Golden Anchor"), Title(de: "Innere Sonne", en: "Inner Sun"), Title(de: "Starke Güte", en: "Strong Kindness")]
        case (.mid, .dark, .gentle):
            return [Title(de: "Herbstwind", en: "Autumn Wind"), Title(de: "Sanfte Unruhe", en: "Gentle Unrest"), Title(de: "Graue Welle", en: "Grey Wave"), Title(de: "Verhangener Himmel", en: "Overcast Sky"), Title(de: "Wandernder Schatten", en: "Wandering Shadow")]
        case (.mid, .dark, .moderate):
            return [Title(de: "Innerer Sturm", en: "Inner Storm"), Title(de: "Steiniger Pfad", en: "Rocky Path"), Title(de: "Gespannte Saite", en: "Taut String"), Title(de: "Unruhiges Meer", en: "Restless Sea"), Title(de: "Schwelender Funke", en: "Smoldering Spark")]
        case (.mid, .dark, .strong):
            return [Title(de: "Aufziehende Front", en: "Approaching Front"), Title(de: "Brodelnde Tiefe", en: "Churning Depth"), Title(de: "Zerissene Wolken", en: "Torn Clouds"), Title(de: "Dunkle Flamme", en: "Dark Flame"), Title(de: "Donnergrollen", en: "Distant Thunder")]
        case (.mid, .neutral, .gentle):
            return [Title(de: "Fließender Tag", en: "Flowing Day"), Title(de: "Leichter Wind", en: "Light Breeze"), Title(de: "Sanfte Strömung", en: "Gentle Current"), Title(de: "Alltägliche Magie", en: "Everyday Magic"), Title(de: "Ruhiger Puls", en: "Steady Pulse")]
        case (.mid, .neutral, .moderate):
            return [Title(de: "Im Fluss", en: "In Flow"), Title(de: "Wellental", en: "Between Waves"), Title(de: "Klarer Blick", en: "Clear View"), Title(de: "Stabile Mitte", en: "Stable Center"), Title(de: "Normaler Wahnsinn", en: "Normal Chaos")]
        case (.mid, .neutral, .strong):
            return [Title(de: "Entschlossener Schritt", en: "Determined Step"), Title(de: "Klare Linie", en: "Clear Line"), Title(de: "Ruhige Kraft", en: "Quiet Power"), Title(de: "Geerdeter Sturm", en: "Grounded Storm"), Title(de: "Fokussiert", en: "Focused")]
        case (.mid, .bright, .gentle):
            return [Title(de: "Frühlingsbrise", en: "Spring Breeze"), Title(de: "Warmer Strom", en: "Warm Stream"), Title(de: "Leichtes Herz", en: "Light Heart"), Title(de: "Sanftes Glühen", en: "Gentle Glow"), Title(de: "Nachmittagslicht", en: "Afternoon Light")]
        case (.mid, .bright, .moderate):
            return [Title(de: "Offenes Herz", en: "Open Heart"), Title(de: "Warmer Wind", en: "Warm Wind"), Title(de: "Lebendiger Fluss", en: "Living Stream"), Title(de: "Goldene Stunde", en: "Golden Hour"), Title(de: "Blühende Wiese", en: "Blooming Meadow")]
        case (.mid, .bright, .strong):
            return [Title(de: "Strahlende Wärme", en: "Radiant Warmth"), Title(de: "Kraftvolle Güte", en: "Powerful Kindness"), Title(de: "Leuchtender Fluss", en: "Luminous River"), Title(de: "Sonnendurchbruch", en: "Sunbreak"), Title(de: "Warmer Fels", en: "Warm Rock")]
        case (.high, .dark, .gentle):
            return [Title(de: "Nervöses Flackern", en: "Nervous Flicker"), Title(de: "Ruhelose Nacht", en: "Restless Night"), Title(de: "Flatternder Puls", en: "Fluttering Pulse"), Title(de: "Elektrische Luft", en: "Electric Air"), Title(de: "Unruhige Flamme", en: "Restless Flame")]
        case (.high, .dark, .moderate):
            return [Title(de: "Unter Strom", en: "Under Voltage"), Title(de: "Aufgewühlte See", en: "Churning Sea"), Title(de: "Getriebenes Herz", en: "Driven Heart"), Title(de: "Rasender Puls", en: "Racing Pulse"), Title(de: "Stürmische Nacht", en: "Stormy Night")]
        case (.high, .dark, .strong):
            return [Title(de: "Tobender Sturm", en: "Raging Storm"), Title(de: "Vulkanausbruch", en: "Eruption"), Title(de: "Blitz und Donner", en: "Lightning Strike"), Title(de: "Brennende Brücke", en: "Burning Bridge"), Title(de: "Wilder Ozean", en: "Wild Ocean")]
        case (.high, .neutral, .gentle):
            return [Title(de: "Tanzende Blätter", en: "Dancing Leaves"), Title(de: "Lebendig und klar", en: "Alive and Clear"), Title(de: "Quicklebendiger Bach", en: "Babbling Brook"), Title(de: "Frischer Wind", en: "Fresh Wind"), Title(de: "Spielender Funke", en: "Playful Spark")]
        case (.high, .neutral, .moderate):
            return [Title(de: "Volle Fahrt", en: "Full Speed"), Title(de: "Lebendiger Strom", en: "Living Current"), Title(de: "Windschnell", en: "Windswept"), Title(de: "Wirbelnde Energie", en: "Swirling Energy"), Title(de: "Im Rausch", en: "In the Rush")]
        case (.high, .neutral, .strong):
            return [Title(de: "Ungezähmte Kraft", en: "Untamed Force"), Title(de: "Wilder Fluss", en: "Wild River"), Title(de: "Donnernde Welle", en: "Thundering Wave"), Title(de: "Entfesselt", en: "Unleashed"), Title(de: "Volle Kraft", en: "Full Force")]
        case (.high, .bright, .gentle):
            return [Title(de: "Tanzende Sonne", en: "Dancing Sun"), Title(de: "Sprudelnde Freude", en: "Bubbling Joy"), Title(de: "Leichter Rausch", en: "Light Rush"), Title(de: "Funkelnder Morgen", en: "Sparkling Morning"), Title(de: "Schmetterling", en: "Butterfly")]
        case (.high, .bright, .moderate):
            return [Title(de: "Goldenes Feuer", en: "Golden Fire"), Title(de: "Wilder Funke", en: "Wild Spark"), Title(de: "Leuchtender Sturm", en: "Luminous Storm"), Title(de: "Feuer und Licht", en: "Fire and Light"), Title(de: "Strahlender Tag", en: "Radiant Day")]
        case (.high, .bright, .strong):
            return [Title(de: "Supernova", en: "Supernova"), Title(de: "Explodierendes Licht", en: "Exploding Light"), Title(de: "Leuchtende Eruption", en: "Luminous Eruption"), Title(de: "Sonnenfeuer", en: "Sunfire"), Title(de: "Grenzenlose Freude", en: "Boundless Joy")]
        }
    }
}

struct WeeklyCardGenerator {
    static func generate(weekCards: [DailyCard]) -> DailyCard? {
        guard weekCards.count >= 7 else { return nil }
        let latestSeven = Array(weekCards.prefix(7)).sorted(by: { $0.date < $1.date })
        let calendar = Calendar.current
        guard latestSeven.count == 7 else { return nil }
        for i in 1..<latestSeven.count {
            let diff = calendar.dateComponents([.day], from: latestSeven[i - 1].date, to: latestSeven[i].date).day ?? 0
            if diff != 1 { return nil }
        }
        let avgDims = VoiceDimensions(
            energy: latestSeven.map(\.dims.energy).reduce(0, +) / CGFloat(latestSeven.count),
            tension: latestSeven.map(\.dims.tension).reduce(0, +) / CGFloat(latestSeven.count),
            fatigue: latestSeven.map(\.dims.fatigue).reduce(0, +) / CGFloat(latestSeven.count),
            warmth: latestSeven.map(\.dims.warmth).reduce(0, +) / CGFloat(latestSeven.count),
            expressiveness: latestSeven.map(\.dims.expressiveness).reduce(0, +) / CGFloat(latestSeven.count),
            tempo: latestSeven.map(\.dims.tempo).reduce(0, +) / CGFloat(latestSeven.count)
        )
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
        let firstDay = latestSeven.first!
        let lastDay = latestSeven.last!
        let tensionChange = lastDay.dims.tension - firstDay.dims.tension
        let warmthChange = lastDay.dims.warmth - firstDay.dims.warmth
        let title: String
        if tensionChange < -0.1 && warmthChange > 0.05 { title = isGerman ? "Woche der Befreiung" : "Week of Liberation" }
        else if warmthChange > 0.1 { title = isGerman ? "Woche der Wärme" : "Week of Warmth" }
        else if tensionChange > 0.1 { title = isGerman ? "Woche der Prüfung" : "Week of Trial" }
        else if avgDims.expressiveness > 0.6 { title = isGerman ? "Lebendige Woche" : "Vibrant Week" }
        else { title = isGerman ? "Sieben Tage" : "Seven Days" }
        let rareCount = latestSeven.filter { $0.rarity == .rare || $0.rarity == .legendary }.count
        let rarity: CardRarity = rareCount >= 2 ? .legendary : (rareCount >= 1 ? .rare : .uncommon)
        let mostCommon = latestSeven.map(\.mood).mostFrequent() ?? (isGerman ? "Ruhig" : "Calm")
        let featureCards = latestSeven.compactMap(\.rawFeatures)
        let weeklyRawFeatures: DailyCard.RawFeatures? = {
            guard !featureCards.isEmpty else { return nil }
            let count = Float(featureCards.count)
            return DailyCard.RawFeatures(
                jitter: featureCards.map(\.jitter).reduce(0, +) / count,
                shimmer: featureCards.map(\.shimmer).reduce(0, +) / count,
                hnr: featureCards.map(\.hnr).reduce(0, +) / count,
                speechRate: featureCards.map(\.speechRate).reduce(0, +) / count,
                f0Range: featureCards.map(\.f0Range).reduce(0, +) / count,
                pauseDur: featureCards.map(\.pauseDur).reduce(0, +) / count
            )
        }()
        let sentence = isGerman
            ? "7 Tage. 7 Karten. Am häufigsten: \(mostCommon). Von \(firstDay.title) bis \(lastDay.title)."
            : "7 days. 7 cards. Most common: \(mostCommon). From \(firstDay.title) to \(lastDay.title)."
        let primaryColor = KlunaWarm.moodColor(for: mostCommon, fallbackQuadrant: .zufrieden)
        return DailyCard(
            date: lastDay.date,
            mood: mostCommon,
            title: "⭐ " + title,
            sentence: sentence,
            insight: nil,
            dims: avgDims,
            baseline: lastDay.baseline,
            primaryColor: primaryColor,
            atmosphereColors: [
                primaryColor.opacity(0.9),
                Color(hex: "F5B731").opacity(0.6),
                primaryColor.opacity(0.5),
                Color(hex: "1A1A2E").opacity(0.4),
            ],
            rarity: rarity,
            indicators: [],
            rawFeatures: weeklyRawFeatures,
            voiceObservation: nil,
            lastSimilarDate: nil,
            lastSimilarMood: nil,
            warmestMoment: nil,
            entryNumber: 0,
            isWeekly: true
        )
    }
}

extension Array where Element: Hashable {
    func mostFrequent() -> Element? {
        let counts = reduce(into: [Element: Int]()) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

enum SoulSubtitleGenerator {
    static func generate(
        dims: VoiceDimensions,
        mood: String,
        previousDims: VoiceDimensions?,
        weekData: [SoulTimelineView.DailySnapshot]
    ) -> String {
        let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"

        if let prev = previousDims {
            let tensionDrop = prev.tension - dims.tension
            let warmthGain = dims.warmth - prev.warmth
            let energyChange = dims.energy - prev.energy

            if tensionDrop > 0.15 {
                return isGerman ? "Entspannter als gestern. Etwas hat sich gelöst." : "More relaxed than yesterday. Something has shifted."
            }
            if warmthGain > 0.15 {
                return isGerman ? "Wärmer als gestern. Da ist etwas, das dir gut tut." : "Warmer than yesterday. Something is doing you good."
            }
            if energyChange > 0.15 {
                return isGerman ? "Mehr Energie als gestern. Etwas treibt dich an." : "More energy than yesterday. Something is driving you."
            }
            if energyChange < -0.15 {
                return isGerman ? "Ruhiger als gestern. Dein Körper braucht das vielleicht." : "Quieter than yesterday. Your body might need this."
            }
        }

        if weekData.count >= 3 {
            let avgWarmth = weekData.map(\.dims.warmth).reduce(0, +) / CGFloat(weekData.count)
            if dims.warmth > avgWarmth + 0.1 {
                return isGerman ? "Dein wärmster Moment diese Woche." : "Your warmest moment this week."
            }
            let avgTension = weekData.map(\.dims.tension).reduce(0, +) / CGFloat(weekData.count)
            if dims.tension < avgTension - 0.1 {
                return isGerman ? "Entspannter als dein Wochendurchschnitt." : "More relaxed than your weekly average."
            }
        }

        switch mood.lowercased() {
        case "begeistert", "excited":
            return isGerman ? "Da brennt etwas. Deine Stimme strahlt." : "Something is burning. Your voice is glowing."
        case "ruhig", "calm":
            return isGerman ? "Still und klar. Wie ein See am Morgen." : "Still and clear. Like a morning lake."
        case "verletzlich", "vulnerable":
            return isGerman ? "Leise heute. Das ist mutig." : "Quiet today. That takes courage."
        case "angespannt", "tense":
            return isGerman ? "Etwas arbeitet in dir. Dein Körper spürt es." : "Something is working inside you. Your body feels it."
        case "nachdenklich", "reflective":
            return isGerman ? "Deine Stimme denkt nach." : "Your voice is thinking."
        case "zufrieden", "content":
            return isGerman ? "Im Gleichgewicht. Das hört man." : "In balance. You can hear it."
        case "erschöpft", "exhausted", "erschoepft":
            return isGerman ? "Müde. Gönn dir Ruhe." : "Tired. Give yourself rest."
        default:
            return isGerman ? "Dein Klang heute." : "Your sound today."
        }
    }
}
