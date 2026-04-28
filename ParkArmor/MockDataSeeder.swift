import Foundation
import MapKit

/// Mock data seeder for screenshot mode (--screenshots launch argument).
/// Provides sample parking sessions with location data.
struct MockDataSeeder {
    static func seedDataIfNeeded() {
        guard CommandLine.arguments.contains("--screenshots") else { return }
        
        // TODO: Tek wires this to real model.
        // Minimal fixture: seed sample CLLocationCoordinate2D + Session objects.
        // Current: placeholder print.
        print("MockDataSeeder: TODO — wire to real ParkArmor session model")
    }
}
