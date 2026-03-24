import CoreLocation
import MapKit
import Observation

@Observable final class MapKitHelper {
    var isGeocoding = false

    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(coordinate: coordinate)
        isGeocoding = true
        defer { isGeocoding = false }

        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location) else { return "" }
            let mapItems = await withCheckedContinuation { continuation in
                request.getMapItems { items, _ in
                    continuation.resume(returning: items ?? [])
                }
            }
            guard let mapItem = mapItems.first else { return "" }
            return mapItem.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true) ?? ""
        } else {
            let geocoder = CLGeocoder()
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                guard let placemark = placemarks.first else { return "" }
                var parts: [String] = []
                if let street = placemark.thoroughfare {
                    if let number = placemark.subThoroughfare {
                        parts.append("\(number) \(street)")
                    } else {
                        parts.append(street)
                    }
                }
                if let city = placemark.locality {
                    parts.append(city)
                }
                return parts.joined(separator: ", ")
            } catch {
                return ""
            }
        }
    }

    func distanceString(
        from: CLLocation,
        to: CLLocation,
        unit: DistanceUnit
    ) -> String {
        let meters = from.distance(from: to)
        return unit.formatted(meters)
    }

    func bearing(from: CLLocation, to: CLLocation) -> Double {
        let fromCoord = from.coordinate
        let toCoord = to.coordinate
        return fromCoord.bearing(to: toCoord)
    }

    func openInMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let location = CLLocation(coordinate: coordinate)
        let mapItem: MKMapItem
        if #available(iOS 26.0, *) {
            mapItem = MKMapItem(location: location, address: nil)
        } else {
            let placemark = MKPlacemark(coordinate: coordinate)
            mapItem = MKMapItem(placemark: placemark)
        }
        mapItem.name = name

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ]
        mapItem.openInMaps(launchOptions: launchOptions)
    }
}
