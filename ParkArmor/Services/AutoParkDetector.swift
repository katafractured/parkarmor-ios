import CoreBluetooth
import CoreLocation
import CoreMotion
import Foundation
import Observation

@Observable final class AutoParkDetector: NSObject {
    var isMonitoring = false
    var detectionState: DetectionState = .idle
    var pendingAutoSaveCoordinate: CLLocationCoordinate2D?

    enum DetectionState: Equatable {
        case idle
        case driving
        case transitioned
        case saved
    }

    private let motionManager = CMMotionActivityManager()
    private var cbManager: CBCentralManager?
    private var lastDrivingDate: Date?

    var isEnabled: Bool {
        get { UserDefaults(suiteName: "group.com.katafract.ParkArmor")?.bool(forKey: "autoDetectEnabled") ?? false }
        set { UserDefaults(suiteName: "group.com.katafract.ParkArmor")?.set(newValue, forKey: "autoDetectEnabled") }
    }

    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable(), isEnabled, !isMonitoring else { return }
        isMonitoring = true

        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            self.handleActivityUpdate(activity)
        }

        cbManager = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionShowPowerAlertKey: false
        ])
    }

    func stopMonitoring() {
        motionManager.stopActivityUpdates()
        cbManager = nil
        isMonitoring = false
        detectionState = .idle
    }

    private func handleActivityUpdate(_ activity: CMMotionActivity) {
        if activity.automotive && activity.confidence != .low {
            detectionState = .driving
            lastDrivingDate = activity.startDate
        } else if activity.walking && detectionState == .driving {
            guard let lastDriving = lastDrivingDate,
                  activity.startDate.timeIntervalSince(lastDriving) > 30
            else { return }

            detectionState = .transitioned
            NotificationCenter.default.post(name: .didDetectParking, object: nil)
        }
    }
}

extension AutoParkDetector: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard detectionState == .driving else { return }
        detectionState = .transitioned
        NotificationCenter.default.post(name: .didDetectParking, object: nil)
    }
}

extension Notification.Name {
    static let didDetectParking = Notification.Name("com.katafract.ParkArmor.didDetectParking")
}
