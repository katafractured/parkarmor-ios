import AppIntents
import Foundation

struct ExtendTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Extend Timer"
    static let description = IntentDescription("Add 15 minutes to the parking timer")
    static let isDiscoverable = false
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Post a notification to the main app
        // The main app uses NotificationCenter to observe this
        NotificationCenter.default.post(
            name: Notification.Name("com.katafract.ParkArmor.extendTimerFromWidget"),
            object: nil,
            userInfo: ["minutes": 15]
        )
        
        return .result()
    }
}
