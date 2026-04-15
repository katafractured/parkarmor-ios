import CoreLocation
import Foundation
import PhotosUI
import Observation
import SwiftUI

@Observable final class SaveParkingViewModel {
    var address = ""
    var notes = ""
    var selectedPhotos: [PhotosPickerItem] = []
    var photoData: [Data] = []
    var capturedPhotoData: [Data] = []
    var hasTimer = false
    var timerDate: Date = Date().addingTimeInterval(7200) // 2 hours default
    var isSaving = false
    var isGeocodingAddress = false
    var error: String?
    var coordinate: CLLocationCoordinate2D?
    /// Previous visits detected within ~50m of the current save coordinate.
    var nearbyPreviousVisits: [ParkingLocation] = []

    private let mapKitHelper: MapKitHelper
    private let photoManager: PhotoManager
    private let repository: ParkingRepository
    private let notificationManager: NotificationManager
    private let liveActivityManager: LiveActivityManager
    private let preferences: UserPreferences

    init(
        mapKitHelper: MapKitHelper,
        photoManager: PhotoManager,
        repository: ParkingRepository,
        notificationManager: NotificationManager,
        liveActivityManager: LiveActivityManager,
        preferences: UserPreferences
    ) {
        self.mapKitHelper = mapKitHelper
        self.photoManager = photoManager
        self.repository = repository
        self.notificationManager = notificationManager
        self.liveActivityManager = liveActivityManager
        self.preferences = preferences

        setupCarPlayNotificationHandler()
    }

    private func setupCarPlayNotificationHandler() {
        NotificationCenter.default.addObserver(
            forName: .carPlayParkHere,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let location = notification.object as? CLLocation else { return }
            self?.beginSave(coordinate: location.coordinate)
            // Automatically save with minimal UI after a brief delay to let user confirm
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.confirmSave(onSuccess: { _ in })
            }
        }
    }

    func beginSave(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        Task {
            await geocodeAddress(coordinate: coordinate)
            detectNearbyPreviousVisits(coordinate: coordinate)
        }
    }

    private func detectNearbyPreviousVisits(coordinate: CLLocationCoordinate2D) {
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let history = (try? repository.fetchHistory(includeActive: false)) ?? []
        let nearby = history.filter { past in
            past.clLocation.distance(from: clLocation) < 50 // meters
        }
        nearbyPreviousVisits = nearby
    }

    private func geocodeAddress(coordinate: CLLocationCoordinate2D) async {
        isGeocodingAddress = true
        
        // Try geocoding with 1.5s timeout
        do {
            let geocodeTask = Task {
                await mapKitHelper.reverseGeocode(coordinate: coordinate)
            }
            
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            address = await geocodeTask.value
        } catch {
            // Timeout or error — use coordinate fallback
            if address.isEmpty {
                address = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
            }
        }
        
        isGeocodingAddress = false
    }

    func loadSelectedPhotos() async {
        guard !selectedPhotos.isEmpty else {
            photoData = capturedPhotoData
            return
        }
        do {
            let libraryPhotos = try await photoManager.loadImages(from: selectedPhotos)
            photoData = capturedPhotoData + libraryPhotos
        } catch {
            self.error = error.localizedDescription
            photoData = capturedPhotoData
        }
    }

    func confirmSave(nickname: String = "", onSuccess: @escaping (ParkingLocation) -> Void) {
        guard let coordinate else {
            error = "Location unavailable."
            return
        }
        isSaving = true
        Task {
            do {
                await loadSelectedPhotos()
                let location = try repository.saveParking(
                    coordinate: coordinate,
                    address: address,
                    notes: notes,
                    nickname: nickname.isEmpty ? nil : nickname,
                    photoData: photoData,
                    preserveHistory: preferences.saveParkingHistory
                )

                if hasTimer && timerDate > Date() {
                    let notificationId = try await notificationManager.scheduleNotification(
                        expiresAt: timerDate,
                        locationName: address,
                        parkingId: location.id,
                        alertMode: preferences.timerAlertMode
                    )
                    try repository.addTimer(
                        to: location,
                        expiresAt: timerDate,
                        notificationId: notificationId
                    )
                    liveActivityManager.sync(with: location)
                }

                isSaving = false
                onSuccess(location)
            } catch {
                self.error = error.localizedDescription
                isSaving = false
            }
        }
    }
}
