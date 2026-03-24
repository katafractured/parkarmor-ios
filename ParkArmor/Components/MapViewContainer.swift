import MapKit
import SwiftUI

final class ParkingAnnotation: MKPointAnnotation {
    let parkingId: UUID
    let isActive: Bool

    init(location: ParkingLocation) {
        self.parkingId = location.id
        self.isActive = location.isActive
        super.init()
        self.coordinate = location.coordinate
        self.title = location.displayAddress
    }
}

struct MapViewContainer: UIViewRepresentable {
    var parkingLocations: [ParkingLocation]
    var onAnnotationTap: (ParkingLocation) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAnnotationTap: onAnnotationTap)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.userTrackingMode = .followWithHeading
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic)
        context.coordinator.mapView = mapView
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.onAnnotationTap = onAnnotationTap
        context.coordinator.updateAnnotations(mapView: mapView, locations: parkingLocations)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onAnnotationTap: (ParkingLocation) -> Void
        var mapView: MKMapView?
        private var annotationMap: [UUID: ParkingAnnotation] = [:]

        init(onAnnotationTap: @escaping (ParkingLocation) -> Void) {
            self.onAnnotationTap = onAnnotationTap
        }

        func updateAnnotations(mapView: MKMapView, locations: [ParkingLocation]) {
            let newIds = Set(locations.map(\.id))
            let existingIds = Set(annotationMap.keys)

            // Remove stale
            let toRemove = existingIds.subtracting(newIds).compactMap { annotationMap[$0] }
            mapView.removeAnnotations(toRemove)
            toRemove.forEach { annotationMap.removeValue(forKey: $0.parkingId) }

            // Add new
            for location in locations where !existingIds.contains(location.id) {
                let annotation = ParkingAnnotation(location: location)
                annotationMap[location.id] = annotation
                mapView.addAnnotation(annotation)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let parking = annotation as? ParkingAnnotation else { return nil }

            let reuseId = "ParkingPin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: reuseId)

            view.annotation = annotation
            view.canShowCallout = true

            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
            let iconName = parking.isActive ? "car.fill" : "clock.arrow.circlepath"
            let color = parking.isActive ? UIColor(red: 0, green: 240/255.0, blue: 1, alpha: 1) : .systemGray
            let image = UIImage(systemName: iconName, withConfiguration: symbolConfig)?
                .withTintColor(color, renderingMode: .alwaysOriginal)
            view.image = image
            view.frame.size = CGSize(width: 40, height: 40)

            let btn = UIButton(type: .detailDisclosure)
            view.rightCalloutAccessoryView = btn

            return view
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let parking = view.annotation as? ParkingAnnotation,
                  let annotation = annotationMap[parking.parkingId] else { return }
            // We need to find the ParkingLocation from ID — emit via callback
            // The parent view will handle looking up the location by ID
            _ = annotation
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let parking = view.annotation as? ParkingAnnotation else { return }
            // Find location via stored annotation — parent lookup needed
            // Post notification or use binding — for simplicity use tap through callback
            _ = parking
        }
    }
}
