import CoreLocation
import Testing
@testable import ParkArmor

// MARK: - Date.formatElapsed

@Suite("Date.formatElapsed")
struct DateFormatElapsedTests {
    @Test func secondsOnly() {
        #expect(Date.formatElapsed(45) == "45s")
    }

    @Test func minutesOnly() {
        #expect(Date.formatElapsed(90) == "1m")
        #expect(Date.formatElapsed(3599) == "59m")
    }

    @Test func hoursAndMinutes() {
        #expect(Date.formatElapsed(3600) == "1h 0m")
        #expect(Date.formatElapsed(5400) == "1h 30m")
        #expect(Date.formatElapsed(7261) == "2h 1m")
    }

    @Test func zero() {
        #expect(Date.formatElapsed(0) == "0s")
    }

    @Test func negativeClampedToZero() {
        #expect(Date.formatElapsed(-100) == "0s")
    }
}

// MARK: - Date.elapsedString

@Suite("Date.elapsedString")
struct DateElapsedStringTests {
    @Test func recentDate() {
        let now = Date()
        let past = now.addingTimeInterval(-120)
        #expect(past.elapsedString(since: now) == "2m")
    }

    @Test func futureDate_clampedToZero() {
        let now = Date()
        let future = now.addingTimeInterval(300)
        #expect(future.elapsedString(since: now) == "0s")
    }
}

// MARK: - Date.timeRemainingString

@Suite("Date.timeRemainingString")
struct DateTimeRemainingTests {
    @Test func expired() {
        let past = Date().addingTimeInterval(-60)
        #expect(past.timeRemainingString() == "Expired")
    }

    @Test func future() {
        let future = Date().addingTimeInterval(90)
        // Returns "Xm remaining" — just verify suffix
        #expect(future.timeRemainingString().hasSuffix("remaining"))
    }
}

// MARK: - DistanceUnit.formatted

@Suite("DistanceUnit.formatted")
struct DistanceUnitTests {
    @Test func milesLargeDistance() {
        let result = DistanceUnit.miles.formatted(1609.344)
        #expect(result == "1.0 mi")
    }

    @Test func milesShortDistance() {
        let result = DistanceUnit.miles.formatted(30)
        // 30m * 3.28084 = 98ft
        #expect(result.hasSuffix("ft"))
    }

    @Test func kilometersLargeDistance() {
        let result = DistanceUnit.kilometers.formatted(2000)
        #expect(result == "2.0 km")
    }

    @Test func kilometersShortDistance() {
        let result = DistanceUnit.kilometers.formatted(500)
        #expect(result == "500 m")
    }
}

// MARK: - CLLocationCoordinate2D.bearing

@Suite("CLLocationCoordinate2D.bearing")
struct BearingTests {
    @Test func northBearing() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        let bearing = from.bearing(to: to)
        #expect(abs(bearing - 0.0) < 1.0 || abs(bearing - 360.0) < 1.0)
    }

    @Test func eastBearing() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        let bearing = from.bearing(to: to)
        #expect(abs(bearing - 90.0) < 1.0)
    }

    @Test func southBearing() {
        let from = CLLocationCoordinate2D(latitude: 1, longitude: 0)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let bearing = from.bearing(to: to)
        #expect(abs(bearing - 180.0) < 1.0)
    }

    @Test func westBearing() {
        let from = CLLocationCoordinate2D(latitude: 0, longitude: 1)
        let to = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let bearing = from.bearing(to: to)
        #expect(abs(bearing - 270.0) < 1.0)
    }

    @Test func bearingIsInRange() {
        let from = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let to = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        let bearing = from.bearing(to: to)
        #expect(bearing >= 0 && bearing < 360)
    }
}

// MARK: - Double.cardinalDirection

@Suite("Double.cardinalDirection")
struct CardinalDirectionTests {
    @Test func north() {
        #expect((0.0).cardinalDirection == "N")
        #expect((360.0 - 1).cardinalDirection == "N")
    }

    @Test func northeast() {
        #expect((45.0).cardinalDirection == "NE")
    }

    @Test func east() {
        #expect((90.0).cardinalDirection == "E")
    }

    @Test func south() {
        #expect((180.0).cardinalDirection == "S")
    }

    @Test func west() {
        #expect((270.0).cardinalDirection == "W")
    }
}

// MARK: - CLLocationCoordinate2D.distance

@Suite("CLLocationCoordinate2D.distance")
struct CoordinateDistanceTests {
    @Test func samePoint() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        #expect(coord.distance(to: coord) < 1.0)
    }

    @Test func knownDistance() {
        // SF to LA: roughly 560km
        let sf = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let la = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)
        let dist = sf.distance(to: la)
        #expect(dist > 550_000 && dist < 620_000)
    }
}
