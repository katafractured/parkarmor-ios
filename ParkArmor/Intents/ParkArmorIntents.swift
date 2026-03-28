import AppIntents
import CoreLocation
import Foundation
import MapKit
import SwiftData

struct SaveParkingIntent: AppIntent {
    static let title: LocalizedStringResource = "Save Parking Spot"
    static let description = IntentDescription("Save your current location as your parking spot.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        let fetcher = IntentLocationFetcher()
        let coordinate = try await fetcher.fetchCoordinate()
        let address = await reverseGeocodeAddress(for: coordinate)

        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.katafract.ParkArmor"
        ) else {
            throw IntentError.locationUnavailable
        }

        let storeURL = groupURL.appendingPathComponent("parkarmor.store")
        let schema = Schema([ParkingLocation.self, ParkingPhoto.self, ParkingTimer.self])
        let config = ModelConfiguration(nil, schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<ParkingLocation>(predicate: #Predicate { $0.isActive })
        let existing = try context.fetch(descriptor)
        let saveParkingHistory = UserDefaults(suiteName: "group.com.katafract.ParkArmor")?.bool(forKey: "saveParkingHistory") ?? true

        for location in existing {
            if saveParkingHistory {
                location.isActive = false
            } else {
                context.delete(location)
            }
        }

        let newLocation = ParkingLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: address,
            notes: "",
            isActive: true
        )
        context.insert(newLocation)
        try context.save()

        let displayAddress = address.isEmpty ? "your current location" : address
        return .result(
            value: displayAddress,
            dialog: "Parking spot saved at \(displayAddress)."
        )
    }

    private func reverseGeocodeAddress(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return "" }
            let mapItems = await withCheckedContinuation { continuation in
                request.getMapItems { items, _ in
                    continuation.resume(returning: items ?? [])
                }
            }
            guard let mapItem = mapItems.first else { return "" }
            return mapItem.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) ?? ""
        }

        let geocoder = CLGeocoder()
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return ""
        }

        var parts: [String] = []
        if let number = placemark.subThoroughfare, let street = placemark.thoroughfare {
            parts.append("\(number) \(street)")
        } else if let street = placemark.thoroughfare {
            parts.append(street)
        }
        if let city = placemark.locality {
            parts.append(city)
        }
        return parts.joined(separator: ", ")
    }

    enum IntentError: Error, LocalizedError {
        case locationUnavailable

        var errorDescription: String? {
            "Could not get your current location."
        }
    }
}

struct FindCarIntent: AppIntent {
    static let title: LocalizedStringResource = "Where's My Car?"
    static let description = IntentDescription("Find out where you parked your car.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some ReturnsValue<String> & ProvidesDialog {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.katafract.ParkArmor"
        ) else {
            return .result(value: "Unknown", dialog: "No parking spot saved.")
        }

        let storeURL = groupURL.appendingPathComponent("parkarmor.store")
        let schema = Schema([ParkingLocation.self, ParkingPhoto.self, ParkingTimer.self])
        let config = ModelConfiguration(nil, schema: schema, url: storeURL, allowsSave: false)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ParkingLocation>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )

        guard let location = try context.fetch(descriptor).first else {
            return .result(value: "No active parking", dialog: "You don't have an active parking spot saved.")
        }

        let elapsed = Date().timeIntervalSince(location.savedAt)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let elapsedString: String
        if hours > 0 {
            elapsedString = "\(hours) hours and \(minutes) minutes ago"
        } else if minutes > 0 {
            elapsedString = "\(minutes) minutes ago"
        } else {
            elapsedString = "just now"
        }

        let address = location.displayAddress
        let dialog: String
        if let timer = location.timer, !timer.isExpired {
            let remaining = timer.expiresAt.timeIntervalSinceNow
            let timerHours = Int(remaining) / 3600
            let timerMinutes = (Int(remaining) % 3600) / 60
            let timerString = timerHours > 0
                ? "\(timerHours) hours and \(timerMinutes) minutes"
                : "\(timerMinutes) minutes"
            dialog = "Your car is parked at \(address), saved \(elapsedString). Your meter has \(timerString) remaining."
        } else {
            dialog = "Your car is parked at \(address), saved \(elapsedString)."
        }

        return .result(value: address, dialog: "\(dialog)")
    }
}

struct ParkArmorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveParkingIntent(),
            phrases: [
                "Save my parking spot with \(.applicationName)",
                "Park here with \(.applicationName)",
                "Save parking with \(.applicationName)",
                "I just parked with \(.applicationName)"
            ],
            shortTitle: "Save Parking Spot",
            systemImageName: "car.fill"
        )
        AppShortcut(
            intent: FindCarIntent(),
            phrases: [
                "Where's my car with \(.applicationName)",
                "Where did I park with \(.applicationName)",
                "Find my car with \(.applicationName)",
                "Where is my parking spot with \(.applicationName)"
            ],
            shortTitle: "Where's My Car?",
            systemImageName: "location.fill"
        )
    }
}

private final class IntentLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func fetchCoordinate() async throws -> CLLocationCoordinate2D {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: location.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
