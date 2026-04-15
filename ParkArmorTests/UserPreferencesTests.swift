import Foundation
import Testing
@testable import ParkArmor

// MARK: - TimerAlertMode

@Suite("TimerAlertMode")
struct TimerAlertModeTests {
    @Test func atExpirationHasOneOffset() {
        #expect(TimerAlertMode.atExpiration.offsets == [TimeInterval(0)])
    }

    @Test func fifteenMinutesBeforeHasOneOffset() {
        let offsets = TimerAlertMode.fifteenMinutesBefore.offsets
        #expect(offsets == [TimeInterval(15 * 60)])
    }

    @Test func fifteenMinutesAndExpirationHasTwoOffsets() {
        let offsets = TimerAlertMode.fifteenMinutesAndExpiration.offsets
        #expect(offsets.count == 2)
        #expect(offsets.contains(TimeInterval(0)))
        #expect(offsets.contains(TimeInterval(15 * 60)))
    }

    @Test func allCasesHaveNonEmptyTitle() {
        for mode in TimerAlertMode.allCases {
            #expect(!mode.title.isEmpty)
        }
    }
}

// MARK: - HistoryRetentionOption

@Suite("HistoryRetentionOption")
struct HistoryRetentionOptionTests {
    @Test func foreverHasNilCutoff() {
        #expect(HistoryRetentionOption.forever.cutoffDate == nil)
    }

    @Test func sevenDaysCutoffIsInPast() {
        let cutoff = HistoryRetentionOption.sevenDays.cutoffDate
        #expect(cutoff != nil)
        #expect(cutoff! < Date())
    }

    @Test func thirtyDaysCutoffIsInPast() {
        let cutoff = HistoryRetentionOption.thirtyDays.cutoffDate
        #expect(cutoff != nil)
        #expect(cutoff! < Date())
    }

    @Test func ninetyDaysCutoffIsInPast() {
        let cutoff = HistoryRetentionOption.ninetyDays.cutoffDate
        #expect(cutoff != nil)
        #expect(cutoff! < Date())
    }

    @Test func cutoffDatesAreOrdered() {
        let seven = HistoryRetentionOption.sevenDays.cutoffDate!
        let thirty = HistoryRetentionOption.thirtyDays.cutoffDate!
        let ninety = HistoryRetentionOption.ninetyDays.cutoffDate!
        // 7 days ago is MORE RECENT than 90 days ago
        #expect(seven > thirty)
        #expect(thirty > ninety)
    }

    @Test func allCasesHaveNonEmptyTitle() {
        for option in HistoryRetentionOption.allCases {
            #expect(!option.title.isEmpty)
        }
    }

    @Test func rawValuesRoundTrip() {
        for option in HistoryRetentionOption.allCases {
            let recovered = HistoryRetentionOption(rawValue: option.rawValue)
            #expect(recovered == option)
        }
    }
}

// MARK: - TimeFormat

@Suite("TimeFormat")
struct TimeFormatTests {
    @Test func rawValuesRoundTrip() {
        for format in TimeFormat.allCases {
            let recovered = TimeFormat(rawValue: format.rawValue)
            #expect(recovered == format)
        }
    }
}

@Suite("UserPreferences — premium entitlement")
struct UserPreferencesPremiumTests {
    @Test func doesNotRestoreProFromLegacyDefaultsCache() {
        let suiteName = "UserPreferencesPremiumTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(true, forKey: "isPro")

        let preferences = UserPreferences(defaults: defaults)

        #expect(preferences.isPro == false)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func changingProStateDoesNotWriteToDefaults() {
        let suiteName = "UserPreferencesPremiumTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = UserPreferences(defaults: defaults)

        preferences.isPro = true

        #expect(defaults.object(forKey: "isPro") == nil)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
