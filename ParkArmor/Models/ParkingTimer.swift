import Foundation
import SwiftData

@Model final class ParkingTimer {
    var id: UUID
    var expiresAt: Date
    var notificationIdentifier: String
    var label: String
    var location: ParkingLocation?

    init(expiresAt: Date, notificationIdentifier: String = "", label: String = "Parking Meter") {
        self.id = UUID()
        self.expiresAt = expiresAt
        self.notificationIdentifier = notificationIdentifier
        self.label = label
    }

    var isExpired: Bool {
        Date() >= expiresAt
    }

    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }
}
