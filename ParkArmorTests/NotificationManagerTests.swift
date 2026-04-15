import Foundation
import Testing
import UserNotifications
@testable import ParkArmor

@Suite("NotificationManager — body copy")
struct NotificationManagerBodyTests {
    let manager = NotificationManager()

    // MARK: At-expiration body

    @Test func bodyAtExpirationWithLocationName() {
        let body = manager.notificationBody(locationName: "City Lot", minutesBefore: nil)
        #expect(body == "Meter at City Lot is about to expire.")
    }

    @Test func bodyAtExpirationWithoutLocationName() {
        let body = manager.notificationBody(locationName: "", minutesBefore: nil)
        #expect(body == "Your parking meter is about to expire.")
    }

    // MARK: Reminder body

    @Test func bodyReminderWithLocationName() {
        let body = manager.notificationBody(locationName: "Airport Lot B", minutesBefore: 15)
        #expect(body == "Meter at Airport Lot B expires in 15 minutes.")
    }

    @Test func bodyReminderWithoutLocationName() {
        let body = manager.notificationBody(locationName: "", minutesBefore: 15)
        #expect(body == "Your parking meter expires in 15 minutes.")
    }

    @Test func bodyReminderOneMinute() {
        let body = manager.notificationBody(locationName: "A", minutesBefore: 1)
        #expect(body.contains("1 minutes"))
    }
}

@Suite("NotificationManager — identifier format")
struct NotificationManagerIdentifierTests {
    let manager = NotificationManager()

    @Test func identifierContainsParkingId() {
        let id = UUID()
        let identifier = manager.notificationIdentifier(for: id, suffix: 0)
        #expect(identifier.contains(id.uuidString))
    }

    @Test func identifierContainsSuffix() {
        let id = UUID()
        let identifier = manager.notificationIdentifier(for: id, suffix: 900)
        #expect(identifier.contains("900"))
    }

    @Test func identifierHasPrefix() {
        let id = UUID()
        let identifier = manager.notificationIdentifier(for: id, suffix: 0)
        #expect(identifier.hasPrefix("parking-timer-"))
    }

    @Test func differentSuffixesProduceDifferentIdentifiers() {
        let id = UUID()
        let a = manager.notificationIdentifier(for: id, suffix: 0)
        let b = manager.notificationIdentifier(for: id, suffix: 900)
        #expect(a != b)
    }
}

@Suite("NotificationManager — authorization state")
struct NotificationManagerAuthTests {
    @Test func isAuthorizedWhenAuthorized() {
        let manager = NotificationManager()
        // Can't force authorization in tests; verify default state
        let result = manager.isAuthorized
        // notDetermined → false
        #expect(result == (manager.authorizationStatus == .authorized || manager.authorizationStatus == .provisional))
    }

    @Test func cancelNotificationWithEmptyIdentifierIsNoOp() {
        let manager = NotificationManager()
        // Should not crash on empty or comma-only identifiers
        manager.cancelNotification(identifier: "")
        manager.cancelNotification(identifier: ",,,")
    }
}
