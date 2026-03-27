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

    // MARK: - Tuning constants

    /// Minimum time (seconds) that must pass between the last automotive
    /// activity and a walking/stationary transition before detection fires.
    /// Lower = more sensitive. Raise to avoid bus stops and red lights.
    private static let minDriveDuration: TimeInterval = 60

    /// Maximum time (seconds) after the last automotive activity during
    /// which a walking/stationary transition is still considered a park event.
    /// Prevents stale driving state from firing hours later.
    private static let maxTransitionWindow: TimeInterval = 300

    /// CoreMotion confidence level required to treat an activity as driving.
    /// `.high` is least noisy; `.medium` catches more cases but more false positives.
    private static let requiredDrivingConfidence: CMMotionActivityConfidence = .medium

    /// Delay (seconds) after a Bluetooth peripheral disconnects before
    /// firing detection. Absorbs transient glitches.
    private static let bluetoothDebounce: TimeInterval = 4

    // MARK: - Private state

    private let motionManager = CMMotionActivityManager()
    private var cbManager: CBCentralManager?
    private var lastDrivingDate: Date?
    private var bluetoothDebounceTask: Task<Void, Never>?

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
        bluetoothDebounceTask?.cancel()
        bluetoothDebounceTask = nil
        motionManager.stopActivityUpdates()
        cbManager = nil
        isMonitoring = false
        detectionState = .idle
        lastDrivingDate = nil
    }

    func handleActivityUpdate(_ activity: CMMotionActivity) {
        if activity.automotive && activity.confidence >= Self.requiredDrivingConfidence {
            detectionState = .driving
            lastDrivingDate = activity.startDate
            return
        }

        guard detectionState == .driving,
              let lastDriving = lastDrivingDate else { return }

        let elapsed = activity.startDate.timeIntervalSince(lastDriving)

        // Clear stale driving state if the transition window has passed
        guard elapsed <= Self.maxTransitionWindow else {
            detectionState = .idle
            lastDrivingDate = nil
            return
        }

        // Walking or stationary after sufficient drive time = parked
        let isPostDriveActivity = activity.walking || activity.stationary
        guard isPostDriveActivity && elapsed >= Self.minDriveDuration else { return }

        detectionState = .transitioned
        NotificationCenter.default.post(name: .didDetectParking, object: nil)
    }
}

extension AutoParkDetector: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {}

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard detectionState == .driving else { return }

        bluetoothDebounceTask?.cancel()
        bluetoothDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.bluetoothDebounce))
            guard let self, !Task.isCancelled, self.detectionState == .driving else { return }
            await MainActor.run {
                self.detectionState = .transitioned
                NotificationCenter.default.post(name: .didDetectParking, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let didDetectParking = Notification.Name("com.katafract.ParkArmor.didDetectParking")
}
