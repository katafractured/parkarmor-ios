//
//  ParkArmorWatch_Watch_AppTests.swift
//  ParkArmorWatch Watch AppTests
//
//  Created by Christian Flores on 3/25/26.
//

import CoreLocation
import XCTest
@testable import ParkArmorWatch_Watch_App

final class ParkArmorWatch_Watch_AppTests: XCTestCase {
    func testFormattedDistanceUsesHereThreshold() {
        XCTAssertEqual(WatchViewModel.formattedDistance(12), "You're here")
    }

    func testFormattedDistanceUsesMetersUnderOneKilometer() {
        XCTAssertEqual(WatchViewModel.formattedDistance(320), "320 m")
    }

    func testFormattedDistanceUsesKilometersAtDistance() {
        XCTAssertEqual(WatchViewModel.formattedDistance(1500), "1.5 km")
    }

    func testRelativeBearingAccountsForHeading() {
        let from = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let to = CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4194)
        let bearing = WatchViewModel.relativeBearing(from: from, to: to, heading: 30)

        XCTAssertEqual(bearing, 330, accuracy: 5)
    }

    func testElapsedStringReturnsHoursAndMinutes() {
        let snapshot = WatchViewModel.WatchParkingSnapshot(
            latitude: 37.7749,
            longitude: -122.4194,
            address: "123 Main St",
            savedAt: Date().addingTimeInterval(-(2 * 3600 + 15 * 60)),
            timerExpiresAt: nil
        )

        XCTAssertEqual(snapshot.elapsedString, "2h 15m")
    }
}
