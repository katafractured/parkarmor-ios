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
    }

    func beginSave(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        Task { await geocodeAddress(coordinate: coordinate) }
    }

    private func geocodeAddress(coordinate: CLLocationCoordinate2D) async {
        isGeocodingAddress = true
        address = await mapKitHelper.reverseGeocode(coordinate: coordinate)
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

    func confirmSave(onSuccess: @escaping (ParkingLocation) -> Void) {
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
