import Foundation
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

    // Repository (injected after ModelContext is available)
    private(set) var repository: ParkingRepository?

    // State
    var activeParking: ParkingLocation?
    var selectedTab: AppTab = .map
    var showingPaywall = false
    var errorMessage: String?
    var shouldPresentActiveParkingFromLiveActivity = false

    var isPro: Bool { storeKitManager.isPro }
    var hasSeenOnboarding: Bool {
        get { preferences.hasSeenOnboarding }
        set { preferences.hasSeenOnboarding = newValue }
    }

    func configure(context: ModelContext) {
        repository = ParkingRepository(context: context)
    }

    func onAppLaunch() async {
        await storeKitManager.loadProducts()
        await storeKitManager.verifyEntitlement()
        refreshActiveParking()
        if locationManager.isAuthorized {
            locationManager.startUpdating()
        }
    }

    func refreshActiveParking() {
        activeParking = try? repository?.fetchActive()
        liveActivityManager.sync(with: activeParking)
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
}
