import SwiftUI
import UIKit

enum KlunaWarm {
    static let background = Color(hex: "FFF8F0")
    static let cardBackground = Color(hex: "FFF1E6")
    static let warmBrown = Color(hex: "3D3229")
    static let warmAccent = Color(hex: "E8825C")
    static let secondary = Color(hex: "9C8E82")

    static let begeistert = Color(hex: "FFD54F")
    static let aufgewuehlt = Color(hex: "FF7043")
    static let zufrieden = Color(hex: "4DB6AC")
    static let erschoepft = Color(hex: "90A4AE")
    static let moodBegeistert = Color(hex: "F5B731")
    static let moodAufgekratzt = Color(hex: "F0943D")
    static let moodAufgewuehlt = Color(hex: "E85C5C")
    static let moodAngespannt = Color(hex: "D4734E")
    static let moodFrustriert = Color(hex: "9B6B5C")
    static let moodErschoepft = Color(hex: "8B9DAF")
    static let moodVerletzlich = Color(hex: "B088A8")
    static let moodRuhig = Color(hex: "6BC5A0")
    static let moodZufrieden = Color(hex: "4DB8A4")
    static let moodNachdenklich = Color(hex: "7BA7C4")

    static func color(for quadrant: EmotionQuadrant) -> Color {
        switch quadrant {
        case .begeistert: return begeistert
        case .aufgewuehlt: return aufgewuehlt
        case .zufrieden: return zufrieden
        case .erschoepft: return erschoepft
        }
    }

    static func moodColor(for rawMood: String?, fallbackQuadrant: EmotionQuadrant) -> Color {
        let normalizedRaw = (rawMood ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalizedRaw {
        case "excited", "begeistert": return moodBegeistert
        case "energized", "aufgekratzt": return moodAufgekratzt
        case "stirred_up", "aufgewühlt", "aufgewuehlt": return moodAufgewuehlt
        case "tense", "angespannt": return moodAngespannt
        case "frustrated", "frustriert": return moodFrustriert
        case "exhausted", "erschöpft", "erschoepft": return moodErschoepft
        case "vulnerable", "verletzlich": return moodVerletzlich
        case "calm", "ruhig": return moodRuhig
        case "content", "zufrieden", "relieved", "erleichtert": return moodZufrieden
        case "reflective", "nachdenklich": return moodNachdenklich
        case "hopeful", "hoffnungsvoll": return moodBegeistert
        case "grateful", "dankbar": return warmAccent
        default:
            break
        }

        guard let mood = MoodCategory.resolve(rawMood)?.rawValue else { return color(for: fallbackQuadrant) }
        switch mood {
        case MoodCategory.begeistert.rawValue: return moodBegeistert
        case MoodCategory.aufgekratzt.rawValue: return moodAufgekratzt
        case MoodCategory.aufgewuehlt.rawValue: return moodAufgewuehlt
        case MoodCategory.angespannt.rawValue: return moodAngespannt
        case MoodCategory.frustriert.rawValue: return moodFrustriert
        case MoodCategory.erschoepft.rawValue: return moodErschoepft
        case MoodCategory.verletzlich.rawValue: return moodVerletzlich
        case MoodCategory.ruhig.rawValue: return moodRuhig
        case MoodCategory.zufrieden.rawValue: return moodZufrieden
        case MoodCategory.nachdenklich.rawValue: return moodNachdenklich
        default: return color(for: fallbackQuadrant)
        }
    }
}

extension JournalEntry {
    var stimmungsfarbe: Color {
        KlunaWarm.moodColor(for: mood, fallbackQuadrant: quadrant)
    }
}

extension EmotionQuadrant {
    var title: String {
        switch self {
        case .begeistert: return "Begeistert"
        case .aufgewuehlt: return "Aufgekratzt"
        case .zufrieden: return "Zufrieden"
        case .erschoepft: return "Erschöpft"
        }
    }

    var label: String {
        switch self {
        case .begeistert: return "Aufgekratzt und positiv"
        case .aufgewuehlt: return "Aufgewühlt"
        case .zufrieden: return "Ruhig und zufrieden"
        case .erschoepft: return "Ruhig und erschöpft"
        }
    }
}

struct WarmCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(KlunaWarm.cardBackground)
                    .shadow(color: KlunaWarm.warmBrown.opacity(0.06), radius: 12, x: 0, y: 6)
            )
    }
}

