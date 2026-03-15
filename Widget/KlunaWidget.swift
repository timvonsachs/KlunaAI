import WidgetKit
import SwiftUI

struct KlunaWidgetEntry: TimelineEntry {
    let date: Date
    let mood: String
    let moodColorHex: String
    let question: String
}

struct KlunaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> KlunaWidgetEntry {
        KlunaWidgetEntry(
            date: Date(),
            mood: "ruhig",
            moodColorHex: "E8825C",
            question: "Was bewegt dich heute wirklich?"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KlunaWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KlunaWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func loadEntry() -> KlunaWidgetEntry {
        let group = KlunaWidgetShared.appGroupId()
        let defaults = UserDefaults(suiteName: group) ?? .standard
        let mood = defaults.string(forKey: KlunaWidgetShared.moodKey) ?? "ruhig"
        let color = defaults.string(forKey: KlunaWidgetShared.moodColorHexKey) ?? "E8825C"
        let question = defaults.string(forKey: KlunaWidgetShared.questionKey) ?? "Was bewegt dich heute wirklich?"
        return KlunaWidgetEntry(date: Date(), mood: mood, moodColorHex: color, question: question)
    }
}

struct KlunaWidgetView: View {
    var entry: KlunaWidgetProvider.Entry

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0")
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: entry.moodColorHex))
                    .frame(width: 36, height: 36)
                Text(entry.mood)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "3D3229").opacity(0.58))
                Text(entry.question)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color(hex: "3D3229").opacity(0.35))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 6)
            }
            .padding(10)
        }
    }
}

struct KlunaWidget: Widget {
    let kind: String = "KlunaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KlunaWidgetProvider()) { entry in
            KlunaWidgetView(entry: entry)
        }
        .configurationDisplayName("Kluna")
        .description("Deine Stimmung und aktuelle Kluna-Frage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    KlunaWidget()
} timeline: {
    KlunaWidgetEntry(date: .now, mood: "zufrieden", moodColorHex: "F5B731", question: "Was war heute dein wärmster Moment?")
}
