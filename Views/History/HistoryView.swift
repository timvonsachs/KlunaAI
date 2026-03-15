import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    private let memoryManager = MemoryManager(context: PersistenceController.shared.container.viewContext)
    private let journalManager = JournalManager(context: PersistenceController.shared.container.viewContext)

    @State private var range: TimeRange = .month
    @State private var selectedDimension: PerformanceDimension?
    @State private var history: [DailyScoreSummary] = []
    @State private var sessions: [SessionSummary] = []
    @State private var userLanguage = "de"

    var body: some View {
        ScrollView {
            VStack(spacing: KlunaSpacing.md) {
                Text(L10n.history)
                    .font(KlunaFont.heading(28))
                    .foregroundColor(.klunaPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                pickerRow

                Group {
                    PremiumLineChart(
                        dataPoints: chartPoints,
                        emptyText: userLanguage == "de" ? "Noch ein paar Sessions fuer den Chart." : "A few more sessions are needed for the chart."
                    )

                    Text(L10n.dimensions)
                        .font(KlunaFont.heading(15))
                        .foregroundColor(.klunaPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    DimensionFilterRow(selectedDimension: $selectedDimension, language: userLanguage)

                    if let current = memoryManager.averageScores(weekOffset: 0) {
                        PremiumRadarChart(current: current, previous: memoryManager.averageScores(weekOffset: -4))
                    }

                    let voiceProfile = journalManager.weeklyVoiceProfile(weeks: 4)
                    if !voiceProfile.isEmpty {
                        VoiceProfileChart(snapshots: voiceProfile, language: userLanguage)
                    }

                    if memoryManager.totalSessionCount() >= 5,
                       let weekAvg = memoryManager.averageScores(lastDays: 7),
                       let best = memoryManager.personalBestSession(),
                       let bestDate = best.dateAsDate {
                        PersonalBestCard(
                            currentScores: weekAvg,
                            bestScores: best.scores,
                            bestDate: bestDate,
                            bestPitchType: best.pitchType,
                            language: userLanguage
                        )
                    }

                    SessionListView(sessions: sessions)
                }
                .modifier(ProOnlyModifier(isPro: subscriptionManager.hasFullHistory))
            }
            .padding(.horizontal, KlunaSpacing.md)
            .padding(.vertical, KlunaSpacing.md)
        }
        .background(Color.klunaBackground.ignoresSafeArea())
        .onAppear(perform: reload)
        .onChange(of: range) { _ in reload() }
    }

    private var pickerRow: some View {
        HStack(spacing: KlunaSpacing.sm) {
            ForEach(TimeRange.allCases, id: \.self) { item in
                Text(item.rawValue)
                    .font(KlunaFont.caption(12))
                    .foregroundColor(range == item ? .white : .klunaSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(range == item ? Color.klunaAccent : Color.klunaSurface)
                    .cornerRadius(KlunaRadius.pill)
                    .overlay(
                        RoundedRectangle(cornerRadius: KlunaRadius.pill)
                            .stroke(range == item ? Color.clear : Color.klunaBorder, lineWidth: 1)
                    )
                    .onTapGesture {
                        withAnimation(KlunaAnimation.springFast) {
                            range = item
                        }
                    }
            }
            Spacer()
        }
    }

    private var chartPoints: [(date: Date, score: Double)] {
        let points: [(date: Date, score: Double)] = history.map { item in
            let score: Double
            switch selectedDimension {
            case .confidence: score = item.averageConfidence
            case .energy: score = item.averageEnergy
            case .tempo: score = item.averageTempo
            case .clarity: score = item.averageClarity
            case .stability: score = item.averageStability
            case .charisma: score = item.averageCharisma
            case nil: score = item.averageOverall
            }
            return (item.date, score)
        }

        if points.count > 1 {
            return points
        }

        // Fallback for many sessions on one day: show session-based line instead of empty chart.
        let fallback = sessions.reversed().compactMap { summary -> (Date, Double)? in
            guard let date = summary.dateAsDate else { return nil }
            let score: Double
            switch selectedDimension {
            case .confidence: score = summary.scores.confidence
            case .energy: score = summary.scores.energy
            case .tempo: score = summary.scores.tempo
            case .clarity: score = summary.scores.clarity
            case .stability: score = summary.scores.stability
            case .charisma: score = summary.scores.charisma
            case nil: score = summary.overallScore
            }
            return (date, score)
        }
        return fallback
    }

    private func reload() {
        history = memoryManager.scoreHistory(lastDays: range.days)
        sessions = memoryManager.recentSessions(count: max(12, range.days))
        userLanguage = memoryManager.loadUser().language
    }
}

struct DimensionFilterRow: View {
    @Binding var selectedDimension: PerformanceDimension?
    let language: String

    private let colors: [PerformanceDimension: Color] = [
        .confidence: .klunaGreen,
        .energy: .klunaOrange,
        .tempo: .klunaAmber,
        .stability: Color(hex: "96CEB4"),
        .charisma: .klunaAccent,
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KlunaSpacing.sm) {
                FilterChip(
                    label: language == "de" ? "Gesamt" : "Overall",
                    isSelected: selectedDimension == nil,
                    color: .klunaPrimary
                ) {
                    selectedDimension = nil
                }
                ForEach(PerformanceDimension.activeDimensions, id: \.self) { dim in
                    FilterChip(
                        label: dim.shortName(language: language),
                        isSelected: selectedDimension == dim,
                        color: colors[dim] ?? .klunaAccent
                    ) {
                        withAnimation(KlunaAnimation.springFast) {
                            selectedDimension = dim
                        }
                    }
                }
            }
        }
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(KlunaFont.caption(13))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, KlunaSpacing.md)
                .padding(.vertical, KlunaSpacing.sm)
                .background(isSelected ? color : color.opacity(0.12))
                .cornerRadius(KlunaRadius.pill)
        }
        .buttonStyle(.plain)
    }
}

struct ProOnlyModifier: ViewModifier {
    let isPro: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isPro {
            content
        } else {
            content
                .blur(radius: 6)
                .overlay {
                    VStack(spacing: KlunaSpacing.sm) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.klunaAccent)
                        Text(L10n.proFeature)
                            .font(KlunaFont.heading(16))
                            .foregroundColor(.klunaPrimary)
                        Text(L10n.upgrade)
                            .font(KlunaFont.caption(12))
                            .foregroundColor(.klunaMuted)
                    }
                }
        }
    }
}

