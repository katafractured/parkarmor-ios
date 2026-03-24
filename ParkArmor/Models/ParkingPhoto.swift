import Foundation
import SwiftData

@Model final class ParkingPhoto {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data
    var caption: String
    var capturedAt: Date
    var location: ParkingLocation?

    init(imageData: Data, caption: String = "") {
        self.id = UUID()
        self.imageData = imageData
        self.caption = caption
        self.capturedAt = Date()
    }
}
