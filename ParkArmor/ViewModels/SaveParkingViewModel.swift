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

    init(
        mapKitHelper: MapKitHelper,
        photoManager: PhotoManager,
        repository: ParkingRepository,
        notificationManager: NotificationManager
    ) {
        self.mapKitHelper = mapKitHelper
        self.photoManager = photoManager
        self.repository = repository
        self.notificationManager = notificationManager
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
        guard !selectedPhotos.isEmpty else { return }
        do {
            photoData = try await photoManager.loadImages(from: selectedPhotos)
        } catch {
            self.error = error.localizedDescription
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
                    photoData: photoData
                )

                if hasTimer && timerDate > Date() {
                    let notificationId = try await notificationManager.scheduleNotification(
                        expiresAt: timerDate,
                        locationName: address,
                        parkingId: location.id
                    )
                    try repository.addTimer(
                        to: location,
                        expiresAt: timerDate,
                        notificationId: notificationId
                    )
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
