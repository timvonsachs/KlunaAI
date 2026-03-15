import SwiftUI
import CoreData
import AVFoundation

struct JournalCalendarView: View {
    @ObservedObject private var dataManager = KlunaDataManager.shared
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("Kalender")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(KlunaWarm.warmBrown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        MonthNavigation(currentMonth: $currentMonth)
                            .padding(.top, 16)

                        CompactMoodGrid(
                            month: currentMonth,
                            entries: monthEntries,
                            selectedDate: $selectedDate
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                        Rectangle()
                            .fill(KlunaWarm.warmBrown.opacity(0.06))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        EmotionTimeline(
                            month: currentMonth,
                            entries: monthEntries
                        )
                        .padding(.top, 16)
                    }
                    .padding(.bottom, 100)
                }
                .background(KlunaWarm.background.ignoresSafeArea())
                .refreshable {
                    await refreshCalendarData()
                }
                .onChange(of: selectedDate) { _, date in
                    if let date {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                            proxy.scrollTo(Calendar.current.startOfDay(for: date), anchor: .top)
                        }
                    }
                }
            }
            .onAppear(perform: reload)
        }
    }

    private var monthEntries: [JournalEntry] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: currentMonth) else { return [] }
        return dataManager.entries.filter { monthInterval.contains($0.date) }
    }

    private func reload() {
        dataManager.refresh(limit: 500)
    }

    private func refreshCalendarData() async {
        reload()
    }
}

struct MonthNavigation: View {
    @Binding var currentMonth: Date

    var body: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(KlunaWarm.warmBrown.opacity(0.05)))
            }

            Spacer()

            Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)

            Spacer()

            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.4))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(KlunaWarm.warmBrown.opacity(0.05)))
            }
        }
        .padding(.horizontal, 20)
    }

    private func changeMonth(_ delta: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        currentMonth = Calendar.current.date(byAdding: .month, value: delta, to: currentMonth) ?? currentMonth
    }
}

struct CompactMoodGrid: View {
    let month: Date
    let entries: [JournalEntry]
    @Binding var selectedDate: Date?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(["M", "D", "M", "D", "F", "S", "S"].enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 8) {
                ForEach(daysInMonth(), id: \.self) { date in
                    CompactDayDot(
                        date: date,
                        entry: bestEntryForDate(date),
                        isToday: Calendar.current.isDateInToday(date),
                        isSelected: isSelected(date),
                        appeared: appeared,
                        index: dayIndex(for: date),
                        entriesCount: entriesCountForDate(date)
                    )
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedDate = Calendar.current.startOfDay(for: date)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(KlunaWarm.cardBackground)
                .shadow(color: KlunaWarm.warmBrown.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        guard let selectedDate else { return false }
        return Calendar.current.isDate(selectedDate, inSameDayAs: date)
    }

    private func daysInMonth() -> [Date] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: month) else { return [] }
        let start = interval.start
        let days = Calendar.current.range(of: .day, in: .month, for: start) ?? 1..<2
        return days.compactMap { day in
            Calendar.current.date(byAdding: .day, value: day - 1, to: start)
        }
    }

    private func entriesCountForDate(_ date: Date) -> Int {
        entries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.count
    }

    private func bestEntryForDate(_ date: Date) -> JournalEntry? {
        entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted(by: { $0.date > $1.date })
            .first
    }

    private func dayIndex(for date: Date) -> Int {
        Calendar.current.component(.day, from: date)
    }
}

struct CompactDayDot: View {
    let date: Date
    let entry: JournalEntry?
    let isToday: Bool
    let isSelected: Bool
    let appeared: Bool
    let index: Int
    let entriesCount: Int

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 10, weight: isToday ? .bold : .regular, design: .rounded))
                .foregroundStyle(
                    isToday ? KlunaWarm.warmAccent :
                        entry != nil ? KlunaWarm.warmBrown :
                        KlunaWarm.warmBrown.opacity(0.25)
                )

            ZStack {
                if let entry {
                    let mood = entry.stimmungsfarbe
                    Circle()
                        .fill(mood)
                        .frame(width: isSelected ? 22 : 18, height: isSelected ? 22 : 18)
                        .shadow(color: isSelected ? mood.opacity(0.4) : .clear, radius: 4)
                    if entriesCount > 1 {
                        Circle()
                            .fill(KlunaWarm.cardBackground.opacity(0.85))
                            .frame(width: 4, height: 4)
                    }
                } else {
                    Circle()
                        .fill(KlunaWarm.warmBrown.opacity(0.03))
                        .frame(width: 14, height: 14)
                }

                if isToday {
                    Circle()
                        .stroke(KlunaWarm.warmAccent, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.84), value: isSelected)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.6)
        .animation(.spring(response: 0.35).delay(Double(index) * 0.01), value: appeared)
    }
}

