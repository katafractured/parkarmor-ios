import CoreLocation
import Foundation
import Testing
@testable import ParkArmor

// MARK: - ParkingLocation computed properties

@Suite("ParkingLocation")
struct ParkingLocationTests {
    @Test func displayAddressUsesNickname() {
        let location = ParkingLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            address: "123 Main St, San Francisco"
        )
        location.nickname = "Work Garage"
        #expect(location.displayAddress == "Work Garage")
    }

    @Test func displayAddressFallsBackToAddress() {
        let location = ParkingLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            address: "123 Main St, San Francisco"
        )
        #expect(location.displayAddress == "123 Main St, San Francisco")
    }

    @Test func displayAddressUsesCoordinateWhenBothEmpty() {
        let location = ParkingLocation(latitude: 37.7749, longitude: -122.4194)
        location.nickname = "   "
        #expect(location.displayAddress.contains("37.7749"))
        #expect(location.displayAddress.contains("-122.4194"))
    }

    @Test func rawAddressIgnoresNickname() {
        let location = ParkingLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            address: "456 Oak Ave"
        )
        location.nickname = "Airport Lot B"
        #expect(location.rawAddress == "456 Oak Ave")
    }

    @Test func rawAddressUsesCoordinatesWhenEmpty() {
        let location = ParkingLocation(latitude: 10.0, longitude: 20.0)
        #expect(location.rawAddress.contains("10.0000"))
        #expect(location.rawAddress.contains("20.0000"))
    }

    @Test func coordinateMatchesStoredValues() {
        let location = ParkingLocation(latitude: 37.7749, longitude: -122.4194)
        #expect(location.coordinate.latitude == 37.7749)
        #expect(location.coordinate.longitude == -122.4194)
    }

    @Test func clLocationMatchesStoredValues() {
        let location = ParkingLocation(latitude: 37.7749, longitude: -122.4194)
        #expect(location.clLocation.coordinate.latitude == 37.7749)
        #expect(location.clLocation.coordinate.longitude == -122.4194)
    }

    @Test func defaultsOnInit() {
        let location = ParkingLocation(latitude: 0, longitude: 0)
        #expect(location.isActive == true)
        #expect(location.isPinned == false)
        #expect(location.isFavorite == false)
        #expect(location.photos.isEmpty)
        #expect(location.timer == nil)
        #expect(location.nickname == nil)
        #expect(location.notes.isEmpty)
    }
}

// MARK: - ParkingTimer computed properties

@Suite("ParkingTimer")
struct ParkingTimerTests {
    @Test func notExpiredWhenFuture() {
        let timer = ParkingTimer(expiresAt: Date().addingTimeInterval(3600))
        #expect(timer.isExpired == false)
    }

    @Test func expiredWhenPast() {
        let timer = ParkingTimer(expiresAt: Date().addingTimeInterval(-1))
        #expect(timer.isExpired == true)
    }

    @Test func timeRemainingIsPositiveWhenFuture() {
        let timer = ParkingTimer(expiresAt: Date().addingTimeInterval(3600))
        #expect(timer.timeRemaining > 0)
        #expect(timer.timeRemaining <= 3600)
    }

    @Test func timeRemainingIsZeroWhenExpired() {
        let timer = ParkingTimer(expiresAt: Date().addingTimeInterval(-60))
        #expect(timer.timeRemaining == 0)
    }

    @Test func defaultLabelIsParking() {
        let timer = ParkingTimer(expiresAt: Date())
        #expect(timer.label == "Parking Meter")
    }
}
