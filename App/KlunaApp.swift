import SwiftUI
import CoreData

@main
struct KlunaApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var teamManager = TeamManager()
    @StateObject private var streakManager: StreakManager
    @StateObject private var challengeManager: ChallengeManager

    init() {
        let mm = MemoryManager(context: persistenceController.container.viewContext)
        Self.performBaselineResetIfNeeded(context: persistenceController.container.viewContext)
        _streakManager = StateObject(wrappedValue: StreakManager(memoryManager: mm))
        _challengeManager = StateObject(wrappedValue: ChallengeManager(memoryManager: mm))
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(subscriptionManager)
                .environmentObject(teamManager)
                .environmentObject(streakManager)
                .environmentObject(challengeManager)
        }
    }

    private static func performBaselineResetIfNeeded(context: NSManagedObjectContext) {
        let resetKey = "baselineResetV3_scoringRecalibration"
        guard !UserDefaults.standard.bool(forKey: resetKey) else { return }

        print("🔄 Resetting baselines for real feature values...")
        BaselineEngine().resetAll(context: context)

        let explicitKeys = [
            "ewmaBaselines",
            "featureBaselines",
            "baselineMeans",
            "baselineStdDevs",
            "baselineSessionCount",
        ]
        explicitKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys {
            let lowered = key.lowercased()
            if lowered.contains("baseline") || lowered.contains("ewma") ||
                lowered.contains("running") || lowered.contains("zscore") {
                UserDefaults.standard.removeObject(forKey: key)
                print("🔄 Removed defaults key: \(key)")
            }
        }

        UserDefaults.standard.set(true, forKey: resetKey)
        print("✅ Baselines reset complete")
    }
}