struct EmotionTimeline: View {
    let month: Date
    let entries: [JournalEntry]

    var body: some View {
        let grouped = groupEntriesByDay(entries)
        let sortedDays = grouped.keys.sorted(by: >)

        LazyVStack(spacing: 0) {
            ForEach(sortedDays, id: \.self) { day in
                let dayEntries = grouped[day] ?? []
                TimelineDayHeader(date: day, entryCount: dayEntries.count)
                    .id(day)

                let sorted = dayEntries.sorted(by: { $0.date > $1.date })
                ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, entry in
                    TimelineEntryNode(entry: entry, isLast: idx == sorted.count - 1)
                }

                if day != sortedDays.last {
                    TimelineConnector(
                        fromColor: KlunaWarm.color(for: sorted.last?.quadrant ?? .zufrieden),
                        toColor: nextDayColor(after: day, in: grouped, sortedDays: sortedDays)
                    )
                }
            }

            if sortedDays.isEmpty {
                EmptyTimelineView()
            }
        }
        .padding(.horizontal, 20)
    }

    private func groupEntriesByDay(_ entries: [JournalEntry]) -> [Date: [JournalEntry]] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.date) }
    }

    private func nextDayColor(
        after day: Date,
        in grouped: [Date: [JournalEntry]],
        sortedDays: [Date]
    ) -> Color {
        guard let idx = sortedDays.firstIndex(of: day), sortedDays.indices.contains(idx + 1) else {
            return KlunaWarm.warmBrown.opacity(0.1)
        }
        let next = sortedDays[idx + 1]
        let sample = grouped[next]?.first
        return KlunaWarm.color(for: sample?.quadrant ?? .zufrieden)
    }
}

struct TimelineDayHeader: View {
    let date: Date
    let entryCount: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Text(date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            }
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(KlunaWarm.cardBackground)
            )

            Rectangle()
                .fill(KlunaWarm.warmBrown.opacity(0.08))
                .frame(height: 1)

            if entryCount > 1 {
                Text("\(entryCount) Einträge")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

struct TimelineEntryNode: View {
    let entry: JournalEntry
    let isLast: Bool
    @State private var isExpanded = false
    @State private var appeared = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(entry.stimmungsfarbe.opacity(0.3))
                    .frame(width: 2, height: 12)
                ZStack {
                    Circle()
                        .fill(entry.stimmungsfarbe)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(entry.stimmungsfarbe.opacity(0.3))
                        .frame(width: 22, height: 22)
                }
                if !isLast || isExpanded {
                    Rectangle()
                        .fill(entry.stimmungsfarbe.opacity(0.15))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
                    Spacer()
                    Text(entry.moodLabel ?? entry.quadrant.label)
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(entry.stimmungsfarbe)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(entry.stimmungsfarbe.opacity(0.1))
                        )
                }

                Text(entry.transcript)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if isExpanded {
                    if let coach = entry.coachText, !coach.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                                .foregroundStyle(KlunaWarm.warmAccent)
                                .padding(.top, 2)
                            Text(coach)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(KlunaWarm.warmAccent.opacity(0.04))
                        )
                    }

                    HStack(spacing: 16) {
                        MiniBar(label: "Energie", value: CGFloat(entry.arousal / 100), color: KlunaWarm.warmAccent)
                        MiniBar(label: "Stimmung", value: CGFloat(entry.acousticValence / 100), color: entry.stimmungsfarbe)
                    }

                    if !entry.themes.isEmpty {
                        let uniqueThemes = Array(Set(entry.themes)).sorted()
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                            ForEach(uniqueThemes, id: \.self) { theme in
                                Text(theme)
                                    .font(.system(.caption2, design: .rounded))
                                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(KlunaWarm.warmBrown.opacity(0.04))
                                    )
                            }
                        }
                    }

                    if entry.audioRelativePath != nil {
                        AudioPlayerView(audioPath: entry.audioRelativePath)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(KlunaWarm.cardBackground)
                    .shadow(
                        color: KlunaWarm.warmBrown.opacity(isExpanded ? 0.08 : 0.04),
                        radius: isExpanded ? 12 : 6,
                        x: 0,
                        y: isExpanded ? 6 : 3
                    )
            )
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            }
        }
        .padding(.bottom, 8)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -20)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }
}

struct MiniBar: View {
    let label: String
    let value: CGFloat
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))

            Capsule()
                .fill(KlunaWarm.warmBrown.opacity(0.06))
                .frame(height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.6))
                        .frame(width: max(4, 80 * value), height: 4)
                }
                .frame(width: 80)
        }
    }
}

