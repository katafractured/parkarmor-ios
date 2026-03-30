import Foundation
import AppIntents
import CoreLocation
import SwiftData
import Observation

@Observable final class AppViewModel {
    private enum PendingWatchAction {
        case save(latitude: Double, longitude: Double, address: String)
        case endParking
    }

    // Services
    let locationManager = LocationManager()
    let mapKitHelper = MapKitHelper()
    let notificationManager = NotificationManager()
    let photoManager = PhotoManager()
    let storeKitManager = StoreKitManager()
    let liveActivityManager = LiveActivityManager()
    let preferences = UserPreferences()
    let watchSession = WatchSessionManager.shared

    // Repository (injected after ModelContext is available)
    private(set) var repository: ParkingRepository?

    // State
    var activeParking: ParkingLocation?
    var selectedTab: AppTab = .map
    var showingPaywall = false
    var errorMessage: String?
    var shouldPresentActiveParkingFromLiveActivity = false
    var hasSeenOnboarding = false

    private var hasCompletedLaunchSetup = false
    private var hasRegisteredWatchObservers = false
    private var pendingWatchAction: PendingWatchAction?
    private var observerTokens: [NSObjectProtocol] = []

    var isPro: Bool { storeKitManager.isPro }

    init() {
        hasSeenOnboarding = preferences.hasSeenOnboarding
        registerWatchObserversIfNeeded()
    }

    func configure(context: ModelContext) {
        repository = ParkingRepository(context: context)
        watchSession.statusProvider = { [weak self] in
            self?.currentWatchStatusPayload() ?? ["status": "error", "message": "Phone still starting"]
        }
        refreshActiveParking()
        processPendingWatchActionIfNeeded()
    }

    func onAppLaunch() async {
        hasSeenOnboarding = preferences.hasSeenOnboarding
        await storeKitManager.loadProducts()
        await storeKitManager.verifyEntitlement()
        refreshActiveParking()
        if locationManager.isAuthorized {
            locationManager.startUpdating()
        }

        guard !hasCompletedLaunchSetup else { return }
        hasCompletedLaunchSetup = true

        ParkArmorShortcuts.updateAppShortcutParameters()
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        preferences.hasSeenOnboarding = true
    }

    func refreshActiveParking() {
        activeParking = try? repository?.fetchActive()
        liveActivityManager.sync(with: activeParking)
        watchSession.sendParkingToWatch(activeParking)
    }

    func endParking() {
        guard let repository else { return }
        guard let active = activeParking ?? (try? repository.fetchActive()) else { return }
        // Cancel any timer notification
        if let identifier = active.timer?.notificationIdentifier, !identifier.isEmpty {
            notificationManager.cancelNotification(identifier: identifier)
        }
        do {
            try repository.deactivateAll()
            activeParking = nil
            watchSession.sendParkingToWatch(nil)
            Task { await liveActivityManager.endCurrentActivity() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requiresPro(feature: String) -> Bool {
        if isPro { return false }
        showingPaywall = true
        return true
    }

    private func registerWatchObserversIfNeeded() {
        guard !hasRegisteredWatchObservers else { return }
        hasRegisteredWatchObservers = true

        let saveToken = NotificationCenter.default.addObserver(
            forName: .watchRequestedSaveParking,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let lat = notification.userInfo?["latitude"] as? Double,
                  let lon = notification.userInfo?["longitude"] as? Double,
                  let address = notification.userInfo?["address"] as? String
            else { return }

            self.handleWatchSaveParking(latitude: lat, longitude: lon, address: address)
        }
        observerTokens.append(saveToken)

        let endToken = NotificationCenter.default.addObserver(
            forName: .watchRequestedEndParking,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWatchEndParking()
        }
        observerTokens.append(endToken)
    }

    private func handleWatchSaveParking(latitude: Double, longitude: Double, address: String) {
        guard let repository else {
            pendingWatchAction = .save(latitude: latitude, longitude: longitude, address: address)
            return
        }

        do {
            try repository.saveParking(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                address: address,
                notes: "",
                preserveHistory: preferences.saveParkingHistory
            )
            refreshActiveParking()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleWatchEndParking() {
        guard repository != nil else {
            pendingWatchAction = .endParking
            return
        }

        endParking()
    }

    private func processPendingWatchActionIfNeeded() {
        guard let pendingWatchAction else { return }
        self.pendingWatchAction = nil

        switch pendingWatchAction {
        case let .save(latitude, longitude, address):
            handleWatchSaveParking(latitude: latitude, longitude: longitude, address: address)
        case .endParking:
            handleWatchEndParking()
        }
    }

    private func currentWatchStatusPayload() -> [String: Any] {
        let currentParking = activeParking ?? (try? repository?.fetchActive()) ?? nil
        if let currentParking {
            return [
                "status": "ok",
                "activeParking": [
                    "latitude": currentParking.latitude,
                    "longitude": currentParking.longitude,
                    "address": currentParking.displayAddress,
                    "savedAt": currentParking.savedAt.timeIntervalSince1970,
                    "timerExpiresAt": currentParking.timer?.expiresAt.timeIntervalSince1970 ?? 0
                ]
            ]
        }

        return [
            "status": "ok",
            "activeParking": NSNull()
        ]
    }
}
