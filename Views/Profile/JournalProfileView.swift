import SwiftUI
import CoreData
import UIKit

struct JournalProfileView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var dataManager = KlunaDataManager.shared
    @State private var entries: [JournalEntry] = []
    @State private var userName: String = UserDefaults.standard.string(forKey: "kluna_profile_name") ?? ""
    @State private var isDonating: Bool = UserDefaults.standard.bool(forKey: "kluna_data_donation_enabled")
    @State private var tempName: String = ""
    @State private var showEditNameSheet = false
    @State private var showDeleteAllAlert = false
    @State private var showCardCollection = false
    @State private var selectedMilestone: ProfileMilestone?
    @ObservedObject private var badgeManager = BadgeManager.shared
    @ObservedObject private var personalCalibration = PersonalCalibration.shared

    private var stats: KlunaStats {
        KlunaStats.from(entries: entries, isDonating: isDonating)
    }

    private var memberSince: Date {
        entries.map(\.date).min() ?? Date()
    }

    private var firstEntry: JournalEntry? {
        entries.sorted(by: { $0.date < $1.date }).first
    }

    private var latestEntry: JournalEntry? {
        entries.sorted(by: { $0.date > $1.date }).first
    }

    private var voiceType: ProfileVoiceTypeModel? {
        ProfileVoiceTypeModel.from(entries: entries)
    }

    private var klunaScore: Int {
        let uniqueDays = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
        let grouped = Dictionary(grouping: entries.filter { $0.conversationId != nil }, by: { $0.conversationId! })
        let avgRounds: Float
        if grouped.isEmpty {
            avgRounds = 1
        } else {
            let total = grouped.values.reduce(0) { $0 + $1.count }
            avgRounds = Float(total) / Float(grouped.count)
        }
        let memoryDepth = KlunaMemory.shared.layersForUI.filter { !$0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let feedbackCount = CoachFeedbackStore.totalCount()
        return KlunaScore.calculate(
            entryCount: entries.count,
            uniqueDays: uniqueDays,
            avgRoundsPerConversation: avgRounds,
            memoryDepth: memoryDepth,
            feedbackCount: feedbackCount
        )
    }

    private var latestDims: VoiceDimensions {
        latestEntry.map(VoiceDimensions.from) ?? VoiceDimensions(energy: 0.5, tension: 0.5, fatigue: 0.5, warmth: 0.5, expressiveness: 0.5, tempo: 0.5)
    }

    private var latestMood: String {
        latestEntry?.moodLabel ?? latestEntry?.mood ?? "ruhig"
    }

    private var activeDays: Int {
        Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
    }

    private var minutesSpoken: Int {
        Int(stats.totalMinutesSpoken)
    }

    private var currentVoiceType: GeneratedVoiceType? {
        VoiceTypeGenerator.loadLatest()
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 16)

                    ProfileHeroSectionV3(
                        dims: latestDims,
                        mood: latestMood,
                        userName: userName,
                        voiceType: currentVoiceType,
                        memberSince: entries.isEmpty ? nil : memberSince
                    )

                    Spacer().frame(height: 28)

                    StatsRowSectionV3(
                        streak: stats.currentStreak,
                        klunaScore: klunaScore,
                        activeDays: activeDays
                    )

                    Spacer().frame(height: 28)

                    ProfileCardCollectionPreview(
                        cards: dataManager.allDailyCards(),
                        onShowAll: { showCardCollection = true }
                    )

                    Spacer().frame(height: 28)

                    if entries.count >= 10 {
                        ProfileEvolutionView(entries: entries)
                        Spacer().frame(height: 28)
                    }

                    JourneySectionV3(
                        entries: stats.totalEntries,
                        minutesSpoken: minutesSpoken,
                        longestStreak: stats.longestStreak,
                        topMood: stats.mostFrequentMood
                    )

                    Spacer().frame(height: 28)

                    BadgesSectionV3(badges: badgeManager.allBadges, stats: stats)

                    Spacer().frame(height: 28)

                    HowKlunaWorksSectionV3()

                    Spacer().frame(height: 28)

                    DonationSectionV3(isDonating: $isDonating)

                    Spacer().frame(height: 28)

                    SettingsSectionV3(
                        onEditName: {
                            tempName = userName
                            showEditNameSheet = true
                        },
                        onReminders: {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        },
                        onDelete: {
                            showDeleteAllAlert = true
                        }
                    )

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, 20)
            }
            .background(KlunaWarm.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $showEditNameSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("profile.name_prompt".localized)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("profile.your_name_placeholder".localized, text: $tempName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(KlunaWarm.cardBackground)
                        )

                    Spacer()
                }
                .padding(20)
                .background(KlunaWarm.background.ignoresSafeArea())
                .navigationTitle("profile.change_name".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("general.abort".localized) { showEditNameSheet = false }
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("general.save".localized) {
                            userName = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                            UserDefaults.standard.set(userName, forKey: "kluna_profile_name")
                            showEditNameSheet = false
                        }
                        .foregroundStyle(KlunaWarm.warmAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showCardCollection) {
            ProfileCardCollectionFullView(cards: dataManager.allDailyCards())
        }
        .alert("general.delete_all_data".localized, isPresented: $showDeleteAllAlert) {
            Button("general.abort".localized, role: .cancel) {}
            Button("general.delete_confirm".localized, role: .destructive) {
                deleteAllJournalData()
            }
        } message: {
            Text("profile.delete_warning".localized)
        }
    }

    private func reload() {
        entries = JournalManager(context: context).recentEntries(limit: 800)
        badgeManager.checkBadges(stats: stats)
    }

    private func globalStatsMock() -> GlobalVoiceStats {
        GlobalVoiceStats(
            totalDonors: 12432,
            totalDataPoints: 811235,
            avgWarmth: 0.54,
            avgStability: 0.58,
            avgEnergy: 0.49,
            avgTempo: 0.52,
            avgOpenness: 0.46,
            mostCommonMood: "ruhig"
        )
    }

    private func deleteAllJournalData() {
        KlunaAnalytics.shared.track("data_deleted")
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "CDJournalEntry")
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            _ = try? context.execute(delete)
            try? context.save()
        }

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            reload()
            return
        }

        let folders = ["journal_audio", "journal_audio_segments", "Recordings"]
        for folder in folders {
            let url = docs.appendingPathComponent(folder, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let keysToRemove = [
            "todayInsight",
            "todayInsightDate",
            "kluna_today_insight",
            "kluna_insight_timestamp",
            "personalizedPrompt",
            "personalizedPromptDate",
            "kluna_personalized_prompt",
            "kluna_prompt_timestamp",
            "kluna_personalized_prompt_timestamp",
            "kluna_ewma_baselines",
            "kluna_calibration",
        ]
        keysToRemove.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        BaselineManager.shared.resetBaselines()
        PersonalCalibration.shared.reset()
        MentionTracker.shared.reset()
        KlunaMemory.shared.reset()
        PromptHistory.shared.reset()
        BadgeManager.shared.reset()
        KlunaAnalytics.shared.reset()
        reload()
    }
}

struct ProfileHeaderSection: View {
    let userName: String?
    let memberSince: Date
    let currentStreak: Int
    let longestStreak: Int
    let totalEntries: Int
    let latestEntry: JournalEntry?
    let dominantMoodColor: Color

    var body: some View {
        VStack(spacing: 16) {
            if let latestEntry {
                VoiceSignatureV2(entry: latestEntry, size: 110)
            } else {
                Circle()
                    .fill(dominantMoodColor.opacity(0.15))
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(dominantMoodColor.opacity(0.7))
                    )
                    .frame(width: 100, height: 100)
            }

            Text(userName ?? "Kluna-Nutzer")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(KlunaWarm.warmBrown)

            HStack(spacing: 4) {
                Text("profile.member_since".localized)
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                Text(memberSince.formatted(.dateTime.month(.wide).year()))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
            }
            .font(.system(.caption, design: .rounded))

            HStack(spacing: 24) {
                streakColumn(icon: "flame.fill", iconColor: KlunaWarm.warmAccent, value: "\(currentStreak)", label: "profile.current_streak".localized)
                divider
                streakColumn(icon: "trophy.fill", iconColor: Color(hex: "F5B731"), value: "\(longestStreak)", label: "profile.longest_streak".localized)
                divider
                VStack(spacing: 2) {
                    Text("\(totalEntries)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Text("profile.entries".localized)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(KlunaWarm.warmBrown.opacity(0.08))
            .frame(width: 1, height: 32)
    }

    private func streakColumn(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 16))
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(KlunaWarm.warmBrown)
            }
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
        }
    }
}

struct CalibrationStatusView: View {
    let entryCount: Int
    @State private var checkPop = false

    private var progress: CGFloat {
        min(CGFloat(max(entryCount, 0)) / 10.0, 1.0)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(KlunaWarm.warmBrown.opacity(0.08), lineWidth: 3)
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: progress * 0.75)
                    .stroke(
                        entryCount >= 10 ? Color(hex: "#6BC5A0") : KlunaWarm.warmAccent,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(135))
                    .animation(.easeInOut(duration: 0.55), value: progress)

                Text(entryCount >= 10 ? "✓" : "\(entryCount)")
                    .font(.system(size: entryCount >= 10 ? 14 : 12, weight: .bold, design: .rounded))
                    .foregroundStyle(entryCount >= 10 ? Color(hex: "#6BC5A0") : KlunaWarm.warmAccent)
                    .scaleEffect(entryCount >= 10 ? (checkPop ? 1.18 : 1.0) : 1.0)
                    .animation(.easeInOut(duration: 0.35), value: entryCount)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entryCount >= 10 ? "profile.calibration_known".localized : "profile.calibration_learning".localized)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(KlunaWarm.warmBrown)

                Text(
                    entryCount >= 10
                        ? "profile.baseline_calibrated".localized
                        : String(format: "profile.entries_until_calibration".localized, max(0, 10 - entryCount))
                )
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(KlunaWarm.cardBackground)
        )
        .animation(.easeInOut(duration: 0.35), value: entryCount >= 10)
        .onChange(of: entryCount) { newValue in
            guard newValue == 10 else { return }
            checkPop = false
            withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) {
                checkPop = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                    checkPop = false
                }
            }
        }
    }
}

struct VoiceTypeSection: View {
    let voiceType: ProfileVoiceTypeModel?
    let latestEntry: JournalEntry?
    let userName: String

