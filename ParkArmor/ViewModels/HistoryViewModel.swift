import Foundation
import Observation

@Observable final class HistoryViewModel {
    var locations: [ParkingLocation] = []
    var isLoading = false
    var error: String?

    private let repository: ParkingRepository
    let isPro: Bool

    init(repository: ParkingRepository, isPro: Bool) {
        self.repository = repository
        self.isPro = isPro
    }

    func load() {
        isLoading = true
        do {
            locations = try repository.fetchHistory()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func delete(_ location: ParkingLocation) {
        do {
            try repository.delete(location)
            locations.removeAll { $0.id == location.id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func reactivate(_ location: ParkingLocation) {
        do {
            try repository.reactivate(location)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func togglePin(_ location: ParkingLocation) {
        do {
            try repository.togglePin(location)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
