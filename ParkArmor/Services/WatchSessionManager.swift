import Foundation
import Observation
import WatchConnectivity

@Observable final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    var isReachable = false
    var statusProvider: (() -> [String: Any])?

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
        processMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        processMessage(message, replyHandler: replyHandler)
    }

    private func processMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)? = nil
    ) {
        guard let action = message["action"] as? String else {
            replyHandler?(["status": "error", "message": "Missing action"])
            return
        }

        let work = {
            if action == "saveParking",
               let latitude = message["latitude"] as? Double,
               let longitude = message["longitude"] as? Double,
               let address = message["address"] as? String {
                self.handleSaveParkingRequest(latitude: latitude, longitude: longitude, address: address)
                replyHandler?(["status": "ok", "action": action])
            } else if action == "endParking" {
                self.handleEndParkingRequest()
                replyHandler?(["status": "ok", "action": action])
            } else if action == "syncStatus" {
                let payload = self.statusProvider?() ?? ["status": "error", "message": "Phone still starting"]
                replyHandler?(payload)
            } else {
                replyHandler?(["status": "error", "message": "Unknown action: \(action)"])
            }
        }

        if Thread.isMainThread {
            work()
        } else if replyHandler != nil {
            DispatchQueue.main.sync(execute: work)
        } else {
            DispatchQueue.main.async(execute: work)
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