// MARK: - Share Engine

enum ShareAspect {
    case story
    case post
    case square

    var size: CGSize {
        switch self {
        case .story: return CGSize(width: 1080, height: 1920)
        case .post: return CGSize(width: 1080, height: 1080)
        case .square: return CGSize(width: 1080, height: 1080)
        }
    }
}

struct VoiceTypeShareData {
    let typeName: String
    let typeDescription: String
    let dimensions: VoiceDimensions
    let userName: String
    let signatureShape: VoiceSignatureData
    let dominantColor: Color
}

struct MonthlyReviewShareData {
    let month: String
    let dominantMood: String
    let dominantColor: Color
    let totalEntries: Int
    let totalMinutes: Int
    let streakRecord: Int
    let moodDistribution: [(String, Color, Float)]
    let signatureData: VoiceSignatureData
}

struct MilestoneShareData {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let date: Date
    let streakCount: Int?
    let entryCount: Int?
}

struct ContradictionShareData {
    let wordsSay: String
    let voiceSays: String
    let moodColor: Color
    let date: Date
}

struct SignatureShareData {
    let signatureData: VoiceSignatureData
    let moodLabel: String
    let color: Color
    let date: Date
}

struct StreakShareData {
    let days: Int
    let color: Color
}

struct YearReviewShareData {
    let title: String
}

struct MonthlyLetterShareData {
    let monthName: String
    let excerpt: String
    let entryCount: Int
    let activeDays: Int
    let longestStreak: Int
    let dominantMood: String
    let legendaryCards: Int
    let rareCards: Int
}

enum ShareContent {
    case voiceType(VoiceTypeShareData)
    case monthlyReview(MonthlyReviewShareData)
    case monthlyLetter(MonthlyLetterShareData)
    case milestone(MilestoneShareData)
    case contradiction(ContradictionShareData)
    case signature(SignatureShareData)
    case streak(StreakShareData)
    case yearReview(YearReviewShareData)

    var defaultAspect: ShareAspect { .story }
}

enum ShareCTAType: String, CaseIterable {
    case voiceType
    case contradiction
    case milestone
    case monthly
    case streak
    case signature
}

final class ShareABManager: ObservableObject {
    static let shared = ShareABManager()

    private let variantPrefix = "kluna.share.ab.variant."
    private let tapsPrefix = "kluna.share.ab.taps."
    private let shownPrefix = "kluna.share.ab.shown."

    func ctaText(for type: ShareCTAType) -> String {
        variant(for: type) == "A" ? "Teilen" : "Story teilen"
    }

    func trackShown(_ type: ShareCTAType) {
        increment(shownPrefix + type.rawValue)
    }

    func trackTap(_ type: ShareCTAType) {
        increment(tapsPrefix + type.rawValue)
    }

    private func variant(for type: ShareCTAType) -> String {
        let key = variantPrefix + type.rawValue
        if let saved = UserDefaults.standard.string(forKey: key) { return saved }
        let newVariant = Bool.random() ? "A" : "B"
        UserDefaults.standard.set(newVariant, forKey: key)
        return newVariant
    }

    private func increment(_ key: String) {
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }
}

