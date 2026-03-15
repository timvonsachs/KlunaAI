import Foundation

final class FeatureUnlockManager {
    static let shared = FeatureUnlockManager()

    struct Unlock {
        let id: String
        let sessionThreshold: Int
        let message: String
    }

    private let unlocks: [Unlock] = [
        Unlock(id: "dimensions", sessionThreshold: 2, message: "Kluna zeigt dir jetzt 5 Dimensionen deiner Stimme."),
        Unlock(id: "profile", sessionThreshold: 3, message: "Ab jetzt erkennt Kluna deinen Sprechstil."),
        Unlock(id: "prediction", sessionThreshold: 4, message: "Kluna kann jetzt vorhersagen wie du abschneidest. Schlag die Erwartung!"),
        Unlock(id: "spectral", sessionThreshold: 6, message: "Neues Feature: Stimmklang-Analyse. Wärme, Präsenz und Brillanz."),
        Unlock(id: "melodic", sessionThreshold: 8, message: "Neues Feature: Melodie-Analyse. Bewusste vs. zufällige Betonung."),
        Unlock(id: "consistency", sessionThreshold: 10, message: "10 Sessions! Kluna trackt jetzt deine Konsistenz."),
    ]

    func checkUnlocks(sessionCount: Int) -> [Unlock] {
        let shownKey = "shownUnlocks"
        var shown = UserDefaults.standard.stringArray(forKey: shownKey) ?? []
        var newlyUnlocked: [Unlock] = []

        for unlock in unlocks where sessionCount >= unlock.sessionThreshold && !shown.contains(unlock.id) {
            newlyUnlocked.append(unlock)
            shown.append(unlock.id)
        }

        UserDefaults.standard.set(shown, forKey: shownKey)
        return newlyUnlocked
    }

    func isUnlocked(_ featureId: String, sessionCount: Int) -> Bool {
        guard let unlock = unlocks.first(where: { $0.id == featureId }) else { return false }
        return sessionCount >= unlock.sessionThreshold
    }
}