    var body: some View {
        VStack(spacing: 16) {
            Text("profile.voice_type_title".localized)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)

            if let type = voiceType {
                VStack(spacing: 12) {
                    Text(type.name)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(type.color)

                    Text(type.description)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    HStack(spacing: 12) {
                        ForEach(type.dimensions, id: \.label) { dim in
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .trim(from: 0, to: 0.75)
                                        .stroke(KlunaWarm.warmBrown.opacity(0.06), lineWidth: 3)
                                        .rotationEffect(.degrees(135))
                                    Circle()
                                        .trim(from: 0, to: 0.75 * dim.value.clamped(to: 0...1))
                                        .stroke(type.color, lineWidth: 3)
                                        .rotationEffect(.degrees(135))
                                }
                                .frame(width: 36, height: 36)
                                Text(dim.shortLabel)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                            }
                        }
                    }
                    .padding(.top, 4)

                    if let latestEntry {
                        let dims = VoiceDimensions.from(latestEntry)
                        let payload = VoiceTypeShareData(
                            typeName: type.name,
                            typeDescription: type.description,
                            dimensions: dims,
                            userName: userName.isEmpty ? "du" : userName,
                            signatureShape: .fromDimensions(dims),
                            dominantColor: type.color
                        )
                        KlunaShareButton(action: {
                            ShareABManager.shared.trackTap(.voiceType)
                            ShareImageGenerator.share(content: .voiceType(payload))
                        })
                        .padding(.top, 6)
                        .onAppear {
                            ShareABManager.shared.trackShown(.voiceType)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Text("profile.not_enough_data".localized)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                    Text("profile.voice_type_after_entries".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
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

struct VoiceEvolutionSection: View {
    let firstEntry: JournalEntry
    let latestEntry: JournalEntry
    let firstDimensions: ProfileVoiceDimensions
    let latestDimensions: ProfileVoiceDimensions
    @State private var showFirst = true

    var body: some View {
        VStack(spacing: 16) {
            Text("profile.your_evolution".localized)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)

            ZStack {
                if showFirst {
                    VStack(spacing: 8) {
                        VoiceSignatureV2(entry: firstEntry, size: 140)
                        Text("profile.first_entry".localized)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(KlunaWarm.warmBrown)
                        Text(firstEntry.date.formatted(.dateTime.day().month(.wide).year()))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                    }
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                } else {
                    VStack(spacing: 8) {
                        VoiceSignatureV2(entry: latestEntry, size: 140)
                        Text("profile.latest_entry".localized)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(KlunaWarm.warmBrown)
                        Text(latestEntry.date.formatted(.dateTime.day().month(.wide).year()))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.45))
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .trailing).combined(with: .opacity)))
                }
            }
            .animation(.spring(response: 0.5), value: showFirst)
            .onTapGesture { showFirst.toggle() }

            Text("profile.tap_to_switch".localized)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))

            VStack(spacing: 6) {
                EvolutionRow(label: "dim.energy".localized, first: firstDimensions.energy, latest: latestDimensions.energy)
                EvolutionRow(label: "dim.tension".localized, first: firstDimensions.tension, latest: latestDimensions.tension)
                EvolutionRow(label: "dim.fatigue".localized, first: firstDimensions.fatigue, latest: latestDimensions.fatigue)
                EvolutionRow(label: "dim.warmth".localized, first: firstDimensions.warmth, latest: latestDimensions.warmth)
                EvolutionRow(label: "dim.expressiveness".localized, first: firstDimensions.expressiveness, latest: latestDimensions.expressiveness)
                EvolutionRow(label: "dim.tempo".localized, first: firstDimensions.tempo, latest: latestDimensions.tempo)
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

struct EvolutionRow: View {
    let label: String
    let first: CGFloat
    let latest: CGFloat
    private var diff: CGFloat { latest - first }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(KlunaWarm.warmBrown.opacity(0.04))
                    Capsule().fill(KlunaWarm.warmAccent.opacity(0.2)).frame(width: geo.size.width * first.clamped(to: 0...1))
                    Capsule()
                        .fill(KlunaWarm.warmAccent.opacity(0.5))
                        .frame(width: geo.size.width * latest.clamped(to: 0...1))
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())

            Image(systemName: diff > 0.05 ? "arrow.up.right" : diff < -0.05 ? "arrow.down.right" : "minus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(KlunaWarm.warmAccent.opacity(abs(diff) < 0.01 ? 0.35 : 0.8))
                .frame(width: 16)
        }
    }
}

struct StatsSection: View {
    let stats: KlunaStats

    var body: some View {
        VStack(spacing: 16) {
            Text("profile.journey_in_numbers".localized)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ProfileStatCard(icon: "waveform", value: "\(stats.totalEntries)", label: "profile.entries".localized, color: KlunaWarm.warmAccent)
                ProfileStatCard(icon: "clock", value: formatMinutes(stats.totalMinutesSpoken), label: "profile.spoken".localized, color: KlunaWarm.moodZufrieden)
                ProfileStatCard(icon: "flame.fill", value: "\(stats.longestStreak)", label: "profile.longest_streak".localized, color: Color(hex: "F5B731"))
                ProfileStatCard(icon: "calendar", value: "\(stats.activeDays)", label: "profile.active_days".localized, color: Color(hex: "7BA7C4"))
                ProfileStatCard(icon: "heart.fill", value: stats.mostFrequentMood, label: "profile.most_frequent_mood".localized, color: stats.mostFrequentMoodColor)
                ProfileStatCard(icon: "star.fill", value: stats.rarestMood, label: "profile.rarest_mood".localized, color: stats.rarestMoodColor)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) Min" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

struct ProfileStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(KlunaWarm.warmBrown)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.05)))
    }
}

struct MilestonesSection: View {
    let milestones: [ProfileMilestone]
    let onMilestoneTap: (ProfileMilestone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("profile.milestones".localized)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)
            ForEach(milestones) { milestone in
                MilestoneRow(milestone: milestone) {
                    onMilestoneTap(milestone)
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

struct MilestonePopup: View {
    let milestone: ProfileMilestone
    let onShare: () -> Void
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showButtons = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(milestone.color.opacity(0.10))
                        .frame(width: 110, height: 110)
                    Circle()
                        .fill(milestone.color.opacity(0.05))
                        .frame(width: 150, height: 150)
                    Image(systemName: milestone.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(milestone.color)
                }
                .scaleEffect(showContent ? 1 : 0.35)
                .opacity(showContent ? 1 : 0)

                Text(milestone.title)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)

                Text(milestone.description)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .opacity(showContent ? 1 : 0)

                VStack(spacing: 12) {
                    KlunaShareButton(action: onShare)

                    Button(action: onDismiss) {
                        Text("general.continue".localized)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                    }
                }
                .opacity(showButtons ? 1 : 0)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(KlunaWarm.background)
                    .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 12)
            )
            .padding(.horizontal, 32)
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.18)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.72)) {
                showButtons = true
            }
        }
    }
}

struct MilestoneRow: View {
    let milestone: ProfileMilestone
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(milestone.isUnlocked ? milestone.color.opacity(0.12) : KlunaWarm.warmBrown.opacity(0.04))
                    .frame(width: 44, height: 44)
                Image(systemName: milestone.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(milestone.isUnlocked ? milestone.color : KlunaWarm.warmBrown.opacity(0.15))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(milestone.isUnlocked ? KlunaWarm.warmBrown : KlunaWarm.warmBrown.opacity(0.25))
                Text(milestone.description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(milestone.isUnlocked ? KlunaWarm.warmBrown.opacity(0.5) : KlunaWarm.warmBrown.opacity(0.15))
                if milestone.isUnlocked, let date = milestone.unlockedDate {
                    Text(date.formatted(.dateTime.day().month(.wide)))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(milestone.color.opacity(0.6))
                }
            }

            Spacer()

            if milestone.isUnlocked {
                Button(action: onShare) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(milestone.color)
                            .font(.system(size: 18))
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(KlunaWarm.warmAccent.opacity(0.65))
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            } else if let progress = milestone.progress {
                ZStack {
                    Circle().stroke(KlunaWarm.warmBrown.opacity(0.06), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress.clamped(to: 0...1))
                        .stroke(milestone.color.opacity(0.4), lineWidth: 3)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
                }
                .frame(width: 32, height: 32)
            }
        }
    }
}

struct HowItWorksSection: View {
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: { withAnimation(.spring(response: 0.35)) { expanded.toggle() } }) {
                HStack {
                    Text("profile.how_it_works".localized)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 20) {
                    ExplanationBlock(icon: "waveform", title: "profile.explain.voice_analysis_title".localized, text: "profile.explain.voice_analysis_text".localized, color: KlunaWarm.warmAccent)
                    ExplanationBlock(icon: "lock.shield.fill", title: "profile.explain.privacy_title".localized, text: "profile.explain.privacy_text".localized, color: KlunaWarm.moodZufrieden)
                    ExplanationBlock(icon: "sparkles", title: "profile.explain.dimensions_title".localized, text: "profile.explain.dimensions_text".localized, color: Color(hex: "7BA7C4"))
                    ExplanationBlock(icon: "brain.head.profile", title: "profile.explain.coach_title".localized, text: "profile.explain.coach_text".localized, color: Color(hex: "B088A8"))
                    ExplanationBlock(icon: "chart.line.uptrend.xyaxis", title: "profile.explain.baseline_title".localized, text: "profile.explain.baseline_text".localized, color: Color(hex: "F0943D"))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
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

struct ExplanationBlock: View {
    let icon: String
    let title: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Text(text)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                    .lineSpacing(3)
            }
        }
    }
}

struct DataDonationSection: View {
    @State private var localDonation: Bool
    @State private var showDetails = false
    @State private var showGlobalStats = false
    let isPremium: Bool
    let globalStats: GlobalVoiceStats?
    let onDonationChange: (Bool) -> Void

    init(isDonating: Bool, isPremium: Bool, globalStats: GlobalVoiceStats?, onDonationChange: @escaping (Bool) -> Void) {
        self._localDonation = State(initialValue: isDonating)
        self.isPremium = isPremium
        self.globalStats = globalStats
        self.onDonationChange = onDonationChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(hex: "6BC5A0"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("profile.donation.research_title".localized)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Text("profile.donation.research_subtitle".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                }
                Spacer()
                Toggle("", isOn: $localDonation)
                    .labelsHidden()
                    .tint(Color(hex: "6BC5A0"))
                    .onChange(of: localDonation) { _, value in onDonationChange(value) }
            }

            VStack(alignment: .leading, spacing: 12) {
                DonationInfoRow(icon: "checkmark.shield.fill", text: "profile.donation.info_1".localized, color: Color(hex: "6BC5A0"))
                DonationInfoRow(icon: "waveform.badge.magnifyingglass", text: "profile.donation.info_2".localized, color: Color(hex: "6BC5A0"))
                DonationInfoRow(icon: "chart.line.uptrend.xyaxis", text: "profile.donation.info_3".localized, color: Color(hex: "6BC5A0"))
                DonationInfoRow(icon: "globe.europe.africa", text: "profile.donation.info_4".localized, color: Color(hex: "6BC5A0"))
            }

            Button(action: { withAnimation(.spring(response: 0.35)) { showDetails.toggle() } }) {
                HStack {
                    Text("profile.donation.what_sent".localized)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmAccent)
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(KlunaWarm.warmAccent)
                }
            }

            if showDetails {
                VStack(alignment: .leading, spacing: 12) {
                    DetailGroup(title: "profile.donation.group_voice_quality".localized, items: [
                        "profile.donation.item_jitter".localized,
                        "profile.donation.item_shimmer".localized,
                        "profile.donation.item_hnr".localized,
                    ])
                    DetailGroup(title: "profile.donation.group_pitch".localized, items: [
                        "profile.donation.item_pitch_mean".localized,
                        "profile.donation.item_pitch_variation".localized,
                        "profile.donation.item_pitch_range".localized,
                    ])
                    DetailGroup(title: "profile.donation.group_rhythm".localized, items: [
                        "profile.donation.item_speech_rate".localized,
                        "profile.donation.item_articulation_rate".localized,
                        "profile.donation.item_pause_metrics".localized,
                    ])
                    DetailGroup(title: "profile.donation.group_loudness".localized, items: [
                        "profile.donation.item_dynamic_range".localized,
                        "profile.donation.item_loudness_variation".localized,
                    ])
                    DetailGroup(title: "profile.donation.group_spectral".localized, items: [
                        "profile.donation.item_formants".localized,
                        "profile.donation.item_formant_dispersion".localized,
                        "profile.donation.item_spectral_distribution".localized,
                    ])
                    DetailGroup(title: "profile.donation.group_derived".localized, items: [
                        "profile.donation.item_dimensions".localized,
                        "profile.donation.item_arousal_valence".localized,
                        "profile.donation.item_zscores".localized,
                        "profile.donation.item_flags".localized,
                    ])
                    DetailGroup(title: "profile.donation.group_context".localized, items: [
                        "profile.donation.item_mood".localized,
                        "profile.donation.item_age_gender".localized,
                        "profile.donation.item_entry_index".localized,
                    ])

                    VStack(alignment: .leading, spacing: 6) {
                        Text("profile.donation.not_sent_title".localized)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color(hex: "E85C5C"))
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color(hex: "E85C5C"))
                            Text("profile.donation.not_sent_values".localized)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Color(hex: "E85C5C").opacity(0.72))
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "6BC5A0").opacity(0.04)))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if localDonation && isPremium {
                Button(action: { showGlobalStats = true }) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Color(hex: "6BC5A0"))
                        Text("profile.donation.global_stats".localized)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(Color(hex: "6BC5A0"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "6BC5A0").opacity(0.5))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "6BC5A0").opacity(0.2), lineWidth: 1))
                }
                .sheet(isPresented: $showGlobalStats) {
                    GlobalStatsSheet(stats: globalStats)
                }
            } else if localDonation && !isPremium {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(KlunaWarm.warmAccent)
                    Text("profile.donation.premium_hint".localized)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(KlunaWarm.warmAccent.opacity(0.04)))
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