struct TimelineConnector: View {
    let fromColor: Color
    let toColor: Color

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [fromColor.opacity(0.2), toColor.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 2, height: 32)
            .frame(width: 44, alignment: .center)
            Spacer()
        }
    }
}

struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.15))
            Text("Noch keine Einträge diesen Monat")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
            Text("Sprich deinen ersten Eintrag ein")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct AudioPlayerView: View {
    let audioPath: String?
    @ObservedObject private var audioPlayer = KlunaAudioPlayer.shared

    var body: some View {
        if audioPath != nil {
            HStack(spacing: 12) {
                Button(action: togglePlayback) {
                    Image(systemName: isCurrentPath && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(KlunaWarm.warmAccent)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(KlunaWarm.warmAccent.opacity(0.1))
                        )
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(KlunaWarm.warmBrown.opacity(0.08))
                            .frame(height: 4)
                        Capsule()
                            .fill(KlunaWarm.warmAccent)
                            .frame(width: geo.size.width * currentProgress, height: 4)
                    }
                }
                .frame(height: 4)

                Text(currentDurationText)
                    .font(.system(.caption2, design: .rounded).monospacedDigit())
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.5))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(KlunaWarm.warmBrown.opacity(0.03))
            )
            .onDisappear {
                if isCurrentPath {
                    audioPlayer.stop()
                }
            }
        }
    }

    private func togglePlayback() {
        audioPlayer.togglePlayPause(audioPath: audioPath)
    }

    private var isCurrentPath: Bool {
        guard let audioPath else { return false }
        return audioPlayer.currentPath == audioPath
    }

    private var currentProgress: CGFloat {
        guard isCurrentPath else { return 0 }
        return CGFloat(audioPlayer.progress)
    }

    private var currentDurationText: String {
        guard isCurrentPath else { return "0:00" }
        return formatTime(Int(max(0, audioPlayer.remainingDuration)))
    }

    private func formatTime(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return "\(m):\(String(format: "%02d", s))"
    }
}

@MainActor
final class KlunaAudioPlayer: NSObject, ObservableObject {
    static let shared = KlunaAudioPlayer()

    @Published var isPlaying = false
    @Published var progress: Float = 0
    @Published var currentPath: String?
    @Published var remainingDuration: TimeInterval = 0

    private var avPlayer: AVAudioPlayer?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var timer: Timer?
    private var totalFrames: AVAudioFramePosition = 0

    func togglePlayPause(audioPath: String?) {
        guard let audioPath, !audioPath.isEmpty else {
            print("🔊 ❌ No audio path")
            return
        }
        if currentPath == audioPath {
            if let p = avPlayer {
                if p.isPlaying {
                    p.pause()
                    isPlaying = false
                } else {
                    try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                    p.play()
                    isPlaying = true
                    startProgressTimer()
                }
                return
            }
            if let node = playerNode {
                if node.isPlaying {
                    node.pause()
                    isPlaying = false
                } else {
                    try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                    node.play()
                    isPlaying = true
                    startProgressTimer()
                }
                return
            }
        }
        if currentPath == audioPath {
            return
        }
        play(audioPath: audioPath)
    }

    func play(audioPath: String?) {
        stop()
        guard let audioPath, !audioPath.isEmpty else {
            print("🔊 ❌ No audio path")
            return
        }
        guard let url = resolveAudioURL(audioPath) else {
            print("🔊 ❌ Could not resolve audio URL")
            return
        }

        let exists = FileManager.default.fileExists(atPath: url.path)
        print("🔊 Audio path: \(url.path)")
        print("🔊 File exists: \(exists)")
        guard exists else {
            logDocumentsFiles()
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
            print("🔊 Session ready: mode=default, speaker=override")
        } catch {
            print("🔊 ⚠️ Session setup failed: \(error) – trying anyway")
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.volume = 1.0
            p.prepareToPlay()
            if p.play() {
                avPlayer = p
                currentPath = audioPath
                isPlaying = true
                remainingDuration = p.duration
                startProgressTimer()
                print("🔊 ✅ Playing with AVAudioPlayer (\(String(format: "%.1f", p.duration))s)")
                return
            }
        } catch {
            print("🔊 AVAudioPlayer failed: \(error)")
        }

        do {
            try playWithAudioFile(url: url, audioPath: audioPath)
            print("🔊 ✅ Playing via AVAudioEngine")
        } catch {
            print("🔊 AVAudioFile failed, trying raw PCM... \(error)")
            tryPlayRawPCM(url: url, audioPath: audioPath)
        }
    }

