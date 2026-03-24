import ActivityKit
import Foundation

struct ParkingTimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var expiresAt: Date
        var address: String
    }

    var parkingID: UUID
    var savedAt: Date
}
