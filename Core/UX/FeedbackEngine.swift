import UIKit
import Foundation
import UserNotifications

final class FeedbackEngine {
    static let shared = FeedbackEngine()

    func scoreReveal(score: Double) {
        if score >= 75 {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    func positiveSurprise() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func levelUp() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            generator.notificationOccurred(.success)
        }
    }

    func xpGain() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func barFill() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

@MainActor
final class KlunaNotificationManager {
    static let shared = KlunaNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let promptReminderId = "kluna.prompt.daily"
    private let monthlyReviewId = "kluna.monthly.review"
    private let eveningQuestionId = "kluna.evening.question"
    private let threadReminderId = "kluna.thread.reminder"

    private init() {}

    func configureOnLaunch() async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }
        await schedulePersonalizedPromptReminder()
        await scheduleMonthlyReviewHint()
    }

    func refreshPromptReminder() async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }
        await schedulePersonalizedPromptReminder()
    }

    func requestPermission() {
        Task {
            let granted = await requestAuthorizationIfNeeded()
            KlunaAnalytics.shared.track(granted ? "notifications_granted" : "notifications_denied")
        }
    }

    func scheduleEveningQuestion(_ question: String) {
        let cleaned = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        Task {
            let granted = await requestAuthorizationIfNeeded()
            guard granted else { return }
            await center.removePendingNotificationRequests(withIdentifiers: [eveningQuestionId])

            let content = UNMutableNotificationContent()
            content.title = "Kluna"
            content.body = cleaned
            content.sound = .default

            var date = DateComponents()
            date.hour = 20
            date.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: eveningQuestionId, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func scheduleThreadReminder(_ thread: String) {
        let cleaned = thread.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        Task {
            let granted = await requestAuthorizationIfNeeded()
            guard granted else { return }
            await center.removePendingNotificationRequests(withIdentifiers: [threadReminderId])

            let isGerman = (Locale.current.language.languageCode?.identifier ?? "de") == "de"
            let body: String
            if cleaned == "unresolved_tension" {
                body = isGerman
                    ? "Gestern war noch etwas offen. Wie klingt deine Stimme heute?"
                    : "Something was still open yesterday. How does your voice sound today?"
            } else if cleaned == "short_ending" {
                body = isGerman
                    ? "Du hast gestern etwas angefangen. Willst du weitermachen?"
                    : "You started telling me something yesterday. Want to continue?"
            } else {
                body = cleaned
            }

            let content = UNMutableNotificationContent()
            content.title = "Kluna"
            content.body = body
            content.sound = .default

            var date = DateComponents()
            date.hour = 9
            date.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
            let request = UNNotificationRequest(identifier: threadReminderId, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    func scheduleMilestoneHint(title: String) async {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Neuer Meilenstein"
        content.body = "Du hast \(title) freigeschaltet. Teile deinen Moment in Kluna."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 8, repeats: false)
        let request = UNNotificationRequest(identifier: "kluna.milestone.\(UUID().uuidString)", content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    private func schedulePersonalizedPromptReminder() async {
        await center.removePendingNotificationRequests(withIdentifiers: [promptReminderId])

        let prompt = PromptManager.shared.currentPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = UNMutableNotificationContent()
        content.title = "Deine Stimme wartet"
        content.body = prompt.isEmpty ? "Nimm dir 2 Minuten fuer dein Voice Journal." : "Heute fuer dich: \(prompt)"
        content.sound = .default

        var date = DateComponents()
        date.hour = 20
        date.minute = 30

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: promptReminderId, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleMonthlyReviewHint() async {
        await center.removePendingNotificationRequests(withIdentifiers: [monthlyReviewId])

        let content = UNMutableNotificationContent()
        content.title = "Monatsrueckblick bereit"
        content.body = "Dein Kluna Monatsbrief wartet auf dich."
        content.sound = .default

        var date = DateComponents()
        date.day = 1
        date.hour = 10
        date.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: monthlyReviewId, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