struct DonationInfoRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 16)
                .padding(.top, 2)
            Text(text)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                .lineSpacing(2)
        }
    }
}

struct DetailGroup: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(Color(hex: "6BC5A0").opacity(0.4))
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)
                    Text(item)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                }
            }
        }
    }
}

struct GlobalStatsSheet: View {
    let stats: GlobalVoiceStats?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(stats?.totalDonors ?? 0)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "6BC5A0"))
                        Text("profile.global.donors_subtitle".localized)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    }
                    .padding(.top, 16)

                    VStack(spacing: 12) {
                        Text("profile.global.averages_title".localized)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown)
                        GlobalComparisonRow(label: "profile.global.warmth".localized, globalAvg: stats?.avgWarmth ?? 0.5)
                        GlobalComparisonRow(label: "profile.global.stability".localized, globalAvg: stats?.avgStability ?? 0.5)
                        GlobalComparisonRow(label: "dim.energy".localized, globalAvg: stats?.avgEnergy ?? 0.5)
                        GlobalComparisonRow(label: "dim.tempo".localized, globalAvg: stats?.avgTempo ?? 0.5)
                        GlobalComparisonRow(label: "profile.global.openness".localized, globalAvg: stats?.avgOpenness ?? 0.5)
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 20).fill(KlunaWarm.cardBackground))

                    VStack(spacing: 8) {
                        Text("profile.global.most_common_mood".localized)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                        Text(stats?.mostCommonMood ?? "mood.ruhig".localized)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(KlunaWarm.warmAccent)
                    }
                }
                .padding(20)
            }
            .background(KlunaWarm.background)
            .navigationTitle("profile.global.nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("home.done".localized) { dismiss() }
                        .foregroundStyle(KlunaWarm.warmAccent)
                }
            }
        }
    }
}

struct GlobalComparisonRow: View {
    let label: String
    let globalAvg: CGFloat

    var body: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(KlunaWarm.warmBrown.opacity(0.05))
                    Capsule().fill(KlunaWarm.warmAccent.opacity(0.45)).frame(width: geo.size.width * globalAvg.clamped(to: 0...1))
                }
            }
            .frame(height: 6)
            Text("\(Int(globalAvg * 100))")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                .frame(width: 28, alignment: .trailing)
        }
        .frame(height: 14)
    }
}

struct ProfileSettingsSection: View {
    let isPremium: Bool
    let onAction: (SettingsAction) -> Void

    var body: some View {
        VStack(spacing: 2) {
            if !isPremium {
                ProfileSettingsRow(icon: "crown.fill", label: "profile.settings.premium".localized, color: Color(hex: "F5B731")) {
                    onAction(.premium)
                }
            }
            ProfileSettingsRow(icon: "pencil", label: "profile.change_name".localized, color: KlunaWarm.warmBrown.opacity(0.5)) { onAction(.editName) }
            ProfileSettingsRow(icon: "square.and.arrow.up", label: "profile.export_data".localized, color: KlunaWarm.warmBrown.opacity(0.5)) { onAction(.export) }
            ProfileSettingsRow(icon: "square.and.arrow.down", label: "profile.settings.export_app_icon".localized, color: KlunaWarm.warmAccent.opacity(0.6)) { onAction(.exportAppIcon) }
            ProfileSettingsRow(icon: "bell", label: "profile.settings.reminders".localized, color: KlunaWarm.warmBrown.opacity(0.5)) { onAction(.notifications) }
            ProfileSettingsRow(icon: "hand.raised.fill", label: "profile.settings.privacy".localized, color: KlunaWarm.warmBrown.opacity(0.5)) { onAction(.privacy) }
            ProfileSettingsRow(icon: "trash", label: "profile.settings.delete_all".localized, color: Color(hex: "E85C5C").opacity(0.6)) { onAction(.deleteAll) }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
    }
}

struct ProfileSettingsRow: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(label)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

struct ProfileVoiceDimensions {
    let energy: CGFloat
    let tension: CGFloat
    let fatigue: CGFloat
    let warmth: CGFloat
    let expressiveness: CGFloat
    let tempo: CGFloat

    static func from(_ entry: JournalEntry) -> ProfileVoiceDimensions {
        let dims = VoiceDimensions.from(entry)
        return ProfileVoiceDimensions(
            energy: dims.energy,
            tension: dims.tension,
            fatigue: dims.fatigue,
            warmth: dims.warmth,
            expressiveness: dims.expressiveness,
            tempo: dims.tempo
        )
    }
}

struct ProfileVoiceTypeModel {
    let name: String
    let description: String
    let color: Color
    let dimensions: [DimensionSummary]

    static func from(entries: [JournalEntry]) -> ProfileVoiceTypeModel? {
        guard entries.count >= 7 else { return nil }
        let dims = entries.map(ProfileVoiceDimensions.from)
        let count = CGFloat(dims.count)
        let avg = ProfileVoiceDimensions(
            energy: dims.map(\.energy).reduce(0, +) / count,
            tension: dims.map(\.tension).reduce(0, +) / count,
            fatigue: dims.map(\.fatigue).reduce(0, +) / count,
            warmth: dims.map(\.warmth).reduce(0, +) / count,
            expressiveness: dims.map(\.expressiveness).reduce(0, +) / count,
            tempo: dims.map(\.tempo).reduce(0, +) / count,
        )
        let name: String
        let description: String
        let color: Color
        if avg.energy > 0.65 && avg.tension < 0.35 && avg.warmth > 0.6 {
            name = "Der warme Energetiker"
            description = "Du klingst kraftvoll und gleichzeitig zugewandt. Deine Stimme trägt Energie mit Gelassenheit."
            color = KlunaWarm.moodBegeistert
        } else if avg.tension > 0.65 && avg.tempo > 0.6 && avg.fatigue < 0.45 {
            name = "Der getriebene Macher"
            description = "Du klingst unter Strom und sehr fokussiert. Viel Vorwärtsdrang, aber mit hörbarer Grundspannung."
            color = KlunaWarm.moodAngespannt
        } else if avg.fatigue > 0.6 && avg.energy < 0.45 && avg.warmth > 0.55 {
            name = "Der sanfte Beobachter"
            description = "Du wirkst leise und aufmerksam. Warm im Ton, aber mit hörbarer Erschöpfung."
            color = KlunaWarm.moodErschoepft
        } else if avg.tension < 0.4 && avg.energy > 0.45 && avg.expressiveness > 0.6 {
            name = "Der gelassene Erzähler"
            description = "Du klingst entspannt und ausdrucksstark. Deine Stimme erzählt mit natürlicher Melodie."
            color = KlunaWarm.moodZufrieden
        } else if avg.tension > 0.6 && avg.energy > 0.6 && avg.warmth < 0.45 {
            name = "Der kontrollierte Stratege"
            description = "Du wirkst präzise und angespannt. Viel Energie, aber mit kontrollierter Distanz."
            color = KlunaWarm.moodAufgewuehlt
        } else if avg.energy > 0.65 && avg.tempo > 0.6 {
            name = "Der energetische Macher"
            description = "Deine Stimme hat Drive und Präsenz. Du klingst aktiv, direkt und nach vorne gerichtet."
            color = KlunaWarm.moodBegeistert
        } else {
            name = "Der sensible Spiegel"
            description = "Deine Stimme zeigt feine Nuancen. Du transportierst Stimmung und Bedeutung sehr unmittelbar."
            color = KlunaWarm.moodVerletzlich
        }
        return ProfileVoiceTypeModel(
            name: name,
            description: description,
            color: color,
            dimensions: [
                DimensionSummary(label: "Energie", shortLabel: "E", value: avg.energy),
                DimensionSummary(label: "Anspannung", shortLabel: "A", value: avg.tension),
                DimensionSummary(label: "Müdigkeit", shortLabel: "M", value: avg.fatigue),
                DimensionSummary(label: "Wärme", shortLabel: "W", value: avg.warmth),
                DimensionSummary(label: "Lebendigkeit", shortLabel: "L", value: avg.expressiveness),
                DimensionSummary(label: "Tempo", shortLabel: "T", value: avg.tempo),
            ]
        )
    }
}

struct DimensionSummary {
    let label: String
    let shortLabel: String
    let value: CGFloat
}

struct KlunaStats {
    let totalEntries: Int
    let totalMinutesSpoken: Int
    let longestStreak: Int
    let currentStreak: Int
    let activeDays: Int
    let mostFrequentMood: String
    let mostFrequentMoodColor: Color
    let rarestMood: String
    let rarestMoodColor: Color
    let uniqueMoodsUsed: Int
    let usedMoods: Set<String>
    let isDonating: Bool
    let contradictionCount: Int
    let shareCount: Int
    let maxEnergy: CGFloat
    let minTension: CGFloat
    let minFatigue: CGFloat
    let maxWarmth: CGFloat
    let hasEntryAfterMidnight: Bool
    let hasEntryBefore6am: Bool
    let maxThemeCount: Int
    let maxMoodsInOneDay: Int

