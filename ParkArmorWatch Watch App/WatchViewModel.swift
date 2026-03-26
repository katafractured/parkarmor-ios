import CoreLocation
import Foundation
import Observation
import WatchConnectivity
import WidgetKit

@Observable final class WatchViewModel: NSObject {
    private enum SharedKeys {
        static let suiteName = "group.com.katafract.ParkArmor"
        static let activeParkingAddress = "watchActiveParkingAddress"
        static let activeParkingLatitude = "watchActiveParkingLatitude"
        static let activeParkingLongitude = "watchActiveParkingLongitude"
        static let activeParkingSavedAt = "watchActiveParkingSavedAt"
        static let activeParkingTimerExpiresAt = "watchActiveParkingTimerExpiresAt"
        static let userLatitude = "watchUserLatitude"
        static let userLongitude = "watchUserLongitude"
        static let distanceUnit = "distanceUnit"
    }

    var activeParkingSnapshot: WatchParkingSnapshot?
    var userLocation: CLLocation?
    var heading: CLHeading?
    var isSavingParking = false
    var saveError: String?
    var isEndingParking = false
    var endError: String?
    var isPhoneReachable = false

    private let locationManager = CLLocationManager()

    struct WatchParkingSnapshot {
        let latitude: Double
        let longitude: Double
        let address: String
        let savedAt: Date
        let timerExpiresAt: Date?

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var clLocation: CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }

        var elapsedString: String {
            let elapsed = max(0, Date().timeIntervalSince(savedAt))
            let hours = Int(elapsed) / 3600
            let minutes = (Int(elapsed) % 3600) / 60

            if hours > 0 { return "\(hours)h \(minutes)m" }
            if minutes > 0 { return "\(minutes)m" }
            return "Just now"
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        loadPersistedSnapshot()
    }

    func saveParking() {
        guard isPhoneReachable else {
            saveError = "iPhone not in range"
            return
        }
        guard let location = userLocation else {
            saveError = "Location unavailable"
            return
        }

        isSavingParking = true
        saveError = nil

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }

            var address = ""
            if let placemark = placemarks?.first {
                var parts: [String] = []
                if let number = placemark.subThoroughfare, let street = placemark.thoroughfare {
                    parts.append("\(number) \(street)")
                } else if let street = placemark.thoroughfare {
                    parts.append(street)
                }
                if let city = placemark.locality {
                    parts.append(city)
                }
                address = parts.joined(separator: ", ")
            }

            let message: [String: Any] = [
                "action": "saveParking",
                "latitude": location.coordinate.latitude,
                "longitude": location.coordinate.longitude,
                "address": address
            ]

            WCSession.default.sendMessage(message, replyHandler: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.isSavingParking = false
                }
            }, errorHandler: { [weak self] error in
                DispatchQueue.main.async {
                    self?.isSavingParking = false
                    self?.saveError = error.localizedDescription
                }
            })
        }
    }

    func endParking() {
        guard isPhoneReachable else {
            endError = "iPhone not in range"
            return
        }

        isEndingParking = true
        endError = nil

        WCSession.default.sendMessage(["action": "endParking"], replyHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.isEndingParking = false
            }
        }, errorHandler: { [weak self] error in
            DispatchQueue.main.async {
                self?.isEndingParking = false
                self?.endError = error.localizedDescription
            }
        })
    }

    var bearingToParking: Double? {
        guard let parking = activeParkingSnapshot, let userLocation else { return nil }
        return Self.relativeBearing(
            from: userLocation.coordinate,
            to: parking.coordinate,
            heading: heading?.trueHeading
        )
    }

    var distanceToParking: String? {
        guard let parking = activeParkingSnapshot, let userLocation else { return nil }
        return Self.formattedDistance(userLocation.distance(from: parking.clLocation))
    }

    static func relativeBearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D,
        heading: CLLocationDirection?
    ) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let x = sin(dLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(x, y) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        if let heading {
            bearing = (bearing - heading + 360).truncatingRemainder(dividingBy: 360)
        }

        return bearing
    }

    static func formattedDistance(_ meters: CLLocationDistance) -> String {
        if meters < 50 { return "You're here" }
        if meters < 1000 { return "\(Int(meters)) m" }
        return String(format: "%.1f km", meters / 1000)
    }
}

