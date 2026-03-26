import Foundation
import AppIntents
import CoreLocation
import SwiftData
import Observation

@Observable final class AppViewModel {
    // Services
    let locationManager = LocationManager()
    let mapKitHelper = MapKitHelper()
    let notificationManager = NotificationManager()
    let photoManager = PhotoManager()
    let storeKitManager = StoreKitManager()
    let liveActivityManager = LiveActivityManager()
    let preferences = UserPreferences()
    let autoDetector = AutoParkDetector()
    let watchSession = WatchSessionManager.shared

    // Repository (injected after ModelContext is available)
    private(set) var repository: ParkingRepository?

    // State
    var activeParking: ParkingLocation?
    var selectedTab: AppTab = .map
    var showingPaywall = false
    var errorMessage: String?
    var shouldPresentActiveParkingFromLiveActivity = false
    var shouldShowAutoDetectPrompt = false
    var hasSeenOnboarding = false

    private var hasCompletedLaunchSetup = false

    var isPro: Bool { storeKitManager.isPro }

    init() {
        hasSeenOnboarding = preferences.hasSeenOnboarding
    }

    func configure(context: ModelContext) {
        repository = ParkingRepository(context: context)
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

        if autoDetector.isEnabled {
            autoDetector.startMonitoring()
        }

        NotificationCenter.default.addObserver(
            forName: .didDetectParking,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAutoDetectedParking()
        }

        NotificationCenter.default.addObserver(
            forName: .watchRequestedSaveParking,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let lat = notification.userInfo?["latitude"] as? Double,
                  let lon = notification.userInfo?["longitude"] as? Double,
                  let address = notification.userInfo?["address"] as? String
            else { return }

            do {
                try self.repository?.saveParking(
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    address: address,
                    notes: "",
                    preserveHistory: self.preferences.saveParkingHistory
                )
                self.refreshActiveParking()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }

        NotificationCenter.default.addObserver(
            forName: .watchRequestedEndParking,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.endParking()
            self.watchSession.sendParkingToWatch(nil)
        }

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
        guard let active = activeParking else { return }
        // Cancel any timer notification
        if let identifier = active.timer?.notificationIdentifier, !identifier.isEmpty {
            notificationManager.cancelNotification(identifier: identifier)
        }
        do {
            try repository?.deactivateAll()
            activeParking = nil
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

    func handleAutoDetectedParking() {
        guard activeParking == nil else { return }
        shouldShowAutoDetectPrompt = true
    }
}