@MainActor
enum ShareImageGenerator {
    static func generateImage(content: ShareContent, aspect: ShareAspect? = nil) -> UIImage? {
        let resolvedAspect = aspect ?? .story
        let size = resolvedAspect.size
        let renderer = ImageRenderer(
            content: ShareCardView(content: content, aspect: resolvedAspect)
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = 1.0
        renderer.proposedSize = .init(size)
        return renderer.uiImage
    }

    static func share(content: ShareContent, from viewController: UIViewController? = nil) {
        guard let storyImage = generateImage(content: content, aspect: .story),
              let postImage = generateImage(content: content, aspect: .post) else {
            print("Share: Could not generate image")
            return
        }
        let count = UserDefaults.standard.integer(forKey: "kluna_share_count")
        UserDefaults.standard.set(count + 1, forKey: "kluna_share_count")
        KlunaAnalytics.shared.track("share_triggered", value: shareType(for: content))
        ShareManager.share(itemSource: ShareImageItemSource(storyImage: storyImage, postImage: postImage), from: viewController)
    }

    private static func shareType(for content: ShareContent) -> String {
        switch content {
        case .voiceType: return "voiceType"
        case .monthlyReview: return "monthlyReview"
        case .monthlyLetter: return "monthlyLetter"
        case .milestone: return "milestone"
        case .contradiction: return "contradiction"
        case .signature: return "signature"
        case .streak: return "streak"
        case .yearReview: return "yearReview"
        }
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

private final class ShareImageItemSource: NSObject, UIActivityItemSource {
    private let storyImage: UIImage
    private let postImage: UIImage

    init(storyImage: UIImage, postImage: UIImage) {
        self.storyImage = storyImage
        self.postImage = postImage
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        postImage
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        preferredImage(for: activityType)
    }

    private func preferredImage(for activityType: UIActivity.ActivityType?) -> UIImage {
        guard let raw = activityType?.rawValue.lowercased() else { return postImage }
        if raw.contains("instagram") || raw.contains("snapchat") || raw.contains("story") || raw.contains("facebook") {
            return storyImage
        }
        return postImage
    }
}

enum ShareManager {
    static func share(image: UIImage, from viewController: UIViewController? = nil) {
        share(itemSource: image, from: viewController)
    }

    static func share(itemSource: Any, from viewController: UIViewController? = nil) {
        DispatchQueue.main.async {
            let activityVC = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
            let sourceView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
            activityVC.popoverPresentationController?.sourceView = sourceView

            let root = viewController ?? topViewController()
            root?.view.addSubview(sourceView)
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
            root?.present(activityVC, animated: true) {
                sourceView.removeFromSuperview()
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return nil
        }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
}

struct KlunaShareButton: View {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Teilen")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(KlunaWarm.warmAccent)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(KlunaWarm.warmAccent.opacity(0.08)))
        }
    }
}

private struct ShareCardView: View {
    let content: ShareContent
    let aspect: ShareAspect

    var body: some View {
        switch content {
        case .voiceType(let data): VoiceTypeShareCard(data: data, aspect: aspect)
        case .monthlyReview(let data): MonthlyReviewShareCard(data: data, aspect: aspect)
        case .monthlyLetter(let data): KlunaMonthlyLetterShareCard(data: data, aspect: aspect)
        case .milestone(let data): MilestoneShareCard(data: data, aspect: aspect)
        case .contradiction(let data): ContradictionShareCard(data: data, aspect: aspect)
        case .signature(let data): SignatureShareCard(data: data, aspect: aspect)
        case .streak(let data): StreakShareCard(data: data, aspect: aspect)
        case .yearReview(let data): YearReviewShareCard(data: data, aspect: aspect)
        }
    }
}

private struct ShareCardBase<Content: View>: View {
    let aspect: ShareAspect
    let content: Content

    init(aspect: ShareAspect = .story, @ViewBuilder content: () -> Content) {
        self.aspect = aspect
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color(hex: "FFF8F0")
            Circle()
                .fill(
                    RadialGradient(
                        colors: [KlunaWarm.warmAccent.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: 800, height: 800)
                .offset(x: 200, y: -220)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [KlunaWarm.warmAccent.opacity(0.04), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 620, height: 620)
                .offset(x: -220, y: 420)
            VStack(spacing: 0) {
                content
                Spacer()
                VStack(spacing: 16) {
                    Rectangle()
                        .fill(KlunaWarm.warmBrown.opacity(0.04))
                        .frame(width: 200, height: 1)
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(KlunaWarm.warmAccent.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Text("K")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmAccent)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Kluna")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown)
                            Text("Das Tagebuch das zuhört")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                                .minimumScaleFactor(0.8)
                        }
                    }
                    Text("kluna.app")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(KlunaWarm.warmAccent.opacity(0.35))
                }
                .padding(.bottom, 56)
            }
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

private struct VoiceTypeShareCard: View {
    let data: VoiceTypeShareData
    let aspect: ShareAspect

    var body: some View {
        ShareCardBase(aspect: aspect) {
            VStack(spacing: 0) {
                Spacer().frame(height: 140)
                Text("MEIN STIMM-TYP")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(data.dominantColor.opacity(0.3))
                Spacer().frame(height: 64)
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [data.dominantColor.opacity(0.5), data.dominantColor.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: 160
                            )
                        )
                        .frame(width: 320, height: 320)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [data.dominantColor.opacity(0.85), data.dominantColor],
                                center: .init(x: 0.35, y: 0.35),
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.3), .clear],
                                center: .init(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 160, height: 160)
                }
                Spacer().frame(height: 48)
                Text(data.typeName)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .minimumScaleFactor(0.6)
                Spacer().frame(height: 16)
                Text(data.typeDescription)
                    .font(.system(size: 36, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 80)
                    .minimumScaleFactor(0.55)
                Spacer().frame(height: 56)
                HStack(spacing: 32) {
                    DimCircle(letter: "E", value: data.dimensions.energy, color: Color(hex: "F5B731"))
                    DimCircle(letter: "A", value: data.dimensions.tension, color: Color(hex: "E85C5C"))
                    DimCircle(letter: "M", value: data.dimensions.fatigue, color: Color(hex: "8B9DAF"))
                    DimCircle(letter: "W", value: data.dimensions.warmth, color: Color(hex: "E8825C"))
                    DimCircle(letter: "L", value: data.dimensions.expressiveness, color: Color(hex: "6BC5A0"))
                    DimCircle(letter: "T", value: data.dimensions.tempo, color: Color(hex: "7BA7C4"))
                }
                Spacer().frame(height: 72)
                Text("Was ist dein Stimm-Typ?")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(data.dominantColor.opacity(0.4))
                Spacer()
            }
        }
    }
}

private struct ContradictionShareCard: View {
    let data: ContradictionShareData
    let aspect: ShareAspect

    var body: some View {
        ShareCardBase(aspect: aspect) {
            VStack(spacing: 0) {
                Spacer().frame(height: 280)
                Text("ICH SAGTE")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.12))
                Spacer().frame(height: 24)
                Text("„\(data.wordsSay)“")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 60)
                    .minimumScaleFactor(0.5)
                Spacer().frame(height: 56)
                Canvas { context, size in
                    let mid = size.height / 2
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: mid))
                    for x in stride(from: 0, to: size.width, by: 3) {
                        let nx = x / size.width
                        let env = sin(nx * .pi)
                        let y = mid + sin(nx * .pi * 5 + 0.8) * 24 * env
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    context.stroke(path, with: .color(KlunaWarm.warmAccent.opacity(0.25)),
                                   style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    context.stroke(path, with: .color(KlunaWarm.warmAccent.opacity(0.06)),
                                   style: StrokeStyle(lineWidth: 20, lineCap: .round))
                }
                .frame(width: 800, height: 70)
                Spacer().frame(height: 56)
                Text("MEINE STIMME SAGT")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(KlunaWarm.warmAccent.opacity(0.35))
                Spacer().frame(height: 24)
                Text("„\(data.voiceSays)“")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmAccent)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 60)
                    .minimumScaleFactor(0.5)
                Spacer()
            }
        }
    }
}