    static func from(entries: [JournalEntry], isDonating: Bool) -> KlunaStats {
        let totalEntries = entries.count
        let totalMinutesSpoken = Int(entries.reduce(0.0) { $0 + $1.duration } / 60.0)
        let activeDays = Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
        let longestStreak = streak(entries: entries, mode: .longest)
        let currentStreak = streak(entries: entries, mode: .current)

        let moodKeys = entries.map { ($0.mood ?? $0.quadrant.rawValue).lowercased() }
        let grouped = Dictionary(grouping: moodKeys, by: { $0 }).mapValues(\.count)
        let most = grouped.max(by: { $0.value < $1.value })?.key ?? "ruhig"
        let rare = grouped.min(by: { $0.value < $1.value })?.key ?? "ruhig"
        let used = Set(moodKeys)
        let contradictionCount = entries.filter { ContradictionStore.load(for: $0.id) != nil }.count
        let shareCount = UserDefaults.standard.integer(forKey: "kluna_share_count")
        let dimensions = entries.map(VoiceDimensions.from)
        let maxEnergy = dimensions.map(\.energy).max() ?? 0
        let minTension = dimensions.map(\.tension).min() ?? 1
        let minFatigue = dimensions.map(\.fatigue).min() ?? 1
        let maxWarmth = dimensions.map(\.warmth).max() ?? 0
        let hasEntryAfterMidnight = entries.contains { Calendar.current.component(.hour, from: $0.date) < 1 }
        let hasEntryBefore6am = entries.contains { Calendar.current.component(.hour, from: $0.date) < 6 }

        var themeBuckets: [String: Int] = [:]
        for entry in entries {
            for theme in entry.themes where !theme.isEmpty {
                themeBuckets[theme.lowercased(), default: 0] += 1
            }
        }
        let maxThemeCount = themeBuckets.values.max() ?? 0

        let dayMoodCounts = Dictionary(grouping: entries, by: { Calendar.current.startOfDay(for: $0.date) })
            .mapValues { dayEntries in
                Set(dayEntries.map { ($0.mood ?? $0.quadrant.rawValue).lowercased() }).count
            }
        let maxMoodsInOneDay = dayMoodCounts.values.max() ?? 0

        let mostResolved = MoodCategory.resolve(most)?.rawValue ?? most
        let rareResolved = MoodCategory.resolve(rare)?.rawValue ?? rare

        return KlunaStats(
            totalEntries: totalEntries,
            totalMinutesSpoken: totalMinutesSpoken,
            longestStreak: longestStreak,
            currentStreak: currentStreak,
            activeDays: activeDays,
            mostFrequentMood: mostResolved.capitalized,
            mostFrequentMoodColor: KlunaWarm.moodColor(for: mostResolved, fallbackQuadrant: .zufrieden),
            rarestMood: rareResolved.capitalized,
            rarestMoodColor: KlunaWarm.moodColor(for: rareResolved, fallbackQuadrant: .erschoepft),
            uniqueMoodsUsed: used.count,
            usedMoods: used,
            isDonating: isDonating,
            contradictionCount: contradictionCount,
            shareCount: shareCount,
            maxEnergy: maxEnergy,
            minTension: minTension,
            minFatigue: minFatigue,
            maxWarmth: maxWarmth,
            hasEntryAfterMidnight: hasEntryAfterMidnight,
            hasEntryBefore6am: hasEntryBefore6am,
            maxThemeCount: maxThemeCount,
            maxMoodsInOneDay: maxMoodsInOneDay
        )
    }

    private enum StreakMode { case longest, current }

    private static func streak(entries: [JournalEntry], mode: StreakMode) -> Int {
        let days = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()

        if mode == .current {
            var current = 0
            var day = Calendar.current.startOfDay(for: Date())
            if !days.contains(day), let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) {
                day = prev
            }
            while days.contains(day) {
                current += 1
                guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            }
            return current
        }

        var best = 1
        var run = 1
        for idx in 1..<sorted.count {
            let prev = sorted[idx - 1]
            let cur = sorted[idx]
            let delta = Calendar.current.dateComponents([.day], from: prev, to: cur).day ?? 99
            if delta == 1 {
                run += 1
            } else {
                best = max(best, run)
                run = 1
            }
        }
        return max(best, run)
    }

    func hasUsedMood(_ mood: String) -> Bool {
        usedMoods.contains(mood.lowercased())
    }
}

struct ProfileMilestone: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
    let unlockedDate: Date?
    let progress: CGFloat?
}

func allMilestones(stats: KlunaStats, firstEntryDate: Date?) -> [ProfileMilestone] {
    [
        ProfileMilestone(title: "profile.milestone.first_step.title".localized, description: "profile.milestone.first_step.description".localized, icon: "mic.fill", color: KlunaWarm.warmAccent, isUnlocked: stats.totalEntries >= 1, unlockedDate: firstEntryDate, progress: stats.totalEntries >= 1 ? 1 : 0),
        ProfileMilestone(title: "profile.milestone.week.title".localized, description: "profile.milestone.week.description".localized, icon: "flame.fill", color: Color(hex: "F5B731"), isUnlocked: stats.longestStreak >= 7, unlockedDate: nil, progress: min(CGFloat(stats.longestStreak) / 7, 1)),
        ProfileMilestone(title: "profile.milestone.month_hero.title".localized, description: "profile.milestone.month_hero.description".localized, icon: "trophy.fill", color: Color(hex: "E85C5C"), isUnlocked: stats.longestStreak >= 30, unlockedDate: nil, progress: min(CGFloat(stats.longestStreak) / 30, 1)),
        ProfileMilestone(title: "profile.milestone.entries_10.title".localized, description: "profile.milestone.entries_10.description".localized, icon: "waveform", color: KlunaWarm.moodZufrieden, isUnlocked: stats.totalEntries >= 10, unlockedDate: nil, progress: min(CGFloat(stats.totalEntries) / 10, 1)),
        ProfileMilestone(title: "profile.milestone.entries_50.title".localized, description: "profile.milestone.entries_50.description".localized, icon: "waveform.badge.magnifyingglass", color: Color(hex: "7BA7C4"), isUnlocked: stats.totalEntries >= 50, unlockedDate: nil, progress: min(CGFloat(stats.totalEntries) / 50, 1)),
        ProfileMilestone(title: "profile.milestone.entries_100.title".localized, description: "profile.milestone.entries_100.description".localized, icon: "star.fill", color: Color(hex: "B088A8"), isUnlocked: stats.totalEntries >= 100, unlockedDate: nil, progress: min(CGFloat(stats.totalEntries) / 100, 1)),
        ProfileMilestone(title: "profile.milestone.full_palette.title".localized, description: "profile.milestone.full_palette.description".localized, icon: "paintpalette.fill", color: Color(hex: "F0943D"), isUnlocked: stats.uniqueMoodsUsed >= 10, unlockedDate: nil, progress: CGFloat(stats.uniqueMoodsUsed) / 10),
        ProfileMilestone(title: "profile.milestone.vulnerable.title".localized, description: "profile.milestone.vulnerable.description".localized, icon: "heart.fill", color: Color(hex: "B088A8"), isUnlocked: stats.hasUsedMood("verletzlich"), unlockedDate: nil, progress: nil),
        ProfileMilestone(title: "profile.milestone.voice_type.title".localized, description: "profile.milestone.voice_type.description".localized, icon: "person.crop.circle.badge.checkmark", color: KlunaWarm.warmAccent, isUnlocked: stats.totalEntries >= 7, unlockedDate: nil, progress: min(CGFloat(stats.totalEntries) / 7, 1)),
        ProfileMilestone(title: "profile.milestone.researcher.title".localized, description: "profile.milestone.researcher.description".localized, icon: "heart.circle.fill", color: Color(hex: "6BC5A0"), isUnlocked: stats.isDonating, unlockedDate: nil, progress: nil),
        ProfileMilestone(title: "profile.milestone.one_hour.title".localized, description: "profile.milestone.one_hour.description".localized, icon: "clock.fill", color: Color(hex: "4DB8A4"), isUnlocked: stats.totalMinutesSpoken >= 60, unlockedDate: nil, progress: min(CGFloat(stats.totalMinutesSpoken) / 60, 1)),
    ]
}

struct Badge: Identifiable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    let category: BadgeCategory
    let condition: (KlunaStats) -> Bool
    let shareText: String
    var isUnlocked: Bool = false
    var unlockedDate: Date? = nil
}

enum BadgeCategory: String, CaseIterable {
    case beginnings
    case streak
    case entries
    case emotions
    case discoveries

    var color: Color {
        switch self {
        case .beginnings: return Color(hex: "E8825C")
        case .streak: return Color(hex: "F5B731")
        case .entries: return Color(hex: "4DB8A4")
        case .emotions: return Color(hex: "B088A8")
        case .discoveries: return Color(hex: "7BA7C4")
        }
    }

    var displayName: String {
        "badge.category.\(rawValue)".localized
    }
}

@MainActor
final class BadgeManager: ObservableObject {
    static let shared = BadgeManager()
    @Published var allBadges: [Badge] = []
    @Published var newlyUnlocked: Badge?

    private let storageKey = "kluna_badges_v2"

    private init() {
        loadBadges()
    }

    func checkBadges(stats: KlunaStats) {
        for idx in allBadges.indices {
            if allBadges[idx].isUnlocked { continue }
            if allBadges[idx].condition(stats) {
                allBadges[idx].isUnlocked = true
                allBadges[idx].unlockedDate = Date()
                KlunaAnalytics.shared.track("badge_unlocked", value: allBadges[idx].id)
                newlyUnlocked = allBadges[idx]
                saveBadges()
                return
            }
        }
    }

    func dismissUnlockedBadge() {
        newlyUnlocked = nil
    }

