import Foundation

struct ScreenshotMode {
    static let isEnabled = CommandLine.arguments.contains("-ScreenshotMode")

    static func seedDataIfEnabled() {
        guard isEnabled else { return }

        // Inject fake parking session into AppState or relevant service
        let fakeParkingSession = ParkingSession(
            id: UUID(),
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            address: "Level 3B, Union Square Parking",
            startTime: Date().addingTimeInterval(-120), // 2 min ago
            duration: 30 * 60, // 30 minutes total
            notes: "Level 3B, near elevator",
            photoURL: nil // Use placeholder in UI if nil
        )

        // Expose via environment or singleton
        AppState.shared.currentParkingSession = fakeParkingSession
        AppState.shared.isPro = true // Enable Pro features for screenshots
        AppState.shared.hasAdRemoval = true
    }
}

// Example ParkingSession model (adjust to match your actual model)
struct ParkingSession: Identifiable, Codable {
    let id: UUID
    let location: CLLocationCoordinate2D
    let address: String
    let startTime: Date
    let duration: TimeInterval
    let notes: String
    let photoURL: URL?

    var secondsRemaining: Int {
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, Int(duration - elapsed))
    }

    var formattedTimeRemaining: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