private struct MilestoneShareCard: View {
    let data: MilestoneShareData
    let aspect: ShareAspect

    var body: some View {
        ShareCardBase(aspect: aspect) {
            VStack(spacing: 0) {
                Spacer().frame(height: 200)
                Text(milestoneEmoji(title: data.title))
                    .font(.system(size: 180))
                Spacer().frame(height: 16)
                Text(milestoneValue(title: data.title))
                    .font(.system(size: 160, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .minimumScaleFactor(0.5)
                Spacer().frame(height: 8)
                Text(data.title)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.6))
                    .minimumScaleFactor(0.6)
                Spacer().frame(height: 16)
                Text(data.subtitle)
                    .font(.system(size: 28, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 100)
                    .minimumScaleFactor(0.6)
                Spacer()
            }
        }
    }

    private func milestoneEmoji(title: String) -> String {
        switch title {
        case "Erster Schritt": return "🎙"
        case "Eine Woche": return "🔥"
        case "Monatsheld": return "🏆"
        case "10 Einträge": return "✨"
        case "50 Einträge": return "💎"
        case "100 Einträge": return "👑"
        case "Volle Palette": return "🎨"
        case "Verletzlich": return "💜"
        case "Eine Stunde": return "⏱"
        default: return "⭐"
        }
    }

    private func milestoneValue(title: String) -> String {
        switch title {
        case "Erster Schritt": return "1"
        case "Eine Woche": return "7"
        case "Monatsheld": return "30"
        case "10 Einträge": return "10"
        case "50 Einträge": return "50"
        case "100 Einträge": return "100"
        case "Eine Stunde": return "60"
        default: return "★"
        }
    }
}

private struct MonthlyReviewShareCard: View {
    let data: MonthlyReviewShareData
    let aspect: ShareAspect