    func reset() {
        allBadges = allBadgeDefinitions()
        newlyUnlocked = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func saveBadges() {
        let payload = allBadges.map {
            [
                "id": $0.id,
                "unlocked": $0.isUnlocked,
                "date": $0.unlockedDate?.timeIntervalSince1970 ?? 0,
            ] as [String: Any]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadBadges() {
        allBadges = allBadgeDefinitions()
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        for item in saved {
            guard let id = item["id"] as? String,
                  let unlocked = item["unlocked"] as? Bool,
                  let index = allBadges.firstIndex(where: { $0.id == id }) else { continue }

            allBadges[index].isUnlocked = unlocked
            if let ts = item["date"] as? TimeInterval, ts > 0 {
                allBadges[index].unlockedDate = Date(timeIntervalSince1970: ts)
            }
        }
    }
}

private func allBadgeDefinitions() -> [Badge] {
    func badge(
        id: String,
        emoji: String,
        category: BadgeCategory,
        condition: @escaping (KlunaStats) -> Bool
    ) -> Badge {
        Badge(
            id: id,
            title: "badge.\(id).title".localized,
            description: "badge.\(id).description".localized,
            emoji: emoji,
            category: category,
            condition: condition,
            shareText: "badge.\(id).share".localized
        )
    }

    let beginnerBadges: [Badge] = [
        badge(id: "first_entry", emoji: "🎙", category: .beginnings, condition: { $0.totalEntries >= 1 }),
        badge(id: "first_contradiction", emoji: "🔍", category: .beginnings, condition: { $0.contradictionCount >= 1 }),
        badge(id: "voice_type_discovered", emoji: "🧬", category: .beginnings, condition: { $0.totalEntries >= 7 }),
        badge(id: "first_share", emoji: "📤", category: .beginnings, condition: { $0.shareCount >= 1 }),
        badge(id: "donor", emoji: "🔬", category: .beginnings, condition: { $0.isDonating }),
    ]

    let streakBadges: [Badge] = [
        badge(id: "streak_3", emoji: "🔥", category: .streak, condition: { $0.longestStreak >= 3 }),
        badge(id: "streak_7", emoji: "🔥", category: .streak, condition: { $0.longestStreak >= 7 }),
        badge(id: "streak_14", emoji: "🔥", category: .streak, condition: { $0.longestStreak >= 14 }),
        badge(id: "streak_30", emoji: "👑", category: .streak, condition: { $0.longestStreak >= 30 }),
        badge(id: "streak_100", emoji: "💎", category: .streak, condition: { $0.longestStreak >= 100 }),
    ]

    let entryBadges: [Badge] = [
        badge(id: "entries_10", emoji: "✨", category: .entries, condition: { $0.totalEntries >= 10 }),
        badge(id: "entries_50", emoji: "💫", category: .entries, condition: { $0.totalEntries >= 50 }),
        badge(id: "entries_100", emoji: "💎", category: .entries, condition: { $0.totalEntries >= 100 }),
        badge(id: "entries_365", emoji: "🏆", category: .entries, condition: { $0.totalEntries >= 365 }),
        badge(id: "hour_spoken", emoji: "⏱", category: .entries, condition: { $0.totalMinutesSpoken >= 60 }),
    ]

    let emotionBadges: [Badge] = [
        badge(id: "full_palette", emoji: "🎨", category: .emotions, condition: { $0.uniqueMoodsUsed >= 10 }),
        badge(id: "vulnerable", emoji: "💜", category: .emotions, condition: { $0.hasUsedMood("verletzlich") }),
        badge(id: "high_energy", emoji: "🌋", category: .emotions, condition: { $0.maxEnergy >= 0.9 }),
        badge(id: "deepest_calm", emoji: "🧘", category: .emotions, condition: { $0.minTension <= 0.15 && $0.minFatigue <= 0.1 }),
        badge(id: "warmest_day", emoji: "☀️", category: .emotions, condition: { $0.maxWarmth >= 0.8 }),
    ]

    let discoveryBadges: [Badge] = [
        badge(id: "night_owl", emoji: "🦉", category: .discoveries, condition: { $0.hasEntryAfterMidnight }),
        badge(id: "early_bird", emoji: "🌅", category: .discoveries, condition: { $0.hasEntryBefore6am }),
        badge(id: "theme_master", emoji: "🧵", category: .discoveries, condition: { $0.maxThemeCount >= 10 }),
        badge(id: "mood_shift", emoji: "🎢", category: .discoveries, condition: { $0.maxMoodsInOneDay >= 3 }),
        badge(id: "baseline_mature", emoji: "🧠", category: .discoveries, condition: { $0.totalEntries >= 30 }),
    ]

    return beginnerBadges + streakBadges + entryBadges + emotionBadges + discoveryBadges
}

struct BadgePreviewSection: View {
    let badges: [Badge]
    let stats: KlunaStats
    @State private var showAllBadges = false

    private var unlocked: [Badge] {
        badges.filter(\.isUnlocked).sorted { ($0.unlockedDate ?? .distantPast) < ($1.unlockedDate ?? .distantPast) }
    }
    private var locked: [Badge] { badges.filter { !$0.isUnlocked } }
    private var nextBadge: Badge? { locked.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("profile.milestones".localized)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(KlunaWarm.warmBrown)

                Spacer()

                Button(action: { showAllBadges = true }) {
                    HStack(spacing: 4) {
                        Text("\(unlocked.count)/\(badges.count)")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundColor(KlunaWarm.warmAccent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(KlunaWarm.warmAccent.opacity(0.5))
                    }
                }
            }

            HStack(spacing: 16) {
                ForEach(Array(unlocked.suffix(3))) { badge in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(badge.category.color.opacity(0.1))
                                .frame(width: 64, height: 64)
                            Text(badge.emoji)
                                .font(.system(size: 32))
                        }
                        Text(badge.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(KlunaWarm.warmBrown.opacity(0.6))
                            .lineLimit(1)
                    }
                }

                if let next = nextBadge {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(KlunaWarm.warmBrown.opacity(0.03))
                                .frame(width: 64, height: 64)
                            if let progress = badgeProgress(next, stats) {
                                Circle()
                                    .trim(from: 0, to: 0.75)
                                    .stroke(KlunaWarm.warmBrown.opacity(0.04), lineWidth: 3)
                                    .frame(width: 64, height: 64)
                                    .rotationEffect(.degrees(135))
                                Circle()
                                    .trim(from: 0, to: CGFloat(progress) * 0.75)
                                    .stroke(next.category.color.opacity(0.4), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 64, height: 64)
                                    .rotationEffect(.degrees(135))
                            } else {
                                Circle()
                                    .stroke(KlunaWarm.warmBrown.opacity(0.06), lineWidth: 2)
                                    .frame(width: 64, height: 64)
                            }
                            Text(next.emoji)
                                .font(.system(size: 32))
                                .opacity(0.12)
                            if let progress = badgeProgress(next, stats) {
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(next.category.color.opacity(0.5))
                            } else {
                                Text("?")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(KlunaWarm.warmBrown.opacity(0.1))
                            }
                        }
                        Text(next.title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(KlunaWarm.warmBrown.opacity(0.3))
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
        )
        .sheet(isPresented: $showAllBadges) {
            AllBadgesView(badges: badges, stats: stats)
        }
    }
}

struct AllBadgesView: View {
    let badges: [Badge]
    let stats: KlunaStats
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    let unlockedCount = badges.filter(\.isUnlocked).count
                    VStack(spacing: 4) {
                        Text("\(unlockedCount)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(KlunaWarm.warmAccent)
                        Text(String(format: "profile.milestones_reached_of_total".localized, badges.count))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(KlunaWarm.warmBrown.opacity(0.3))
                    }
                    .padding(.top, 16)

                    ForEach(BadgeCategory.allCases, id: \.rawValue) { category in
                        let categoryBadges = badges.filter { $0.category == category }
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(category.color)
                                    .frame(width: 3, height: 18)
                                Text(category.displayName)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundColor(KlunaWarm.warmBrown)
                                Spacer()
                                Text("\(categoryBadges.filter(\.isUnlocked).count)/\(categoryBadges.count)")
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundColor(KlunaWarm.warmBrown.opacity(0.2))
                            }

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16),
                                ],
                                spacing: 20
                            ) {
                                ForEach(categoryBadges) { badge in
                                    BadgeCell(badge: badge, stats: stats)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(KlunaWarm.background)
            .navigationTitle("profile.milestones".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(KlunaWarm.warmBrown.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(KlunaWarm.warmBrown.opacity(0.05)))
                    }
                }
            }
        }
    }
}

struct BadgeCell: View {
    let badge: Badge
    let stats: KlunaStats

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? badge.category.color.opacity(0.1) : KlunaWarm.warmBrown.opacity(0.02))
                    .frame(width: 80, height: 80)

                if !badge.isUnlocked, let progress = badgeProgress(badge, stats) {
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(KlunaWarm.warmBrown.opacity(0.04), lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(135))
                    Circle()
                        .trim(from: 0, to: 0.75 * CGFloat(progress))
                        .stroke(badge.category.color.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(135))
                }

                if badge.isUnlocked {
                    Text(badge.emoji)
                        .font(.system(size: 40))
                } else {
                    Text(badge.emoji)
                        .font(.system(size: 40))
                        .opacity(0.1)
                    if let progress = badgeProgress(badge, stats) {
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(badge.category.color.opacity(0.5))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(KlunaWarm.warmBrown.opacity(0.12))
                    }
                }
            }

            Text(badge.title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(badge.isUnlocked ? KlunaWarm.warmBrown : KlunaWarm.warmBrown.opacity(0.25))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(badge.description)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(badge.isUnlocked ? KlunaWarm.warmBrown.opacity(0.45) : KlunaWarm.warmBrown.opacity(0.2))
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)

            if badge.isUnlocked, let date = badge.unlockedDate {
                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(badge.category.color.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

func badgeProgressValue(for badge: Badge, stats: KlunaStats) -> Float? {
    switch badge.id {
    case "streak_3": return min(Float(stats.longestStreak) / 3, 1)
    case "streak_7": return min(Float(stats.longestStreak) / 7, 1)
    case "streak_14": return min(Float(stats.longestStreak) / 14, 1)
    case "streak_30": return min(Float(stats.longestStreak) / 30, 1)
    case "streak_100": return min(Float(stats.longestStreak) / 100, 1)
    case "entries_10": return min(Float(stats.totalEntries) / 10, 1)
    case "entries_50": return min(Float(stats.totalEntries) / 50, 1)
    case "entries_100": return min(Float(stats.totalEntries) / 100, 1)
    case "entries_365": return min(Float(stats.totalEntries) / 365, 1)
    case "hour_spoken": return min(Float(stats.totalMinutesSpoken) / 60, 1)
    case "voice_type_discovered": return min(Float(stats.totalEntries) / 7, 1)
    case "baseline_mature": return min(Float(stats.totalEntries) / 30, 1)
    case "full_palette": return min(Float(stats.uniqueMoodsUsed) / 10, 1)
    case "theme_master": return min(Float(stats.maxThemeCount) / 10, 1)
    default: return nil
    }
}

private func badgeProgress(_ badge: Badge, _ stats: KlunaStats) -> Float? {
    badgeProgressValue(for: badge, stats: stats)
}

enum CoachFeedbackStore {
    private static let prefix = "kluna_coach_feedback_"

    static func get(for entryId: UUID) -> Int? {
        let key = "\(prefix)\(entryId.uuidString)"
        let value = UserDefaults.standard.integer(forKey: key)
        return UserDefaults.standard.object(forKey: key) == nil ? nil : value
    }

    static func save(_ value: Int, for entryId: UUID) {
        let key = "\(prefix)\(entryId.uuidString)"
        UserDefaults.standard.set(value, forKey: key)
    }

    static func totalCount() -> Int {
        UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }.count
    }
}

struct KlunaScore {
    static func calculate(
        entryCount: Int,
        uniqueDays: Int,
        avgRoundsPerConversation: Float,
        memoryDepth: Int,
        feedbackCount: Int
    ) -> Int {
        var score: Float = 0
        score += min(30, logf(Float(entryCount + 1)) / logf(500) * 30)
        score += min(25, Float(uniqueDays) / 90.0 * 25)
        score += min(20, avgRoundsPerConversation / 4.0 * 20)
        score += min(15, Float(memoryDepth) * 3.0)
        score += min(10, Float(feedbackCount) / 20.0 * 10)
        return min(95, Int(score))
    }
}

private struct KlunaScoreProfileView: View {
    let score: Int
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(KlunaWarm.warmBrown.opacity(0.05), lineWidth: 6)
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100.0 * 0.75)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "E8825C"), Color(hex: "F5B731")], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 84, height: 84)
                    .rotationEffect(.degrees(135))

                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown)
                    Text("%")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                }
            }

            Text(isGerman ? "So gut kennt Kluna dich" : "How well Kluna knows you")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

private struct ProfileTopStatsCard: View {
    let totalEntries: Int
    let currentStreak: Int
    let klunaScore: Int

    var body: some View {
        HStack(spacing: 0) {
            ProfileTopStat(value: "\(totalEntries)", label: "Einträge")
            Divider().frame(height: 32).opacity(0.25)
            ProfileTopStat(value: "\(currentStreak)", label: "Streak")
            Divider().frame(height: 32).opacity(0.25)
            ProfileTopStat(value: "\(klunaScore)%", label: "Kluna Score")
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

private struct ProfileTopStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileBlobAvatar: View {
    let dims: VoiceDimensions
    let mood: String

    @State private var phase: CGFloat = 0
    @State private var breathe: CGFloat = 1.0
    @State private var isTouching = false

    private var primaryColor: Color { KlunaWarm.moodColor(for: mood, fallbackQuadrant: .zufrieden) }
    private let blobSize: CGFloat = 80
    private var distortion: CGFloat { dims.tension * 12 }

    var body: some View {
        ZStack {
            BlobShape(phase: phase, distortion: distortion * 0.3)
                .fill(primaryColor.opacity(0.06))
                .frame(width: blobSize * 1.5, height: blobSize * 1.5)

            BlobShape(phase: phase, distortion: distortion, touchPoint: .init(x: 0.5, y: 0.5), touchIntensity: isTouching ? 0.4 : 0)
                .fill(
                    RadialGradient(
                        colors: [primaryColor.opacity(0.6), primaryColor],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: blobSize * 0.4
                    )
                )
                .frame(width: blobSize * breathe, height: blobSize * breathe)
                .shadow(color: primaryColor.opacity(0.15), radius: 12, x: 0, y: 6)

            BlobShape(phase: phase + 1.0, distortion: distortion * 0.3)
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.25), Color.clear],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: blobSize * 0.3
                    )
                )
                .frame(width: blobSize * 0.7, height: blobSize * 0.6)
                .offset(x: -blobSize * 0.05, y: -blobSize * 0.08)
        }
        .frame(width: blobSize * 1.5, height: blobSize * 1.5)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isTouching {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { isTouching = true }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { isTouching = false }
                }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathe = 1.04
            }
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