extension WatchViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
        persistSharedState()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

extension WatchViewModel: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            // Prefer the last context pushed from the phone over UserDefaults
            if let parking = session.receivedApplicationContext["activeParking"] as? [String: Any],
               let latitude = parking["latitude"] as? Double,
               let longitude = parking["longitude"] as? Double,
               let address = parking["address"] as? String,
               let savedAtInterval = parking["savedAt"] as? TimeInterval {
                let timerInterval = parking["timerExpiresAt"] as? TimeInterval
                let timerDate = timerInterval.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
                self.activeParkingSnapshot = WatchParkingSnapshot(
                    latitude: latitude,
                    longitude: longitude,
                    address: address,
                    savedAt: Date(timeIntervalSince1970: savedAtInterval),
                    timerExpiresAt: timerDate
                )
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            if let parking = applicationContext["activeParking"] as? [String: Any],
               let latitude = parking["latitude"] as? Double,
               let longitude = parking["longitude"] as? Double,
               let address = parking["address"] as? String,
               let savedAtInterval = parking["savedAt"] as? TimeInterval {
                let timerInterval = parking["timerExpiresAt"] as? TimeInterval
                let timerDate = timerInterval.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
                self.activeParkingSnapshot = WatchParkingSnapshot(
                    latitude: latitude,
                    longitude: longitude,
                    address: address,
                    savedAt: Date(timeIntervalSince1970: savedAtInterval),
                    timerExpiresAt: timerDate
                )
            } else {
                self.activeParkingSnapshot = nil
            }
            self.persistSharedState()
        }
    }
}

private extension WatchViewModel {
    func loadPersistedSnapshot() {
        guard let defaults = UserDefaults(suiteName: SharedKeys.suiteName),
              let address = defaults.string(forKey: SharedKeys.activeParkingAddress) else { return }
        let latitude = defaults.double(forKey: SharedKeys.activeParkingLatitude)
        let longitude = defaults.double(forKey: SharedKeys.activeParkingLongitude)
        let savedAt = defaults.double(forKey: SharedKeys.activeParkingSavedAt)
        guard savedAt > 0 else { return }
        let timerInterval = defaults.double(forKey: SharedKeys.activeParkingTimerExpiresAt)
        let timerDate = timerInterval > 0 ? Date(timeIntervalSince1970: timerInterval) : nil
        activeParkingSnapshot = WatchParkingSnapshot(
            latitude: latitude,
            longitude: longitude,
            address: address,
            savedAt: Date(timeIntervalSince1970: savedAt),
            timerExpiresAt: timerDate
        )
    }

    func persistSharedState() {
        guard let defaults = UserDefaults(suiteName: SharedKeys.suiteName) else { return }

        if let activeParkingSnapshot {
            defaults.set(activeParkingSnapshot.address, forKey: SharedKeys.activeParkingAddress)
            defaults.set(activeParkingSnapshot.latitude, forKey: SharedKeys.activeParkingLatitude)
            defaults.set(activeParkingSnapshot.longitude, forKey: SharedKeys.activeParkingLongitude)
            defaults.set(activeParkingSnapshot.savedAt.timeIntervalSince1970, forKey: SharedKeys.activeParkingSavedAt)
            defaults.set(activeParkingSnapshot.timerExpiresAt?.timeIntervalSince1970 ?? 0, forKey: SharedKeys.activeParkingTimerExpiresAt)
        } else {
            defaults.removeObject(forKey: SharedKeys.activeParkingAddress)
            defaults.removeObject(forKey: SharedKeys.activeParkingLatitude)
            defaults.removeObject(forKey: SharedKeys.activeParkingLongitude)
            defaults.removeObject(forKey: SharedKeys.activeParkingSavedAt)
            defaults.removeObject(forKey: SharedKeys.activeParkingTimerExpiresAt)
        }

        if let userLocation {
            defaults.set(userLocation.coordinate.latitude, forKey: SharedKeys.userLatitude)
            defaults.set(userLocation.coordinate.longitude, forKey: SharedKeys.userLongitude)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }
}
