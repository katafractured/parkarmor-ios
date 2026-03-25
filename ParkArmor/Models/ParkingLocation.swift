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
    var isFavorite: Bool
    /// Optional user-assigned name, e.g. "Work Garage" or "Airport Terminal B".
    var nickname: String?

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
        self.isFavorite = false
        self.photos = []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Primary display label — shows nickname if set, otherwise the geocoded address.
    var displayAddress: String {
        if let nick = nickname, !nick.trimmingCharacters(in: .whitespaces).isEmpty {
            return nick
        }
        return address.isEmpty ? String(format: "%.4f°, %.4f°", latitude, longitude) : address
    }

    /// Always returns the raw geocoded address (for sub-labels showing the actual street).
    var rawAddress: String {
        address.isEmpty ? String(format: "%.4f°, %.4f°", latitude, longitude) : address
    }
}
