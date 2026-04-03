import CoreLocation
import Foundation
import Observation
import WatchConnectivity
import WidgetKit

@Observable final class WatchViewModel: NSObject {
    enum SyncState {
        case syncing
        case live
        case cached
    }

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
        static let watchSyncState = "watchSyncState"
    }

    var activeParkingSnapshot: WatchParkingSnapshot?
    var userLocation: CLLocation?
    var heading: CLHeading?
    var isSavingParking = false
    var saveError: String?
    var isEndingParking = false
    var endError: String?
    var isPhoneReachable = false
    var statusMessage: String?
    var syncState: SyncState = .syncing
    /// Timestamp of the last application context written by the phone.
    var contextUpdatedAt: Date?

    private let locationManager = CLLocationManager()
    @ObservationIgnored private var statusMessageTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSaveAfterLocation = false
    @ObservationIgnored private var syncFallbackTask: Task<Void, Never>?

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
        startSyncFallbackTimer()
    }

    func saveParking() {
        guard isPhoneReachable else {
            saveError = "iPhone not in range"
            return
        }
        saveError = nil
        endError = nil

        guard let location = userLocation else {
            pendingSaveAfterLocation = true
            isSavingParking = true
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
            return
        }

        isSavingParking = true
        sendSaveParking(for: location)
    }

    private func sendSaveParking(for location: CLLocation) {
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

            WCSession.default.sendMessage(message, replyHandler: { [weak self] reply in
                DispatchQueue.main.async {
                    self?.isSavingParking = false
                    if (reply["status"] as? String) != "ok" {
                        self?.saveError = reply["message"] as? String ?? "Unable to save parking"
                    } else {
                        self?.saveError = nil
                        self?.showStatusMessage("Parking saved")
                    }
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

        WCSession.default.sendMessage(["action": "endParking"], replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.isEndingParking = false

                guard (reply["status"] as? String) == "ok" else {
                    self?.endError = reply["message"] as? String ?? "Unable to end parking"
                    return
                }

                self?.endError = nil
                self?.activeParkingSnapshot = nil
                self?.persistSharedState()
                self?.showStatusMessage("Parking ended")
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
        return Self.formattedDistance(
            userLocation.distance(from: parking.clLocation),
            unit: distanceUnitFromDefaults()
        )
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

    static func formattedDistance(_ meters: CLLocationDistance, unit: String = "km") -> String {
        if meters < 50 { return "You're here" }

        if unit == "km" {
            if meters < 1000 { return "\(Int(meters)) m" }
            return String(format: "%.1f km", meters / 1000)
        }

        let miles = meters / 1609.344
        if miles < 0.1 {
            return "\(Int(meters * 3.28084)) ft"
        }
        return String(format: "%.1f mi", miles)
    }

    func syncNow() {
        if WCSession.default.isReachable {
            requestCurrentStatus()
        } else {
            applyApplicationContext(WCSession.default.receivedApplicationContext)
        }
    }
}

extension WatchViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        userLocation = latestLocation
        persistSharedState()

        if pendingSaveAfterLocation {
            pendingSaveAfterLocation = false
            sendSaveParking(for: latestLocation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if pendingSaveAfterLocation {
                manager.requestLocation()
            }
        case .denied, .restricted:
            pendingSaveAfterLocation = false
            isSavingParking = false
            saveError = "Allow location on Apple Watch"
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if pendingSaveAfterLocation {
            pendingSaveAfterLocation = false
            isSavingParking = false
            saveError = "Still getting location. Try again."
        }
    }
}

extension WatchViewModel: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            if session.isReachable {
                self.requestCurrentStatus()
            } else {
                self.applyApplicationContext(session.receivedApplicationContext)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
            if session.isReachable {
                self.requestCurrentStatus()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.applyApplicationContext(applicationContext)
        }
    }
}

private extension WatchViewModel {
    func distanceUnitFromDefaults() -> String {
        UserDefaults(suiteName: SharedKeys.suiteName)?.string(forKey: SharedKeys.distanceUnit) ?? "km"
    }

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

    func requestCurrentStatus() {
        guard WCSession.default.isReachable else { return }
        syncState = .syncing
        startSyncFallbackTimer()   // fresh 1.2s fallback on every sync attempt

        WCSession.default.sendMessage(["action": "syncStatus"], replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                guard let self else { return }
                self.applySyncReply(reply)
            }
        }, errorHandler: { [weak self] _ in
            DispatchQueue.main.async {
                self?.applyApplicationContext(WCSession.default.receivedApplicationContext)
            }
        })
    }

    func applySyncReply(_ reply: [String: Any]) {
        syncFallbackTask?.cancel()
        syncState = .live

        guard (reply["status"] as? String) == "ok" else {
            activeParkingSnapshot = nil
            persistSharedState()
            return
        }

        if let parking = reply["activeParking"] as? [String: Any],
           let latitude = parking["latitude"] as? Double,
           let longitude = parking["longitude"] as? Double,
           let address = parking["address"] as? String,
           let savedAtInterval = parking["savedAt"] as? TimeInterval {
            let timerInterval = parking["timerExpiresAt"] as? TimeInterval
            let timerDate = timerInterval.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
            activeParkingSnapshot = WatchParkingSnapshot(
                latitude: latitude,
                longitude: longitude,
                address: address,
                savedAt: Date(timeIntervalSince1970: savedAtInterval),
                timerExpiresAt: timerDate
            )
        } else {
            activeParkingSnapshot = nil
        }

        persistSharedState()
    }

    func applyApplicationContext(_ applicationContext: [String: Any]) {
        syncFallbackTask?.cancel()
        syncState = .cached

        if let updatedAt = applicationContext["contextUpdatedAt"] as? TimeInterval {
            contextUpdatedAt = Date(timeIntervalSince1970: updatedAt)
        }

        if let parking = applicationContext["activeParking"] as? [String: Any],
           let latitude = parking["latitude"] as? Double,
           let longitude = parking["longitude"] as? Double,
           let address = parking["address"] as? String,
           let savedAtInterval = parking["savedAt"] as? TimeInterval {
            let timerInterval = parking["timerExpiresAt"] as? TimeInterval
            let timerDate = timerInterval.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
            activeParkingSnapshot = WatchParkingSnapshot(
                latitude: latitude,
                longitude: longitude,
                address: address,
                savedAt: Date(timeIntervalSince1970: savedAtInterval),
                timerExpiresAt: timerDate
            )
        } else {
            // Context has no active parking — clear any stale local snapshot.
            activeParkingSnapshot = nil
        }

        persistSharedState()
    }

    func startSyncFallbackTimer() {
        syncFallbackTask?.cancel()
        syncFallbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.syncState == .syncing else { return }
                self.applyApplicationContext(WCSession.default.receivedApplicationContext)
            }
        }
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

        let syncStateValue: String
        switch syncState {
        case .syncing:
            syncStateValue = "syncing"
        case .live:
            syncStateValue = "live"
        case .cached:
            syncStateValue = "cached"
        }
        defaults.set(syncStateValue, forKey: SharedKeys.watchSyncState)

        WidgetCenter.shared.reloadAllTimelines()
    }

    func showStatusMessage(_ message: String) {
        statusMessageTask?.cancel()
        statusMessage = message

        statusMessageTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.statusMessage = nil
            }
        }
    }
}
