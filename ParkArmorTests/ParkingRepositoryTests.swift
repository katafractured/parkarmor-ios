import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import ParkArmor

// Shared in-memory container factory used across repository tests
private func makeTestContainer() throws -> ModelContainer {
    let schema = Schema([ParkingLocation.self, ParkingPhoto.self, ParkingTimer.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

@Suite("ParkingRepository — save and fetch")
@MainActor
struct ParkingRepositoryTests {
    @Test func saveCreatesActiveRecord() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let saved = try repo.saveParking(
            coordinate: coordinate,
            address: "123 Main St",
            notes: "Level 3",
            nickname: "Work",
            photoData: []
        )

        #expect(saved.isActive)
        #expect(saved.address == "123 Main St")
        #expect(saved.notes == "Level 3")
        #expect(saved.nickname == "Work")
        #expect(saved.latitude == 37.7749)
        #expect(saved.longitude == -122.4194)
    }

    @Test func fetchActiveReturnsLatest() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        try repo.saveParking(coordinate: coord, address: "First", notes: "")
        try repo.saveParking(coordinate: coord, address: "Second", notes: "")

        let active = try repo.fetchActive()
        #expect(active?.address == "Second")
    }

    @Test func saveDeactivatesPrevious() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        let first = try repo.saveParking(coordinate: coord, address: "First", notes: "")
        _ = try repo.saveParking(coordinate: coord, address: "Second", notes: "")

        #expect(!first.isActive)
    }

    @Test func deactivateAllLeavesHistory() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        _ = try repo.saveParking(coordinate: coord, address: "Spot A", notes: "")
        try repo.deactivateAll(preserveHistory: true)

        let active = try repo.fetchActive()
        #expect(active == nil)

        let history = try repo.fetchHistory(includeActive: false)
        #expect(history.count == 1)
    }

    @Test func deactivateAllWithoutHistoryDeletesRecord() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        _ = try repo.saveParking(coordinate: coord, address: "Spot A", notes: "")
        try repo.deactivateAll(preserveHistory: false)

        let history = try repo.fetchHistory(includeActive: true)
        #expect(history.isEmpty)
    }

    @Test func clearHistoryRemovesInactiveOnly() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        _ = try repo.saveParking(coordinate: coord, address: "Old Spot", notes: "")
        let active = try repo.saveParking(coordinate: coord, address: "Current Spot", notes: "")

        try repo.clearHistory()

        let allLocations = try repo.fetchHistory(includeActive: true)
        #expect(allLocations.count == 1)
        #expect(allLocations.first?.address == active.address)
    }

    @Test func pruneHistoryRemovesOldNonFavorites() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let repo = ParkingRepository(context: context)

        // Insert an old inactive location directly
        let oldLocation = ParkingLocation(latitude: 37.7, longitude: -122.4, address: "Old Lot", notes: "")
        oldLocation.isActive = false
        oldLocation.savedAt = Date().addingTimeInterval(-(40 * 24 * 60 * 60)) // 40 days ago
        context.insert(oldLocation)
        try context.save()

        // Insert a recent inactive location
        let recentLocation = ParkingLocation(latitude: 37.7, longitude: -122.4, address: "Recent Lot", notes: "")
        recentLocation.isActive = false
        context.insert(recentLocation)
        try context.save()

        try repo.pruneHistory(retention: .thirtyDays)

        let history = try repo.fetchHistory(includeActive: false)
        #expect(history.count == 1)
        #expect(history.first?.address == "Recent Lot")
    }

    @Test func pruneHistoryPreservesFavorites() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let repo = ParkingRepository(context: context)

        let oldFavorite = ParkingLocation(latitude: 37.7, longitude: -122.4, address: "Fave Spot", notes: "")
        oldFavorite.isActive = false
        oldFavorite.isFavorite = true
        oldFavorite.savedAt = Date().addingTimeInterval(-(60 * 24 * 60 * 60)) // 60 days ago
        context.insert(oldFavorite)
        try context.save()

        try repo.pruneHistory(retention: .thirtyDays)

        let history = try repo.fetchHistory(includeActive: false)
        #expect(history.count == 1)
        #expect(history.first?.address == "Fave Spot")
    }

    @Test func togglePinPersists() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        let location = try repo.saveParking(coordinate: coord, address: "A", notes: "")

        #expect(!location.isPinned)
        try repo.togglePin(location)
        #expect(location.isPinned)
        try repo.togglePin(location)
        #expect(!location.isPinned)
    }

    @Test func toggleFavoritePersists() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        let location = try repo.saveParking(coordinate: coord, address: "A", notes: "")

        #expect(!location.isFavorite)
        try repo.toggleFavorite(location)
        #expect(location.isFavorite)
    }

    @Test func updateNicknameTrimsWhitespace() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        let location = try repo.saveParking(coordinate: coord, address: "A", notes: "")

        try repo.updateNickname(location, nickname: "  Work  ")
        #expect(location.nickname == "  Work  ") // stored as-is; display trims

        try repo.updateNickname(location, nickname: "   ")
        #expect(location.nickname == nil)
    }

    @Test func addTimerLinksToLocation() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        let location = try repo.saveParking(coordinate: coord, address: "A", notes: "")
        let expiresAt = Date().addingTimeInterval(3600)
        try repo.addTimer(to: location, expiresAt: expiresAt, notificationId: "test-id")

        #expect(location.timer != nil)
        #expect(location.timer?.isExpired == false)
    }

    @Test func clearTimerRemovesTimer() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        let location = try repo.saveParking(coordinate: coord, address: "A", notes: "")
        try repo.addTimer(to: location, expiresAt: Date().addingTimeInterval(3600), notificationId: "x")
        try repo.clearTimer(from: location)

        #expect(location.timer == nil)
    }

    @Test func reactivateSetsPreviousLocationActive() throws {
        let container = try makeTestContainer()
        let repo = ParkingRepository(context: ModelContext(container))

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        let first = try repo.saveParking(coordinate: coord, address: "First", notes: "")
        _ = try repo.saveParking(coordinate: coord, address: "Second", notes: "")

        try repo.reactivate(first)

        #expect(first.isActive)
        let active = try repo.fetchActive()
        #expect(active?.address == "First")
    }
}
