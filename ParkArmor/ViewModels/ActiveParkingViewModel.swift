import CoreLocation
import Observation

@Observable final class ActiveParkingViewModel {
    var elapsedSeconds: TimeInterval = 0
    var distanceText = ""
    var bearingDegrees: Double = 0
    var headingDegrees: Double = 0
    var compassCardinal = "N"
    var isActive = false

    private var timerTask: Task<Void, Never>?
    private let mapKitHelper: MapKitHelper
    private let repository: ParkingRepository
    private let notificationManager: NotificationManager
    private let preferences: UserPreferences

    init(
        mapKitHelper: MapKitHelper,
        repository: ParkingRepository,
        notificationManager: NotificationManager,
        preferences: UserPreferences
    ) {
        self.mapKitHelper = mapKitHelper
        self.repository = repository
        self.notificationManager = notificationManager
        self.preferences = preferences
    }

    func start(for parking: ParkingLocation) {
        guard !isActive else { return }
        isActive = true
        elapsedSeconds = Date().timeIntervalSince(parking.savedAt)

        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsedSeconds = Date().timeIntervalSince(parking.savedAt)
            }
        }
    }

    func stop() {
        isActive = false
        timerTask?.cancel()
        timerTask = nil
    }

    func update(userLocation: CLLocation, parking: ParkingLocation, heading: CLHeading?) {
        let meters = userLocation.distance(from: parking.clLocation)
        distanceText = preferences.distanceUnit.formatted(meters)

        let bearing = mapKitHelper.bearing(from: userLocation, to: parking.clLocation)
        compassCardinal = bearing.cardinalDirection

        // Adjust bearing relative to user's heading for a "relative compass"
        if let heading = heading {
            let relativeBearing = (bearing - heading.trueHeading + 360).truncatingRemainder(dividingBy: 360)
            bearingDegrees = relativeBearing
            headingDegrees = heading.trueHeading
        } else {
            bearingDegrees = bearing
            headingDegrees = 0
        }
    }

    func endParking(parking: ParkingLocation) throws {
        if let identifier = parking.timer?.notificationIdentifier, !identifier.isEmpty {
            notificationManager.cancelNotification(identifier: identifier)
        }
        try repository.deactivateAll()
        stop()
    }

    func openDirections(to parking: ParkingLocation) {
        mapKitHelper.openInMaps(coordinate: parking.coordinate, name: parking.displayAddress)
    }
}