private struct ProfileEvolutionView: View {
    let entries: [JournalEntry]

    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        let sorted = entries.sorted(by: { $0.date < $1.date })
        let first5 = Array(sorted.prefix(5))
        let last5 = Array(sorted.suffix(5))

        let firstDims = averageDims(first5)
        let lastDims = averageDims(last5)
        let firstMood = dominantMood(first5)
        let lastMood = dominantMood(last5)

        return VStack(spacing: 16) {
            Text(isGerman ? "Deine Entwicklung" : "Your Evolution")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)

            HStack(spacing: 24) {
                VStack(spacing: 8) {
                    MiniEvolutionBlob(dims: firstDims, mood: firstMood, size: 56)
                    Text(isGerman ? "Anfang" : "Start")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                }

                VStack(spacing: 6) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "6BC5A0").opacity(0.35))
                    let changes = significantChanges(before: firstDims, after: lastDims)
                    if !changes.isEmpty {
                        Text(changes)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color(hex: "6BC5A0").opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(spacing: 8) {
                    MiniEvolutionBlob(dims: lastDims, mood: lastMood, size: 56)
                    Text(isGerman ? "Jetzt" : "Now")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    private func averageDims(_ entries: [JournalEntry]) -> VoiceDimensions {
        guard !entries.isEmpty else {
            return VoiceDimensions(energy: 0.5, tension: 0.5, fatigue: 0.5, warmth: 0.5, expressiveness: 0.5, tempo: 0.5)
        }
        let dims = entries.map(VoiceDimensions.from)
        let count = CGFloat(max(1, dims.count))
        return VoiceDimensions(
            energy: dims.map(\.energy).reduce(0, +) / count,
            tension: dims.map(\.tension).reduce(0, +) / count,
            fatigue: dims.map(\.fatigue).reduce(0, +) / count,
            warmth: dims.map(\.warmth).reduce(0, +) / count,
            expressiveness: dims.map(\.expressiveness).reduce(0, +) / count,
            tempo: dims.map(\.tempo).reduce(0, +) / count
        )
    }

    private func dominantMood(_ entries: [JournalEntry]) -> String {
        entries
            .compactMap { $0.moodLabel ?? $0.mood }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
            .max(by: { $0.value < $1.value })?.key ?? "ruhig"
    }

    private func significantChanges(before: VoiceDimensions, after: VoiceDimensions) -> String {
        var changes: [String] = []
        let tensionDiff = before.tension - after.tension
        let warmthDiff = after.warmth - before.warmth
        let energyDiff = after.energy - before.energy
        if tensionDiff > 0.08 { changes.append(isGerman ? "Anspannung ↓" : "Tension ↓") }
        if warmthDiff > 0.08 { changes.append(isGerman ? "Wärme ↑" : "Warmth ↑") }
        if energyDiff > 0.08 { changes.append(isGerman ? "Energie ↑" : "Energy ↑") }
        if tensionDiff < -0.08 { changes.append(isGerman ? "Anspannung ↑" : "Tension ↑") }
        return changes.prefix(2).joined(separator: "\n")
    }
}

private struct MiniEvolutionBlob: View {
    let dims: VoiceDimensions
    let mood: String
    let size: CGFloat
    @State private var phase: CGFloat = 0

    private var primaryColor: Color { KlunaWarm.moodColor(for: mood, fallbackQuadrant: .zufrieden) }
    private var distortion: CGFloat { dims.tension * 8 }

    var body: some View {
        ZStack {
            BlobShape(phase: phase, distortion: distortion)
                .fill(
                    RadialGradient(
                        colors: [primaryColor.opacity(0.5), primaryColor],
                        center: .init(x: 0.35, y: 0.35),
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size, height: size)

            BlobShape(phase: phase + 1, distortion: distortion * 0.3)
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.2), Color.clear],
                        center: .init(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.25
                    )
                )
                .frame(width: size * 0.7, height: size * 0.6)
        }
        .onAppear {
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

private struct ProfileHeroSectionV3: View {
    let dims: VoiceDimensions
    let mood: String
    let userName: String
    let voiceType: GeneratedVoiceType?
    let memberSince: Date?
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        VStack(spacing: 12) {
            ProfileBlobAvatar(dims: dims, mood: mood)
            Text(userName.isEmpty ? "Kluna" : userName)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229"))

            if let voiceType {
                Button {
                    let payload = VoiceTypeShareData(
                        typeName: isGerman ? voiceType.name : voiceType.nameEN,
                        typeDescription: isGerman ? voiceType.description : voiceType.descriptionEN,
                        dimensions: dims,
                        userName: userName.isEmpty ? (isGerman ? "du" : "you") : userName,
                        signatureShape: .fromDimensions(dims),
                        dominantColor: voiceType.color
                    )
                    KlunaAnalytics.shared.track("share_triggered", value: "voiceType_profile")
                    ShareABManager.shared.trackTap(.voiceType)
                    ShareImageGenerator.share(content: .voiceType(payload))
                } label: {
                    HStack(spacing: 10) {
                        Text(voiceType.emoji)
                            .font(.system(size: 24))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isGerman ? voiceType.name : voiceType.nameEN)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(voiceType.color)
                            Text(isGerman ? voiceType.description : voiceType.descriptionEN)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.3))
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(voiceType.color.opacity(0.3))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(voiceType.color.opacity(0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(voiceType.color.opacity(0.08), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .onAppear { ShareABManager.shared.trackShown(.voiceType) }
            }

            if let memberSince {
                Text(isGerman ? "Dabei seit \(memberSince.formatted(.dateTime.day().month(.wide)))" : "Member since \(memberSince.formatted(.dateTime.day().month(.wide)))")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.16))
            }
        }
    }
}

private struct StatsRowSectionV3: View {
    let streak: Int
    let klunaScore: Int
    let activeDays: Int
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        HStack(spacing: 0) {
            StatItemV3(icon: "flame.fill", iconColor: Color(hex: "#E8825C"), value: "\(streak)", label: "Streak")
            StatDividerV3()
            StatItemV3(icon: "sparkles", iconColor: Color(hex: "#F5B731"), value: "\(klunaScore)%", label: "Kluna Score")
            StatDividerV3()
            StatItemV3(icon: "calendar", iconColor: Color(hex: "#6BC5A0"), value: "\(activeDays)", label: isGerman ? "Aktive Tage" : "Active Days")
        }
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }
}

private struct StatItemV3: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(iconColor.opacity(0.5))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229"))
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.2))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatDividerV3: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "#3D3229").opacity(0.04))
            .frame(width: 1, height: 40)
    }
}

private struct JourneySectionV3: View {
    let entries: Int
    let minutesSpoken: Int
    let longestStreak: Int
    let topMood: String
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isGerman ? "Deine Reise" : "Your Journey")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229"))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                JourneyTileV3(value: "\(entries)", label: isGerman ? "Einträge" : "Entries", icon: "book.fill", color: Color(hex: "#E8825C"))
                JourneyTileV3(value: "\(minutesSpoken)", label: isGerman ? "Minuten gesprochen" : "Minutes spoken", icon: "waveform", color: Color(hex: "#6BC5A0"))
                JourneyTileV3(value: "\(longestStreak)", label: isGerman ? "Längster Streak" : "Longest Streak", icon: "flame.fill", color: Color(hex: "#F5B731"))
                JourneyTileV3(
                    value: moodEmojiV3(topMood),
                    label: isGerman ? "Häufigstes Gefühl" : "Most common mood",
                    subtitle: localizedMoodV3(topMood),
                    icon: nil,
                    color: KlunaWarm.moodColor(for: topMood, fallbackQuadrant: .zufrieden)
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }

    private func moodEmojiV3(_ mood: String) -> String {
        let m = mood.lowercased()
        if m.contains("begeistert") || m.contains("aufgekratzt") { return "😄" }
        if m.contains("ruhig") || m.contains("zufrieden") { return "😌" }
        if m.contains("nachdenklich") { return "🤔" }
        if m.contains("angespannt") || m.contains("aufgewühlt") { return "😬" }
        if m.contains("frustriert") { return "😤" }
        if m.contains("erschöpft") { return "😮‍💨" }
        if m.contains("verletzlich") { return "🥺" }
        return "🙂"
    }

    private func localizedMoodV3(_ mood: String) -> String {
        let resolved = MoodCategory.resolve(mood)?.rawValue ?? mood.lowercased()
        if isGerman {
            switch resolved {
            case "begeistert": return "Begeistert"
            case "aufgekratzt": return "Aufgekratzt"
            case "aufgewühlt": return "Aufgewühlt"
            case "angespannt": return "Angespannt"
            case "frustriert": return "Frustriert"
            case "erschöpft": return "Erschöpft"
            case "verletzlich": return "Verletzlich"
            case "ruhig": return "Ruhig"
            case "zufrieden": return "Zufrieden"
            case "nachdenklich": return "Nachdenklich"
            default: return mood.capitalized
            }
        }
        switch resolved {
        case "begeistert": return "Excited"
        case "aufgekratzt": return "Energized"
        case "aufgewühlt", "aufgewuehlt": return "Stirred Up"
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

private struct JourneyTileV3: View {
    let value: String
    let label: String
    var subtitle: String? = nil
    let icon: String?
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color.opacity(0.45))
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229"))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(color.opacity(0.55))
            }
            Text(label)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.2))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 16).fill(color.opacity(0.03)))
    }
}

private struct BadgesSectionV3: View {
    let badges: [Badge]
    let stats: KlunaStats
    @State private var showAllBadges = false
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }
    private var unlocked: [Badge] { badges.filter(\.isUnlocked) }
    private var nextBadge: Badge? { badges.first(where: { !$0.isUnlocked }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isGerman ? "Meilensteine" : "Milestones")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229"))
                Spacer()
                Text("\(unlocked.count)/\(badges.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#E8825C").opacity(0.35))
            }

            HStack(spacing: 12) {
                ForEach(Array(unlocked.suffix(3)), id: \.id) { badge in
                    MiniBadgeV3(badge: badge, isUnlocked: true)
                }
                if let nextBadge {
                    MiniBadgeV3(badge: nextBadge, isUnlocked: false)
                }
                Spacer()
            }

            Button(action: { showAllBadges = true }) {
                HStack(spacing: 6) {
                    Text(isGerman ? "Alle Meilensteine" : "All milestones")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#E8825C").opacity(0.45))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
        )
        .sheet(isPresented: $showAllBadges) {
            AllBadgesView(badges: badges, stats: stats)
        }
    }
}

private struct MiniBadgeV3: View {
    let badge: Badge
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? badge.category.color.opacity(0.1) : Color(hex: "#3D3229").opacity(0.03))
                    .frame(width: 52, height: 52)
                Text(badge.emoji)
                    .font(.system(size: 24))
                    .opacity(isUnlocked ? 1.0 : 0.15)
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.1))
                }
            }
            Text(badge.title)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(isUnlocked ? Color(hex: "#3D3229").opacity(0.5) : Color(hex: "#3D3229").opacity(0.12))
                .lineLimit(1)
        }
    }
}

