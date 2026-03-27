import Foundation
import Observation
import WatchConnectivity

@Observable final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    var isReachable = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendParkingToWatch(_ parking: ParkingLocation?) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }

        if let parking {
            let payload: [String: Any] = [
                "latitude": parking.latitude,
                "longitude": parking.longitude,
                "address": parking.displayAddress,
                "savedAt": parking.savedAt.timeIntervalSince1970,
                "timerExpiresAt": parking.timer?.expiresAt.timeIntervalSince1970 ?? 0
            ]
            try? WCSession.default.updateApplicationContext(["activeParking": payload])
        } else {
            try? WCSession.default.updateApplicationContext(["activeParking": NSNull()])
        }
    }

    func handleSaveParkingRequest(latitude: Double, longitude: Double, address: String) {
        NotificationCenter.default.post(
            name: .watchRequestedSaveParking,
            object: nil,
            userInfo: ["latitude": latitude, "longitude": longitude, "address": address]
        )
    }

    func handleEndParkingRequest() {
        NotificationCenter.default.post(name: .watchRequestedEndParking, object: nil)
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        isReachable = session.isReachable
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        handleMessage(message)
        replyHandler(["status": "ok"])
    }

    private func handleMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        if action == "saveParking",
           let latitude = message["latitude"] as? Double,
           let longitude = message["longitude"] as? Double,
           let address = message["address"] as? String {
            DispatchQueue.main.async {
                self.handleSaveParkingRequest(latitude: latitude, longitude: longitude, address: address)
            }
        } else if action == "endParking" {
            DispatchQueue.main.async {
                self.handleEndParkingRequest()
            }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}

extension Notification.Name {
    static let watchRequestedSaveParking = Notification.Name("com.katafract.ParkArmor.watchRequestedSaveParking")
    static let watchRequestedEndParking = Notification.Name("com.katafract.ParkArmor.watchRequestedEndParking")
}
