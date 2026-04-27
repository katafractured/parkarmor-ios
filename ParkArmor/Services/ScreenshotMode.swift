import Foundation
import CoreLocation

struct ScreenshotMode {
    static let isEnabled = CommandLine.arguments.contains("-ScreenshotMode")

    static func seedDataIfEnabled() {
        guard isEnabled else { return }

        // FIXME: Screenshot seeding is not yet wired to AppViewModel.
        // To enable screenshot mode, inject a ParkingLocation record directly
        // into the SwiftData ModelContext before app launch, or mock at startup.
    }
}