    func stop() {
        let wasPlaying = isPlaying || (avPlayer?.isPlaying == true) || (playerNode?.isPlaying == true)
        avPlayer?.stop()
        playerNode?.stop()
        audioEngine?.stop()
        cleanup()
        if wasPlaying {
            restoreRecordingSession()
        }
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
        avPlayer = nil
        playerNode = nil
        audioEngine = nil
        audioFile = nil
        totalFrames = 0
        isPlaying = false
        progress = 0
        currentPath = nil
        remainingDuration = 0
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
    }

    private func restoreRecordingSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try AVAudioSession.sharedInstance().setActive(true)
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
            print("🔊 Session reset to recording mode")
        } catch {
            print("🔊 ⚠️ Session reset failed: \(error)")
        }
    }

    private func startProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if let p = self.avPlayer {
                self.progress = p.duration > 0 ? Float(p.currentTime / p.duration) : 0
                self.remainingDuration = max(0, p.duration - p.currentTime)
                return
            }
            guard let node = self.playerNode,
                  let nodeTime = node.lastRenderTime,
                  let playerTime = node.playerTime(forNodeTime: nodeTime),
                  self.totalFrames > 0
            else { return }

            let played = max(0, AVAudioFramePosition(playerTime.sampleTime))
            let clamped = min(played, self.totalFrames)
            self.progress = Float(clamped) / Float(self.totalFrames)
            let sampleRate = self.audioFile?.processingFormat.sampleRate ?? 16_000
            let remainingFrames = max(0, self.totalFrames - clamped)
            self.remainingDuration = Double(remainingFrames) / sampleRate
        }
    }

    private func playWithAudioFile(url: URL, audioPath: String) throws {
        let file = try AVAudioFile(forReading: url)
        print("🔊 File format: \(file.processingFormat)")

        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
        try engine.start()

        totalFrames = file.length
        remainingDuration = file.processingFormat.sampleRate > 0 ? Double(file.length) / file.processingFormat.sampleRate : 0
        node.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async { self?.stop() }
        }
        node.play()

        audioEngine = engine
        playerNode = node
        audioFile = file
        currentPath = audioPath
        isPlaying = true
        startProgressTimer()
    }

    private func tryPlayRawPCM(url: URL, audioPath: String) {
        do {
            let data = try Data(contentsOf: url)
            print("🔊 Raw data size: \(data.count) bytes")
            let hasWAVHeader = data.count > 44 && String(data: data.prefix(4), encoding: .ascii) == "RIFF"
            let pcmData: Data
            let sampleRate: Double
            if hasWAVHeader {
                pcmData = data.dropFirst(44)
                if data.count >= 28 {
                    sampleRate = Double(data.subdata(in: 24..<28).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
                } else {
                    sampleRate = 16_000
                }
                print("🔊 WAV header found. Sample rate: \(sampleRate)")
            } else {
                pcmData = data
                sampleRate = 16_000
                print("🔊 No WAV header, assuming 16kHz PCM")
            }

            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: 1,
                interleaved: true
            ) else {
                print("🔊 ❌ Could not create raw PCM format")
                cleanup()
                return
            }

            let frameCount = UInt32(pcmData.count) / 2
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
                  let channelData = buffer.int16ChannelData
            else {
                print("🔊 ❌ Could not create PCM buffer")
                cleanup()
                return
            }

            buffer.frameLength = frameCount
            pcmData.withUnsafeBytes { rawBytes in
                if let src = rawBytes.baseAddress {
                    memcpy(channelData[0], src, pcmData.count)
                }
            }

            let engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            try engine.start()

            totalFrames = AVAudioFramePosition(frameCount)
            remainingDuration = format.sampleRate > 0 ? Double(frameCount) / format.sampleRate : 0
            node.scheduleBuffer(buffer) { [weak self] in
                DispatchQueue.main.async { self?.stop() }
            }
            node.play()

            audioEngine = engine
            playerNode = node
            audioFile = nil
            currentPath = audioPath
            isPlaying = true
            startProgressTimer()
            print("🔊 ✅ Playing raw PCM via buffer")
        } catch {
            print("🔊 ❌ Raw PCM error: \(error)")
            cleanup()
        }
    }

    private func resolveAudioURL(_ audioPath: String) -> URL? {
        if audioPath.hasPrefix("/") {
            return URL(fileURLWithPath: audioPath)
        }
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let direct = docs.appendingPathComponent(audioPath)
        if FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        let fallback = docs
            .appendingPathComponent("journal_audio", isDirectory: true)
            .appendingPathComponent((audioPath as NSString).lastPathComponent)
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        return direct
    }

    private func logDocumentsFiles() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let files = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)
        print("🔊 Files in Documents:")
        files?.prefix(50).forEach { print("🔊   \($0.lastPathComponent)") }
    }
}

extension KlunaAudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.stop() }
    }
}

