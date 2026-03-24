import UserNotifications
import Observation

@Observable final class NotificationManager {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init() {
        Task { await refreshStatus() }
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
            return granted
        } catch {
            return false
        }
    }

    func scheduleNotification(
        expiresAt: Date,
        locationName: String,
        parkingId: UUID
    ) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = "Parking Meter Expiring"
        content.body = locationName.isEmpty
            ? "Your parking meter is about to expire."
            : "Meter at \(locationName) is about to expire."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: expiresAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "parking-timer-\(parkingId.uuidString)"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
        return identifier
    }

    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [identifier]
        )
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }
}
