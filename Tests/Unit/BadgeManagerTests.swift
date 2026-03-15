import XCTest
import SwiftUI
@testable import KlunaAI

@MainActor
final class BadgeManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BadgeManager.shared.reset()
    }

    override func tearDown() {
        BadgeManager.shared.reset()
        super.tearDown()
    }

    func testFirstEntryBadgeCondition() {
        let badge = BadgeManager.shared.allBadges.first(where: { $0.id == "first_entry" })
        XCTAssertNotNil(badge)
        XCTAssertTrue(badge?.condition(makeStats(totalEntries: 1)) ?? false)
        XCTAssertFalse(badge?.condition(makeStats(totalEntries: 0)) ?? true)
    }

    func testStreakBadgeCondition() {
        let streak3 = BadgeManager.shared.allBadges.first(where: { $0.id == "streak_3" })
        let streak7 = BadgeManager.shared.allBadges.first(where: { $0.id == "streak_7" })
        XCTAssertTrue(streak3?.condition(makeStats(longestStreak: 3)) ?? false)
        XCTAssertTrue(streak3?.condition(makeStats(longestStreak: 7)) ?? false)
        XCTAssertFalse(streak3?.condition(makeStats(longestStreak: 2)) ?? true)
        XCTAssertTrue(streak7?.condition(makeStats(longestStreak: 7)) ?? false)
        XCTAssertFalse(streak7?.condition(makeStats(longestStreak: 3)) ?? true)
    }

    func testFullPaletteBadgeCondition() {
        let badge = BadgeManager.shared.allBadges.first(where: { $0.id == "full_palette" })
        XCTAssertFalse(badge?.condition(makeStats(uniqueMoodsUsed: 9)) ?? true)
        XCTAssertTrue(badge?.condition(makeStats(uniqueMoodsUsed: 10)) ?? false)
    }

    func testOnlyOneBadgeUnlockedPerCheck() {
        let stats = makeStats(totalEntries: 10, longestStreak: 7, uniqueMoodsUsed: 5)
        BadgeManager.shared.checkBadges(stats: stats)
        let firstUnlocked = BadgeManager.shared.newlyUnlocked
        XCTAssertNotNil(firstUnlocked)

        BadgeManager.shared.dismissUnlockedBadge()
        BadgeManager.shared.checkBadges(stats: stats)
        let secondUnlocked = BadgeManager.shared.newlyUnlocked
        XCTAssertNotNil(secondUnlocked)
        XCTAssertNotEqual(firstUnlocked?.id, secondUnlocked?.id)
    }

    func testBadgeProgressCalculation() {
        let stats = makeStats(totalEntries: 35, longestStreak: 5)
        let streak7 = BadgeManager.shared.allBadges.first(where: { $0.id == "streak_7" })
        let entries50 = BadgeManager.shared.allBadges.first(where: { $0.id == "entries_50" })
        XCTAssertNotNil(streak7)
        XCTAssertNotNil(entries50)

        let streakProgress = badgeProgressValue(for: streak7!, stats: stats)
        let entriesProgress = badgeProgressValue(for: entries50!, stats: stats)

        XCTAssertEqual(streakProgress ?? -1, 5.0 / 7.0, accuracy: 0.01)
        XCTAssertEqual(entriesProgress ?? -1, 35.0 / 50.0, accuracy: 0.01)
    }

    private func makeStats(
        totalEntries: Int = 0,
        longestStreak: Int = 0,
        uniqueMoodsUsed: Int = 0
    ) -> KlunaStats {
        KlunaStats(
            totalEntries: totalEntries,
            totalMinutesSpoken: 0,
            longestStreak: longestStreak,
            currentStreak: longestStreak,
            activeDays: 0,
            mostFrequentMood: "Ruhig",
            mostFrequentMoodColor: .blue,
            rarestMood: "Ruhig",
            rarestMoodColor: .blue,
            uniqueMoodsUsed: uniqueMoodsUsed,
            usedMoods: [],
            isDonating: false,
            contradictionCount: 0,
            shareCount: 0,
            maxEnergy: 0,
            minTension: 1,
            minFatigue: 1,
            maxWarmth: 0,
            hasEntryAfterMidnight: false,
            hasEntryBefore6am: false,
            maxThemeCount: 0,
            maxMoodsInOneDay: 0
        )
    }
}
