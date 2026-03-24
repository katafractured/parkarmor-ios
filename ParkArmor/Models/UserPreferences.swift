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

@Observable final class UserPreferences {
    private let defaults: UserDefaults

    init() {
        self.defaults = UserDefaults(suiteName: "group.com.katafract.ParkArmor") ?? .standard
    }

    var distanceUnit: DistanceUnit {
        get {
            let raw = defaults.string(forKey: "distanceUnit") ?? DistanceUnit.miles.rawValue
            return DistanceUnit(rawValue: raw) ?? .miles
        }
        set { defaults.set(newValue.rawValue, forKey: "distanceUnit") }
    }

    var timeFormat: TimeFormat {
        get {
            let raw = defaults.string(forKey: "timeFormat") ?? TimeFormat.elapsed.rawValue
            return TimeFormat(rawValue: raw) ?? .elapsed
        }
        set { defaults.set(newValue.rawValue, forKey: "timeFormat") }
    }

    var notificationsEnabled: Bool {
        get { defaults.object(forKey: "notificationsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "notificationsEnabled") }
    }

    var timerAlertMode: TimerAlertMode {
        get {
            let raw = defaults.string(forKey: "timerAlertMode") ?? TimerAlertMode.atExpiration.rawValue
            return TimerAlertMode(rawValue: raw) ?? .atExpiration
        }
        set { defaults.set(newValue.rawValue, forKey: "timerAlertMode") }
    }

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: "hasSeenOnboarding") }
        set { defaults.set(newValue, forKey: "hasSeenOnboarding") }
    }

    var isPro: Bool {
        get { defaults.bool(forKey: "isPro") }
        set { defaults.set(newValue, forKey: "isPro") }
    }
}