    var body: some View {
        ShareCardBase(aspect: aspect) {
            VStack(spacing: 0) {
                Spacer().frame(height: 120)
                Text("MEIN MONAT")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(data.dominantColor.opacity(0.3))
                Spacer().frame(height: 12)
                Text(data.month)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .minimumScaleFactor(0.7)
                Spacer().frame(height: 48)
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [data.dominantColor.opacity(0.6), data.dominantColor.opacity(0.15), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 140
                            )
                        )
                        .frame(width: 280, height: 280)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [data.dominantColor.opacity(0.85), data.dominantColor],
                                center: .init(x: 0.35, y: 0.35),
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.25), .clear],
                                center: .init(x: 0.3, y: 0.3),
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                        .frame(width: 120, height: 120)
                }
                Spacer().frame(height: 20)
                Text("Meistens \(data.dominantMood)")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(data.dominantColor)
                    .minimumScaleFactor(0.7)
                Spacer().frame(height: 48)
                HStack(spacing: 3) {
                    ForEach(Array(data.moodDistribution.enumerated()), id: \.offset) { _, item in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.1)
                            .frame(width: max(8, CGFloat(item.2) * 600), height: 14)
                    }
                }
                .clipShape(Capsule())
                .padding(.horizontal, 120)
                Spacer().frame(height: 48)
                HStack(spacing: 0) {
                    ShareStat(value: "\(data.totalEntries)", label: "Einträge")
                    ShareStatDivider()
                    ShareStat(value: "\(data.totalMinutes)", label: "Minuten")
                    ShareStatDivider()
                    ShareStat(value: "\(data.streakRecord)🔥", label: "Beste Streak")
                }
                .padding(.horizontal, 80)
                Spacer()
            }
        }
    }
}

private struct StreakShareCard: View {
    let data: StreakShareData
    let aspect: ShareAspect

    var body: some View {
        ShareCardBase(aspect: aspect) {
            VStack(spacing: 0) {
                Spacer()
                Text("🔥").font(.system(size: 200))
                Spacer().frame(height: 8)
                Text("\(data.days)")
                    .font(.system(size: 180, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                Text("Tage in Folge")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.3))
                Spacer().frame(height: 32)
                Text("Jeden Tag 20 Sekunden.\nMein Tagebuch hört zu.")
                    .font(.system(size: 36, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.15))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                Spacer()
            }
        }
    }
}

private struct DimCircle: View {
    let letter: String
    let value: CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(KlunaWarm.warmBrown.opacity(0.04), lineWidth: 6)
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: clamp01(value) * 0.75)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(135))
            }
            .frame(width: 72, height: 72)
            Text(letter)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.2))
        }
    }
}

private struct SignatureShareCard: View {
    let data: SignatureShareData
    let aspect: ShareAspect

    var body: some View {
        ShareCardBase(aspect: aspect) {
            VStack(spacing: 0) {
                Spacer().frame(height: 200)
                Text("MEIN STIMMABDRUCK")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(KlunaWarm.warmAccent.opacity(0.4))
                Spacer().frame(height: 48)
                VoiceSignatureStatic(data: data.signatureData, size: 300, color: data.color)
                Spacer().frame(height: 24)
                Text(data.moodLabel)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .foregroundStyle(data.color)
                    .minimumScaleFactor(0.6)
                Spacer()
            }
        }
    }
}

