import Foundation
import Observation

enum TimeFormat: String, CaseIterable {
    case elapsed = "elapsed"   // "2h 15m"
    case clockTime = "clock"   // "Parked at 2:30 PM"
}

enum TimerAlertMode: String, CaseIterable {
    case atExpiration = "at_expiration"
    case fifteenMinutesBefore = "fifteen_minutes_before"
    case fifteenMinutesAndExpiration = "fifteen_minutes_and_expiration"

    var title: String {
        switch self {
        case .atExpiration:
            return "At expiration"
        case .fifteenMinutesBefore:
            return "15 min before"
        case .fifteenMinutesAndExpiration:
            return "15 min before + expiration"
        }
    }

    var offsets: [TimeInterval] {
        switch self {
        case .atExpiration:
            return [0]
        case .fifteenMinutesBefore:
            return [15 * 60]
        case .fifteenMinutesAndExpiration:
            return [15 * 60, 0]
        }
    }
}

enum HistoryRetentionOption: String, CaseIterable {
    case sevenDays = "7_days"
    case thirtyDays = "30_days"
    case ninetyDays = "90_days"
    case forever = "forever"

    var title: String {
        switch self {
        case .sevenDays:
            return "7 days"
        case .thirtyDays:
            return "30 days"
        case .ninetyDays:
            return "90 days"
        case .forever:
            return "Forever"
        }
    }

    var cutoffDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .sevenDays:
            return calendar.date(byAdding: .day, value: -7, to: .now)
        case .thirtyDays:
            return calendar.date(byAdding: .day, value: -30, to: .now)
        case .ninetyDays:
            return calendar.date(byAdding: .day, value: -90, to: .now)
        case .forever:
            return nil
        }
    }
}

@Observable final class UserPreferences {
    private let defaults: UserDefaults

    var distanceUnit: DistanceUnit {
        didSet { defaults.set(distanceUnit.rawValue, forKey: "distanceUnit") }
    }

    var timeFormat: TimeFormat {
        didSet { defaults.set(timeFormat.rawValue, forKey: "timeFormat") }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    var saveParkingHistory: Bool {
        didSet { defaults.set(saveParkingHistory, forKey: "saveParkingHistory") }
    }

    var historyRetention: HistoryRetentionOption {
        didSet { defaults.set(historyRetention.rawValue, forKey: "historyRetention") }
    }

    var timerAlertMode: TimerAlertMode {
        didSet { defaults.set(timerAlertMode.rawValue, forKey: "timerAlertMode") }
    }

    var hasSeenOnboarding: Bool {
        didSet { defaults.set(hasSeenOnboarding, forKey: "hasSeenOnboarding") }
    }

    var isPro: Bool {
        didSet { defaults.set(isPro, forKey: "isPro") }
    }

    init() {
        self.defaults = UserDefaults(suiteName: "group.com.katafract.ParkArmor") ?? .standard
        let distanceRaw = defaults.string(forKey: "distanceUnit") ?? DistanceUnit.miles.rawValue
        self.distanceUnit = DistanceUnit(rawValue: distanceRaw) ?? .miles

        let timeFormatRaw = defaults.string(forKey: "timeFormat") ?? TimeFormat.elapsed.rawValue
        self.timeFormat = TimeFormat(rawValue: timeFormatRaw) ?? .elapsed

        self.notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.saveParkingHistory = defaults.object(forKey: "saveParkingHistory") as? Bool ?? true

        let historyRetentionRaw = defaults.string(forKey: "historyRetention") ?? HistoryRetentionOption.thirtyDays.rawValue
        self.historyRetention = HistoryRetentionOption(rawValue: historyRetentionRaw) ?? .thirtyDays

        let timerAlertRaw = defaults.string(forKey: "timerAlertMode") ?? TimerAlertMode.atExpiration.rawValue
        self.timerAlertMode = TimerAlertMode(rawValue: timerAlertRaw) ?? .atExpiration

        self.hasSeenOnboarding = defaults.bool(forKey: "hasSeenOnboarding")
        self.isPro = defaults.bool(forKey: "isPro")
    }
}
