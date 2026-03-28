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
    var hasSeenOnboarding = false

    // Auto-detect banner
    var showingAutoDetectBanner = false
    var autoDetectBannerCountdown = 60

    private var hasCompletedLaunchSetup = false
    private var pendingDetectedCoordinate: CLLocationCoordinate2D?
    private var pendingDetectionTask: Task<Void, Never>?
    private var bannerCountdownTask: Task<Void, Never>?

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

        NotificationCenter.default.addObserver(
            forName: .parkingDetectionNotificationTapped,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let action = notification.userInfo?["action"] as? String
            if action == NotificationManager.ParkingDetection.saveAction {
                self.confirmAutoDetectedParking()
            } else {
                self.dismissAutoDetectedParking()
            }
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
        guard activeParking == nil, pendingDetectedCoordinate == nil else { return }
        // Capture location at the moment of detection (while the user is still near the car).
        // Uses the existing when-in-use location permission — no background location access needed.
        pendingDetectedCoordinate = locationManager.currentLocation?.coordinate

        autoDetectBannerCountdown = 60
        showingAutoDetectBanner = true

        // Count down the in-app banner, then fire a notification for locked/backgrounded devices.
        bannerCountdownTask = Task { @MainActor in
            for tick in stride(from: 59, through: 0, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                autoDetectBannerCountdown = tick
            }
            showingAutoDetectBanner = false
            await notificationManager.scheduleParkingDetectedNotification()
        }

        // Auto-save as a suggested session after 5 minutes with no response.
        pendingDetectionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(300))
            guard !Task.isCancelled else { return }
            autoSaveAsSuggested()
        }
    }

    func confirmAutoDetectedParking() {
        let coordinate = pendingDetectedCoordinate
        cancelPendingDetection()
        guard let coordinate else { return }
        Task {
            let address = await mapKitHelper.reverseGeocode(coordinate: coordinate)
            try? repository?.saveParking(
                coordinate: coordinate,
                address: address,
                notes: "",
                preserveHistory: preferences.saveParkingHistory
            )
            await MainActor.run { refreshActiveParking() }
        }
    }

    func dismissAutoDetectedParking() {
        cancelPendingDetection()
    }

    private func autoSaveAsSuggested() {
        guard let coordinate = pendingDetectedCoordinate else { return }
        cancelPendingDetection(clearCoordinate: false)
        pendingDetectedCoordinate = nil
        Task {
            let address = await mapKitHelper.reverseGeocode(coordinate: coordinate)
            try? repository?.saveSuggested(coordinate: coordinate, address: address)
        }
    }

    private func cancelPendingDetection(clearCoordinate: Bool = true) {
        pendingDetectionTask?.cancel()
        bannerCountdownTask?.cancel()
        pendingDetectionTask = nil
        bannerCountdownTask = nil
        showingAutoDetectBanner = false
        notificationManager.cancelParkingDetectedNotification()
        if clearCoordinate { pendingDetectedCoordinate = nil }
    }
}
