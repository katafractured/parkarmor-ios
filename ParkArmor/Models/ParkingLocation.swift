import Foundation
import CoreLocation
import SwiftData

@Model final class ParkingLocation {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var address: String
    var notes: String
    var savedAt: Date
    var isActive: Bool
    var isPinned: Bool

    @Relationship(deleteRule: .cascade, inverse: \ParkingPhoto.location)
    var photos: [ParkingPhoto]

    @Relationship(deleteRule: .cascade, inverse: \ParkingTimer.location)
    var timer: ParkingTimer?

    init(
        latitude: Double,
        longitude: Double,
        address: String = "",
        notes: String = "",
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.notes = notes
        self.savedAt = Date()
        self.isActive = isActive
        self.isPinned = false
        self.photos = []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var displayAddress: String {
        address.isEmpty ? String(format: "%.4f°, %.4f°", latitude, longitude) : address
    }
}