private struct YearReviewShareCard: View {
    let data: YearReviewShareData
    let aspect: ShareAspect

    var body: some View {
        ShareCardBase(aspect: aspect) {
            VStack {
                Spacer()
                Text(data.title)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.55)
                Spacer()
            }
        }
    }
}

private struct KlunaMonthlyLetterShareCard: View {
    let data: MonthlyLetterShareData
    let aspect: ShareAspect

    private var dominantColor: Color {
        KlunaWarm.moodColor(for: data.dominantMood, fallbackQuadrant: .zufrieden)
    }

    var body: some View {
        ShareCardBase(aspect: aspect) {
            VStack(spacing: 0) {
                Spacer().frame(height: 130)
                Text("MONATSBRIEF")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(dominantColor.opacity(0.35))
                Spacer().frame(height: 10)
                Text(data.monthName)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(KlunaWarm.warmBrown)
                    .minimumScaleFactor(0.65)

                Spacer().frame(height: 34)

                Text("„\(data.excerpt)“")
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .foregroundStyle(KlunaWarm.warmBrown.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 80)
                    .lineLimit(6)
                    .minimumScaleFactor(0.6)

                Spacer().frame(height: 46)

                HStack(spacing: 0) {
                    ShareStat(value: "\(data.entryCount)", label: "Einträge")
                    ShareStatDivider()
                    ShareStat(value: "\(data.activeDays)", label: "Tage")
                    ShareStatDivider()
                    ShareStat(value: "\(data.longestStreak)🔥", label: "Streak")
                }
                .padding(.horizontal, 80)

                Spacer().frame(height: 20)

                HStack(spacing: 18) {
                    if data.legendaryCards > 0 {
                        HStack(spacing: 5) {
                            Text("⭐")
                            Text("\(data.legendaryCards) Legendär")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "F5B731").opacity(0.8))
                        }
                    }
                    if data.rareCards > 0 {
                        HStack(spacing: 5) {
                            Text("💎")
                            Text("\(data.rareCards) Selten")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "7BA7C4").opacity(0.8))
                        }
                    }
                }

                Spacer()
            }
        }
    }
}

private struct ShareDimBar: View {
    let label: String
    let value: CGFloat
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.35))
                .frame(width: 170, alignment: .trailing)
            ZStack(alignment: .leading) {
                Capsule().fill(KlunaWarm.warmBrown.opacity(0.04)).frame(height: 8)
                Capsule().fill(color).frame(width: clamp01(value) * 200, height: 8)
            }
            .frame(width: 200)
        }
    }
}

private struct ShareStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(KlunaWarm.warmBrown.opacity(0.25))
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShareStatDivider: View {
    var body: some View {
        Rectangle()
            .fill(KlunaWarm.warmBrown.opacity(0.06))
            .frame(width: 1, height: 44)
    }
}

struct VoiceSignatureData {
    let values: [CGFloat]

    static func fromDimensions(_ dimensions: VoiceDimensions) -> VoiceSignatureData {
        VoiceSignatureData(values: [
            clamp01(dimensions.energy),
            clamp01(dimensions.tension),
            clamp01(dimensions.fatigue),
            clamp01(dimensions.warmth),
            clamp01(dimensions.tempo),
            clamp01(dimensions.expressiveness),
        ])
    }
}

private struct VoiceSignatureStatic: View {
    let data: VoiceSignatureData
    let size: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxR = min(geo.size.width, geo.size.height) / 2 - 6
            ZStack {
                ForEach([0.33, 0.66, 1.0], id: \.self) { level in
                    radarPath(values: Array(repeating: level, count: 6), center: center, maxR: maxR)
                        .stroke(KlunaWarm.warmBrown.opacity(0.08), lineWidth: 0.8)
                }
                radarPath(values: data.values, center: center, maxR: maxR)
                    .fill(color.opacity(0.16))
                radarPath(values: data.values, center: center, maxR: maxR)
                    .stroke(color.opacity(0.7), lineWidth: 2)
            }
        }
        .frame(width: size, height: size)
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

private func clamp01(_ value: CGFloat) -> CGFloat {
    Swift.min(Swift.max(value, 0), 1)
}

