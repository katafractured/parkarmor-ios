import CarPlay
import CoreLocation
import MapKit
import NotificationCenter

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    private let locationManager = CLLocationManager()
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        locationManager.requestWhenInUseAuthorization()
        showMainTemplate()
    }
    
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
    }
    
    private func showMainTemplate() {
        let parkItem = CPListItem(text: "Park Here", detailText: "Save current location")
        parkItem.handler = { [weak self] item, completion in
            self?.parkHere()
            completion()
        }
        
        let findItem = CPListItem(text: "Where's My Car?", detailText: "Navigate back to parked location")
        findItem.handler = { [weak self] item, completion in
            self?.findCar()
            completion()
        }
        
        let section = CPListSection(items: [parkItem, findItem])
        let listTemplate = CPListTemplate(title: "ParkArmor", sections: [section])
        interfaceController?.setRootTemplate(listTemplate, animated: false)
    }
    
    private func parkHere() {
        guard let location = locationManager.location else {
            showAlert(title: "Location Unavailable", message: "Unable to access your current location.")
            return
        }
        
        // Save parking via shared UserDefaults (App Group)
        let defaults = UserDefaults(suiteName: "group.com.katafract.ParkArmor") ?? .standard
        defaults.set(location.coordinate.latitude, forKey: "carplay_park_lat")
        defaults.set(location.coordinate.longitude, forKey: "carplay_park_lon")
        defaults.set(Date().timeIntervalSince1970, forKey: "carplay_park_time")
        defaults.synchronize()
        
        // Post notification for the main app to pick up
        NotificationCenter.default.post(name: .carPlayParkHere, object: location)
        
        // Show confirmation
        showAlert(title: "Parked!", message: "Location saved. Open ParkArmor to confirm.")
    }
    
    private func findCar() {
        let defaults = UserDefaults(suiteName: "group.com.katafract.ParkArmor") ?? .standard
        let lat = defaults.double(forKey: "carplay_park_lat")
        let lon = defaults.double(forKey: "carplay_park_lon")
        
        guard lat != 0 && lon != 0 else {
            showAlert(title: "No Parking Saved", message: "Save a parking location first.")
            return
        }
        
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        destination.name = "My Car"
        destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
    
    private func showAlert(title: String, message: String) {
        let alert = CPAlertTemplate(
            titleVariants: [title],
            actions: [CPAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true)
            })]
        )
        interfaceController?.presentTemplate(alert, animated: true)
    }
}

extension Notification.Name {
    static let carPlayParkHere = Notification.Name("carPlayParkHere")
}
