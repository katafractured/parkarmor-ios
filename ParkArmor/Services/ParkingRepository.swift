import CoreLocation
import SwiftData
import Observation

@Observable final class ParkingRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func saveParking(
        coordinate: CLLocationCoordinate2D,
        address: String,
        notes: String,
        photoData: [Data] = []
    ) throws -> ParkingLocation {
        // Deactivate any currently active locations
        try deactivateAll()

        let location = ParkingLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address,
            notes: notes,
            isActive: true
        )

        for data in photoData {
            let photo = ParkingPhoto(imageData: data)
            location.photos.append(photo)
        }

        context.insert(location)
        try context.save()
        return location
    }

    func fetchActive() throws -> ParkingLocation? {
        let descriptor = FetchDescriptor<ParkingLocation>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }

    func fetchHistory() throws -> [ParkingLocation] {
        let descriptor = FetchDescriptor<ParkingLocation>(
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func deactivateAll() throws {
        let descriptor = FetchDescriptor<ParkingLocation>(
            predicate: #Predicate { $0.isActive }
        )
        let active = try context.fetch(descriptor)
        for location in active {
            location.isActive = false
        }
        if !active.isEmpty {
            try context.save()
        }
    }

    func delete(_ location: ParkingLocation) throws {
        context.delete(location)
        try context.save()
    }

    func togglePin(_ location: ParkingLocation) throws {
        location.isPinned.toggle()
        try context.save()
    }

    func addTimer(to location: ParkingLocation, expiresAt: Date, notificationId: String) throws {
        if let existing = location.timer {
            context.delete(existing)
        }
        let timer = ParkingTimer(
            expiresAt: expiresAt,
            notificationIdentifier: notificationId
        )
        location.timer = timer
        try context.save()
    }

    func clearTimer(from location: ParkingLocation) throws {
        if let timer = location.timer {
            context.delete(timer)
            location.timer = nil
            try context.save()
        }
    }

    func reactivate(_ location: ParkingLocation) throws {
        try deactivateAll()
        location.isActive = true
        try context.save()
    }
}
