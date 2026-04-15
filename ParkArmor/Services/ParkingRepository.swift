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
        nickname: String? = nil,
        photoData: [Data] = [],
        preserveHistory: Bool = true
    ) throws -> ParkingLocation {
        // Deactivate any currently active locations
        try deactivateAll(preserveHistory: preserveHistory)

        let location = ParkingLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address,
            notes: notes,
            isActive: true
        )
        if let nick = nickname, !nick.trimmingCharacters(in: .whitespaces).isEmpty {
            location.nickname = nick
        }

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

    func fetchHistory(includeActive: Bool = false) throws -> [ParkingLocation] {
        let descriptor = FetchDescriptor<ParkingLocation>(
            predicate: #Predicate<ParkingLocation> { location in
                includeActive || !location.isActive
            },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func deactivateAll(preserveHistory: Bool = true) throws {
        let descriptor = FetchDescriptor<ParkingLocation>(
            predicate: #Predicate { $0.isActive }
        )
        let active = try context.fetch(descriptor)
        for location in active {
            if preserveHistory {
                location.isActive = false
            } else {
                context.delete(location)
            }
        }
        if !active.isEmpty {
            try context.save()
        }
    }

    func delete(_ location: ParkingLocation) throws {
        context.delete(location)
        try context.save()
    }

    func updateNickname(_ location: ParkingLocation, nickname: String?) throws {
        location.nickname = nickname?.trimmingCharacters(in: .whitespaces).isEmpty == true ? nil : nickname
        try context.save()
    }

    func togglePin(_ location: ParkingLocation) throws {
        location.isPinned.toggle()
        try context.save()
    }

    func toggleFavorite(_ location: ParkingLocation) throws {
        location.isFavorite.toggle()
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

    @discardableResult
    func saveSuggested(coordinate: CLLocationCoordinate2D, address: String) throws -> ParkingLocation {
        let location = ParkingLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address,
            notes: "",
            isActive: false
        )
        location.isSuggested = true
        context.insert(location)
        try context.save()
        return location
    }

    func confirmSuggested(_ location: ParkingLocation) throws {
        location.isSuggested = false
        try context.save()
    }

    func reactivate(_ location: ParkingLocation) throws {
        try deactivateAll()
        location.isActive = true
        try context.save()
    }

    func clearHistory() throws {
        let history = try fetchHistory(includeActive: false)
        for location in history {
            context.delete(location)
        }
        if !history.isEmpty {
            try context.save()
        }
    }

    func pruneHistory(retention: HistoryRetentionOption) throws {
        guard let cutoffDate = retention.cutoffDate else { return }

        let history = try fetchHistory(includeActive: false)
        let staleLocations = history.filter {
            !$0.isFavorite && $0.savedAt < cutoffDate
        }

        for location in staleLocations {
            context.delete(location)
        }

        if !staleLocations.isEmpty {
            try context.save()
        }
    }

    func extendTimer(on location: ParkingLocation, byMinutes minutes: Int) throws {
        guard let timer = location.timer else { return }
        let newExpiresAt = timer.expiresAt.addingTimeInterval(Double(minutes) * 60)
        timer.expiresAt = newExpiresAt
        try context.save()
    }
}
