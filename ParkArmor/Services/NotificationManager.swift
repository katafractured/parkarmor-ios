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
        parkingId: UUID,
        alertMode: TimerAlertMode
    ) async throws -> String {
        var identifiers: [String] = []

        for offset in alertMode.offsets {
            let fireDate = expiresAt.addingTimeInterval(-offset)
            guard fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = offset == 0 ? "Parking Meter Expiring" : "Parking Meter Reminder"
            content.body = notificationBody(
                locationName: locationName,
                minutesBefore: offset == 0 ? nil : Int(offset / 60)
            )
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = notificationIdentifier(for: parkingId, suffix: Int(offset))

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )
            try await UNUserNotificationCenter.current().add(request)
            identifiers.append(identifier)
        }

        return identifiers.joined(separator: ",")
    }

    func cancelNotification(identifier: String) {
        let identifiers = identifier
            .split(separator: ",")
            .map(String.init)
            .filter { !$0.isEmpty }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: identifiers
        )
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    private func notificationBody(locationName: String, minutesBefore: Int?) -> String {
        if let minutesBefore {
            if locationName.isEmpty {
                return "Your parking meter expires in \(minutesBefore) minutes."
            }
            return "Meter at \(locationName) expires in \(minutesBefore) minutes."
        }

        if locationName.isEmpty {
            return "Your parking meter is about to expire."
        }
        return "Meter at \(locationName) is about to expire."
    }

    private func notificationIdentifier(for parkingId: UUID, suffix: Int) -> String {
        "parking-timer-\(parkingId.uuidString)-\(suffix)"
    }
}
