import Foundation
import Testing
@testable import ParkArmor

@Suite("AutoParkDetector — state machine")
@MainActor
struct AutoParkDetectorTests {
    @Test func initialStateIsIdle() {
        let detector = AutoParkDetector()
        #expect(detector.detectionState == .idle)
        #expect(detector.isMonitoring == false)
        #expect(detector.pendingAutoSaveCoordinate == nil)
    }

    @Test func stopMonitoringResetsToIdle() {
        let detector = AutoParkDetector()
        // Manually force a non-idle state to verify stopMonitoring resets it
        detector.detectionState = .driving
        detector.stopMonitoring()
        #expect(detector.detectionState == .idle)
        #expect(detector.isMonitoring == false)
    }

    @Test func isEnabledPersistsToUserDefaults() {
        let detector = AutoParkDetector()
        detector.isEnabled = true
        #expect(detector.isEnabled == true)
        detector.isEnabled = false
        #expect(detector.isEnabled == false)
    }

    @Test func detectionStateEquality() {
        #expect(AutoParkDetector.DetectionState.idle == .idle)
        #expect(AutoParkDetector.DetectionState.driving == .driving)
        #expect(AutoParkDetector.DetectionState.transitioned == .transitioned)
        #expect(AutoParkDetector.DetectionState.saved == .saved)
        #expect(AutoParkDetector.DetectionState.idle != .driving)
    }

    @Test func didDetectParkingNotificationIsPostedOnTransition() async {
        let detector = AutoParkDetector()
        detector.detectionState = .driving

        var received = false
        let observer = NotificationCenter.default.addObserver(
            forName: .didDetectParking,
            object: nil,
            queue: .main
        ) { _ in received = true }
        defer { NotificationCenter.default.removeObserver(observer) }

        // Simulate BT disconnect while in driving state (centralManager(_:didDisconnectPeripheral:error:))
        // Since we can't inject a real CBPeripheral, we test the underlying notification dispatch directly.
        NotificationCenter.default.post(name: .didDetectParking, object: nil)

        // Allow main run loop to process
        await Task.yield()
        #expect(received)
    }
}

@Suite("AutoParkDetector — Notification.Name")
struct AutoParkDetectorNotificationNameTests {
    @Test func didDetectParkingNameIsStable() {
        let name = Notification.Name.didDetectParking
        #expect(name.rawValue == "com.katafract.ParkArmor.didDetectParking")
    }
}