private struct HowKlunaWorksSectionV3: View {
    @State private var expanded = false
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { expanded.toggle() } }) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#E8825C").opacity(0.4))
                    Text(isGerman ? "So funktioniert Kluna" : "How Kluna works")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229"))
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.15))
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 16)

                    GuideSectionV3(
                        icon: "mic.fill",
                        color: Color(hex: "#E8825C"),
                        title: isGerman ? "Sprechen" : "Speak",
                        items: isGerman ? [
                            "Tippe den Aufnahme-Button und sprich 20 Sekunden",
                            "Erzähl was dich gerade bewegt - oder einfach wie dein Tag war",
                            "Es gibt kein Richtig oder Falsch",
                            "Kluna hört nicht nur was du sagst, sondern wie du klingst",
                            "Du kannst auch Kluna Fragen stellen - sie beantwortet sie"
                        ] : [
                            "Tap the record button and speak for 20 seconds",
                            "Talk about what's on your mind - or just how your day was",
                            "There's no right or wrong",
                            "Kluna hears not just what you say, but how you sound",
                            "You can also ask Kluna questions - she'll answer them"
                        ]
                    )

                    GuideSectionV3(
                        icon: "rectangle.portrait.fill",
                        color: Color(hex: "#F5B731"),
                        title: isGerman ? "Deine Karten" : "Your Cards",
                        items: isGerman ? [
                            "Nach jedem Eintrag bekommst du eine Karte",
                            "Die Farbe und das Muster zeigen wie du geklungen hast",
                            "Tippe auf die verdeckte Karte um sie zu enthüllen",
                            "Seltenheit: Normal, Besonders, Selten, Legendär",
                            "Drehe die Karte um für deine Stimmdaten",
                            "Im 'Ich' Tab findest du alle deine Karten"
                        ] : [
                            "After each entry you get a card",
                            "The color and pattern show how you sounded",
                            "Tap the hidden card to reveal it",
                            "Rarity: Common, Uncommon, Rare, Legendary",
                            "Flip the card for your voice data",
                            "Find all your cards in the 'Me' tab"
                        ]
                    )

                    GuideSectionV3(
                        icon: "bubble.left.and.bubble.right.fill",
                        color: Color(hex: "#6BC5A0"),
                        title: isGerman ? "Gespräche" : "Conversations",
                        items: isGerman ? [
                            "Nach Klunas Antwort kannst du auf 'Antworten' tippen",
                            "Kluna stellt dir eine Frage und hört wie sich deine Stimme verändert",
                            "Jede Runde geht tiefer",
                            "Du kannst jederzeit 'Fertig' tippen",
                            "Zieh auf dem Homescreen nach unten für eine neue Frage"
                        ] : [
                            "After Kluna's response you can tap 'Respond'",
                            "Kluna asks you a question and hears how your voice changes",
                            "Each round goes deeper",
                            "You can tap 'Done' at any time",
                            "Pull down on the home screen for a new question"
                        ]
                    )

                    GuideSectionV3(
                        icon: "brain.head.profile",
                        color: Color(hex: "#B088A8"),
                        title: isGerman ? "Kluna lernt dich kennen" : "Kluna gets to know you",
                        items: isGerman ? [
                            "Ab dem ersten Eintrag merkt sich Kluna deine Themen",
                            "Nach 5 Einträgen kennt Kluna deine Muster",
                            "Nach 10 Einträgen weiß Kluna wer du bist",
                            "Kluna vergleicht immer mit DEINEM persönlichen Normal",
                            "Je mehr du sprichst, desto besser wird Kluna"
                        ] : [
                            "From the first entry Kluna remembers your themes",
                            "After 5 entries Kluna knows your patterns",
                            "After 10 entries Kluna knows who you are",
                            "Kluna always compares with YOUR personal baseline",
                            "The more you speak, the better Kluna gets"
                        ]
                    )

                    GuideSectionV3(
                        icon: "lock.fill",
                        color: Color(hex: "#7BA7C4"),
                        title: isGerman ? "Deine Privatsphäre" : "Your Privacy",
                        items: isGerman ? [
                            "Deine Stimme wird auf deinem Gerät analysiert",
                            "Kein Audio wird ins Internet gesendet",
                            "Wenn du Stimmdaten spendest: nur 26 anonyme Zahlen, kein Audio, kein Text",
                            "Du kannst jederzeit alle Daten löschen"
                        ] : [
                            "Your voice is analyzed on your device",
                            "No audio is sent to the internet",
                            "If you donate voice data: only 26 anonymous numbers, no audio, no text",
                            "You can delete all data at any time"
                        ]
                    )

                    GuideSectionV3(
                        icon: "lightbulb.fill",
                        color: Color(hex: "#F5B731"),
                        title: isGerman ? "Tipps" : "Tips",
                        items: isGerman ? [
                            "Sprich mehrmals am Tag für eine reichere Tageskarte",
                            "7 Tage am Stück = eine besondere Wochenkarte",
                            "Frag Kluna 'Wie war meine Woche?' für einen Rückblick",
                            "Frag 'Was hörst du in meiner Stimme?' wenn du neugierig bist",
                            "Teile deinen Stimm-Typ mit Freunden"
                        ] : [
                            "Speak multiple times a day for a richer daily card",
                            "7 days in a row = a special weekly card",
                            "Ask Kluna 'How was my week?' for a review",
                            "Ask 'What do you hear in my voice?' when you're curious",
                            "Share your voice type with friends"
                        ]
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }
}

private struct GuideSectionV3: View {
    let icon: String
    let color: Color
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color.opacity(0.5))
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229"))
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)

                        Text(item)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color(hex: "#3D3229").opacity(0.4))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 24)
        }
    }
}

private struct DonationSectionV3: View {
    @Binding var isDonating: Bool
    @State private var showDetails = false
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("🧬").font(.system(size: 14))
                        Text(isGerman ? "Stimmdaten spenden" : "Donate voice data")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#3D3229"))
                    }
                    Text(isGerman ? "Hilf der Forschung - 100% anonym" : "Help research - 100% anonymous")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.25))
                }
                Spacer()
                Toggle("", isOn: $isDonating)
                    .labelsHidden()
                    .tint(Color(hex: "#6BC5A0"))
            }

            VStack(alignment: .leading, spacing: 8) {
                DonationInfoRowV3(icon: "checkmark.circle.fill", color: Color(hex: "#6BC5A0"), text: isGerman ? "26 anonyme Stimmwerte (Tonhöhe, Tempo, Pausen, etc.)" : "26 anonymous voice values (pitch, tempo, pauses, etc.)")
                DonationInfoRowV3(icon: "checkmark.circle.fill", color: Color(hex: "#6BC5A0"), text: isGerman ? "6 Dimensionen (Energie, Anspannung, Wärme, etc.)" : "6 dimensions (energy, tension, warmth, etc.)")
                DonationInfoRowV3(icon: "checkmark.circle.fill", color: Color(hex: "#6BC5A0"), text: isGerman ? "Stimmung, Altersgruppe, Geschlecht" : "Mood, age group, gender")
                DonationInfoRowV3(icon: "xmark.circle.fill", color: Color(hex: "#E85C5C").opacity(0.45), text: isGerman ? "Kein Audio, kein Text, kein Name" : "No audio, no text, no name")
                DonationInfoRowV3(icon: "xmark.circle.fill", color: Color(hex: "#E85C5C").opacity(0.45), text: isGerman ? "Kein Rückschluss auf dich möglich" : "No way to identify you")
            }

            Button(action: { withAnimation(.spring(response: 0.3)) { showDetails.toggle() } }) {
                HStack(spacing: 4) {
                    Text(isGerman ? "Alle 26 Werte anzeigen" : "Show all 26 values")
                        .font(.system(size: 12, design: .rounded))
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundColor(Color(hex: "#6BC5A0").opacity(0.45))
            }

            if showDetails {
                VStack(alignment: .leading, spacing: 4) {
                    DetailTextV3("Tonhöhe (F0), Variation, Bereich")
                    DetailTextV3("Jitter, Shimmer, HNR")
                    DetailTextV3("Sprechgeschwindigkeit, Artikulation")
                    DetailTextV3("Pausenrate, Pausendauer")
                    DetailTextV3("Lautstärke, Dynamik")
                    DetailTextV3("Formanten (F1-F4)")
                    DetailTextV3("Spektralverteilung (4 Bänder)")
                    DetailTextV3("6 berechnete Dimensionen")
                    DetailTextV3("Z-Scores, Flags, Baseline-Status")
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: "#6BC5A0").opacity(0.03))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if isDonating {
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#F5B731"))
                    Text(isGerman ? "Community-Vergleiche freigeschaltet" : "Community comparisons unlocked")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(hex: "#6BC5A0").opacity(0.6))
                }
                .transition(.opacity)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
        )
        .onChange(of: isDonating) { value in
            UserDefaults.standard.set(value, forKey: "kluna_data_donation_enabled")
            KlunaAnalytics.shared.track(value ? "donation_enabled" : "donation_disabled")
        }
    }
}

private struct DonationInfoRowV3: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DetailTextV3: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color(hex: "#6BC5A0").opacity(0.2)).frame(width: 4, height: 4)
            Text(text)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.25))
        }
    }
}

private struct SettingsSectionV3: View {
    let onEditName: () -> Void
    let onReminders: () -> Void
    let onDelete: () -> Void
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        VStack(spacing: 0) {
            SettingsRowV3(icon: "person.fill", title: isGerman ? "Name ändern" : "Change name", action: onEditName)
            SettingsDividerV3()
            SettingsRowV3(icon: "bell.fill", title: isGerman ? "Erinnerungen" : "Reminders", action: onReminders)
            SettingsDividerV3()
            SettingsRowV3(icon: "lock.fill", title: isGerman ? "Datenschutz" : "Privacy") {
                if let url = URL(string: "https://kluna.app/privacy.html") {
                    UIApplication.shared.open(url)
                }
            }
            SettingsDividerV3()
            SettingsRowV3(icon: "trash.fill", title: isGerman ? "Alle Daten löschen" : "Delete all data", isDestructive: true, action: onDelete)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }
}

private struct SettingsRowV3: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(isDestructive ? Color(hex: "#E85C5C").opacity(0.5) : Color(hex: "#3D3229").opacity(0.2))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(isDestructive ? Color(hex: "#E85C5C").opacity(0.7) : Color(hex: "#3D3229").opacity(0.55))
                Spacer()
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.1))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
    }
}

private struct SettingsDividerV3: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "#3D3229").opacity(0.03))
            .frame(height: 1)
            .padding(.leading, 62)
    }
}

struct GlobalVoiceStats {
    let totalDonors: Int
    let totalDataPoints: Int
    let avgWarmth: CGFloat
    let avgStability: CGFloat
    let avgEnergy: CGFloat
    let avgTempo: CGFloat
    let avgOpenness: CGFloat
    let mostCommonMood: String
}

extension DailyCard: Identifiable {
    var id: String { "\(date.timeIntervalSince1970)-\(title)" }
}

