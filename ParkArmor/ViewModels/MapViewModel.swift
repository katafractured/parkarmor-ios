import CoreLocation
import MapKit
import Observation
import SwiftUI

// MARK: - Cluster model

struct ParkingCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let locations: [ParkingLocation]

    var count: Int { locations.count }
    var isSingle: Bool { locations.count == 1 }
    var single: ParkingLocation? { locations.count == 1 ? locations.first : nil }
}

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

    /// Groups history locations into spatial clusters based on the current map span.
    /// `clusterRadius` is expressed as a fraction of the map's latitude span.
    func clusters(for locations: [ParkingLocation], span: MKCoordinateSpan) -> [ParkingCluster] {
        // Active parking is always rendered individually — only cluster history
        let historyLocations = locations.filter { !$0.isActive }

        // Threshold: ~4% of visible lat span (shrinks as user zooms in)
        let threshold = max(span.latitudeDelta * 0.04, 0.0002)

        var clusters: [(center: CLLocationCoordinate2D, members: [ParkingLocation])] = []

        for location in historyLocations {
            // Find the nearest existing cluster within threshold
            var bestIndex: Int? = nil
            var bestDistance = Double.greatestFiniteMagnitude

            for (index, cluster) in clusters.enumerated() {
                let latDiff = abs(cluster.center.latitude - location.latitude)
                let lonDiff = abs(cluster.center.longitude - location.longitude)
                let dist = max(latDiff, lonDiff)
                if dist < threshold && dist < bestDistance {
                    bestDistance = dist
                    bestIndex = index
                }
            }

            if let idx = bestIndex {
                clusters[idx].members.append(location)
                // Recompute centroid
                let lats = clusters[idx].members.map(\.latitude)
                let lons = clusters[idx].members.map(\.longitude)
                let avgLat = lats.reduce(0, +) / Double(lats.count)
                let avgLon = lons.reduce(0, +) / Double(lons.count)
                clusters[idx].center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            } else {
                clusters.append((center: location.coordinate, members: [location]))
            }
        }

        return clusters.map { ParkingCluster(coordinate: $0.center, locations: $0.members) }
    }
}
