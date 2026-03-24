import CoreLocation
import MapKit
import Observation
import SwiftUI

@Observable final class MapViewModel {
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    var selectedLocation: ParkingLocation?
    var showingHistory = false
    var showingSettings = false
    var showingSaveParking = false
    var showingActiveParking = false

    func centerOnUser() {
        cameraPosition = .userLocation(fallback: .automatic)
    }

    func centerOn(coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan = .init(latitudeDelta: 0.005, longitudeDelta: 0.005)) {
        let region = MKCoordinateRegion(center: coordinate, span: span)
        cameraPosition = .region(region)
    }

    func centerOn(parking: ParkingLocation) {
        centerOn(coordinate: parking.coordinate)
        selectedLocation = parking
        showingActiveParking = true
    }
}