private struct ProfileCardCollectionPreview: View {
    let cards: [DailyCard]
    let onShowAll: () -> Void
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(isGerman ? "Deine Sammlung" : "Your Collection")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229"))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#E8825C").opacity(0.3))
                    Text("\(cards.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#E8825C").opacity(0.3))
                }
            }

            if cards.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 28))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.18))
                    Text(isGerman ? "Noch keine Karten gesammelt" : "No cards collected yet")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.35))
                    Text(isGerman ? "Sprich heute mit Kluna, um deine erste Daily Card zu erhalten." : "Speak with Kluna today to get your first Daily Card.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.22))
                        .multilineTextAlignment(.center)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        NotificationCenter.default.post(name: .klunaOpenHomeTab, object: nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 11))
                            Text(isGerman ? "Heute aufnehmen" : "Record today")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "#E8825C").opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color(hex: "#E8825C").opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#3D3229").opacity(0.03))
                )
            } else {
                HStack(spacing: 12) {
                    ProfileRarityCount(rarity: .legendary, count: cards.filter { $0.rarity == .legendary }.count)
                    ProfileRarityCount(rarity: .rare, count: cards.filter { $0.rarity == .rare }.count)
                    ProfileRarityCount(rarity: .uncommon, count: cards.filter { $0.rarity == .uncommon }.count)
                    ProfileRarityCount(rarity: .common, count: cards.filter { $0.rarity == .common }.count)
                    Spacer()
                }

                ZStack {
                    ForEach(Array(cards.prefix(5).reversed().enumerated()), id: \.offset) { index, card in
                        ProfileMiniCardView(card: card)
                            .offset(x: CGFloat(index) * 12, y: CGFloat(index) * -4)
                            .rotationEffect(.degrees(Double(index - 2) * 2.5))
                    }
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            }

            Button(action: onShowAll) {
                HStack(spacing: 6) {
                    Text(isGerman ? "Alle Karten ansehen" : "View all cards")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#E8825C").opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#E8825C").opacity(0.04)))
            }
            .buttonStyle(.plain)
            .disabled(cards.isEmpty)
            .opacity(cards.isEmpty ? 0.45 : 1.0)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 10, x: 0, y: 5)
        )
    }
}

private struct ProfileRarityCount: View {
    let rarity: CardRarity
    let count: Int

    var body: some View {
        if count > 0 {
            HStack(spacing: 4) {
                Circle().fill(rarity.color).frame(width: 8, height: 8)
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(rarity.color.opacity(0.7))
            }
        }
    }
}

private struct ProfileMiniCardView: View {
    let card: DailyCard

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: card.atmosphereColors, startPoint: .topLeading, endPoint: .bottomTrailing))

            if let features = card.rawFeatures {
                MiniPatternView(features: features, color: .white)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 4) {
                Spacer()
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [card.primaryColor.opacity(0.6), card.primaryColor],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 12
                        )
                    )
                    .frame(width: 24, height: 24)
                Text(card.title.replacingOccurrences(of: "⭐ ", with: ""))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(card.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                Spacer().frame(height: 8)
            }

            if card.rarity != .common {
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(card.rarity.color)
                            .frame(width: 6, height: 6)
                            .shadow(color: card.rarity.color.opacity(0.5), radius: 3)
                            .padding(8)
                    }
                    Spacer()
                }
            }
        }
        .frame(width: 130, height: 170)
        .shadow(color: card.primaryColor.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

private struct MiniPatternView: View {
    let features: DailyCard.RawFeatures
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .stroke(
                            color.opacity(0.025 + Double(i) * 0.01),
                            lineWidth: 0.8 + CGFloat(features.shimmer) * 1.2
                        )
                        .frame(
                            width: 22 + CGFloat(i) * 18 + CGFloat(features.f0Range) * 0.5,
                            height: 22 + CGFloat(i) * 18 + CGFloat(features.f0Range) * 0.5
                        )
                }

                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) / 12.0 * .pi * 2.0 + Double(features.jitter) * 30.0
                    let radius = min(width, height) * (0.18 + Double(features.pauseDur) * 0.1)
                    Circle()
                        .fill(color.opacity(0.05 + Double(features.shimmer) * 0.12))
                        .frame(width: 2.8, height: 2.8)
                        .offset(
                            x: cos(angle) * radius,
                            y: sin(angle) * radius
                        )
                }
            }
            .frame(width: width, height: height)
        }
    }
}

private struct ProfileCardCollectionFullView: View {
    let cards: [DailyCard]
    @State private var filter: CollectionFilter = .all
    @State private var selectedCard: DailyCard?
    @State private var viewMode: ViewMode = .grid
    @State private var sortOrder: SortOrder = .newestFirst
    @Environment(\.dismiss) private var dismiss
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    private enum ViewMode { case grid, timeline }
    private enum SortOrder { case newestFirst, oldestFirst }
    private enum CollectionFilter: Equatable {
        case all
        case weekly
        case rarity(CardRarity)
    }

    private var filteredCards: [DailyCard] {
        switch filter {
        case .all:
            return cards
        case .weekly:
            return cards.filter(\.isWeekly)
        case .rarity(let rarity):
            return cards.filter { !$0.isWeekly && $0.rarity == rarity }
        }
    }

    private var visibleCards: [DailyCard] {
        let sorted = filteredCards.sorted(by: { $0.date > $1.date })
        return sortOrder == .newestFirst ? sorted : sorted.reversed()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#FFF8F0").ignoresSafeArea()
                VStack(spacing: 0) {
                    ProfileCollectionStatsHeader(cards: cards)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    HStack(spacing: 12) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ProfileFilterChip(
                                    label: isGerman ? "Alle" : "All",
                                    count: cards.count,
                                    isSelected: filter == .all,
                                    color: Color(hex: "#E8825C")
                                ) { filter = .all }

                                if cards.contains(where: \.isWeekly) {
                                    ProfileFilterChip(
                                        label: isGerman ? "Woche" : "Weekly",
                                        count: cards.filter(\.isWeekly).count,
                                        isSelected: filter == .weekly,
                                        color: Color(hex: "#F5B731")
                                    ) { filter = .weekly }
                                }

                                if cards.contains(where: { $0.rarity == .legendary }) {
                                    ProfileFilterChip(
                                        label: CardRarity.legendary.label,
                                        count: cards.filter { $0.rarity == .legendary }.count,
                                        isSelected: filter == .rarity(.legendary),
                                        color: CardRarity.legendary.color
                                    ) { filter = .rarity(.legendary) }
                                }
                                if cards.contains(where: { $0.rarity == .rare }) {
                                    ProfileFilterChip(
                                        label: CardRarity.rare.label,
                                        count: cards.filter { $0.rarity == .rare }.count,
                                        isSelected: filter == .rarity(.rare),
                                        color: CardRarity.rare.color
                                    ) { filter = .rarity(.rare) }
                                }
                                if cards.contains(where: { $0.rarity == .uncommon }) {
                                    ProfileFilterChip(
                                        label: CardRarity.uncommon.label,
                                        count: cards.filter { $0.rarity == .uncommon }.count,
                                        isSelected: filter == .rarity(.uncommon),
                                        color: CardRarity.uncommon.color
                                    ) { filter = .rarity(.uncommon) }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sortOrder = sortOrder == .newestFirst ? .oldestFirst : .newestFirst
                            }
                        } label: {
                            Image(systemName: sortOrder == .newestFirst ? "arrow.down" : "arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.3))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color(hex: "#3D3229").opacity(0.04)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewMode = viewMode == .grid ? .timeline : .grid
                            }
                        } label: {
                            Image(systemName: viewMode == .grid ? "square.grid.2x2" : "list.bullet")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.3))
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color(hex: "#3D3229").opacity(0.04)))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    HStack {
                        Text(
                            isGerman
                            ? (sortOrder == .newestFirst ? "Sortierung: Neueste zuerst" : "Sortierung: Älteste zuerst")
                            : (sortOrder == .newestFirst ? "Sorting: Newest first" : "Sorting: Oldest first")
                        )
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229").opacity(0.20))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    if visibleCards.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "rectangle.stack.badge.person.crop")
                                .font(.system(size: 34))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.18))
                            Text(isGerman ? "Keine Karten für diesen Filter" : "No cards for this filter")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.35))
                            Text(isGerman ? "Wähle einen anderen Filter oder ändere die Sortierung." : "Choose another filter or change sorting.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(Color(hex: "#3D3229").opacity(0.22))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewMode == .grid {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                                spacing: 14
                            ) {
                                ForEach(Array(visibleCards.enumerated()), id: \.element.id) { index, card in
                                    Button { selectedCard = card } label: {
                                        ProfileMiniCardView(card: card)
                                            .modifier(ProfileAppearModifier(index: index))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(Array(visibleCards.enumerated()), id: \.element.id) { index, card in
                                    Button { selectedCard = card } label: {
                                        ProfileTimelineCardRow(card: card)
                                            .modifier(ProfileAppearModifier(index: index))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle(isGerman ? "Deine Sammlung" : "Your Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#3D3229").opacity(0.3))
                    }
                }
            }
            .sheet(item: $selectedCard) { card in
                ZStack {
                    Color(hex: "#1A1A2E").ignoresSafeArea()
                    VStack {
                        Spacer()
                        DailyCardView(card: card)
                        Spacer()
                        Button(isGerman ? "Schließen" : "Close") {
                            selectedCard = nil
                        }
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

private struct ProfileCollectionStatsHeader: View {
    let cards: [DailyCard]
    private var isGerman: Bool { (Locale.current.language.languageCode?.identifier ?? "de") == "de" }

    var body: some View {
        HStack(spacing: 0) {
            ProfileCollectionStat(value: "\(cards.count)", label: isGerman ? "Karten" : "Cards", icon: "square.stack.fill", color: Color(hex: "#E8825C"))
            ProfileCollectionStat(value: "\(cards.filter { $0.rarity == .legendary }.count)", label: isGerman ? "Legendär" : "Legendary", icon: "star.fill", color: Color(hex: "#F5B731"))
            ProfileCollectionStat(value: "\(cards.filter { $0.rarity == .rare }.count)", label: isGerman ? "Selten" : "Rare", icon: "sparkles", color: Color(hex: "#7BA7C4"))
            ProfileCollectionStat(value: longestStreakInCards(), label: "Streak", icon: "flame.fill", color: Color(hex: "#E85C5C"))
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }

    private func longestStreakInCards() -> String {
        var streak = 0
        var maxStreak = 0
        let sortedDates = cards.map { Calendar.current.startOfDay(for: $0.date) }.sorted(by: >)
        var previousDate: Date?

        for date in sortedDates {
            if let previousDate {
                let dayDiff = Calendar.current.dateComponents([.day], from: date, to: previousDate).day ?? 0
                if dayDiff == 1 {
                    streak += 1
                    maxStreak = max(maxStreak, streak)
                } else {
                    streak = 1
                }
            } else {
                streak = 1
            }
            previousDate = date
        }
        return "\(max(maxStreak, streak))"
    }
}

private struct ProfileCollectionStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(0.4))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229"))
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Color(hex: "#3D3229").opacity(0.2))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileFilterChip: View {
    let label: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Circle().fill(color).frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .opacity(0.5)
            }
            .foregroundColor(isSelected ? color : Color(hex: "#3D3229").opacity(0.3))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.08) : Color(hex: "#3D3229").opacity(0.03))
                    .overlay(Capsule().stroke(isSelected ? color.opacity(0.15) : .clear, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileTimelineCardRow: View {
    let card: DailyCard

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(card.primaryColor.opacity(0.08)).frame(width: 44, height: 44)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [card.primaryColor.opacity(0.5), card.primaryColor],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 14
                        )
                    )
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(card.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#3D3229"))
                    Spacer()
                    if card.rarity != .common { RarityBadge(rarity: card.rarity) }
                }
                Text(card.sentence)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.3))
                    .lineLimit(2)
                Text(card.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(Color(hex: "#3D3229").opacity(0.12))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color(hex: "#3D3229").opacity(0.03), radius: 6, x: 0, y: 3)
        )
    }
}

private struct ProfileAppearModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear { appeared = true }
            .animation(
                .easeOut(duration: 0.26).delay(min(0.22, Double(index) * 0.018)),
                value: appeared
            )
    }
}

enum SettingsAction {
    case premium
    case editName
    case export
    case exportAppIcon
    case notifications
    case privacy
    case deleteAll
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

