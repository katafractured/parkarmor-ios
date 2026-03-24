import Foundation
import Observation

enum HistoryFilter: String, CaseIterable {
    case recent
    case favorites
    case all

    var title: String {
        switch self {
        case .recent:
            return "Recent"
        case .favorites:
            return "Favorites"
        case .all:
            return "All"
        }
    }
}

@Observable final class HistoryViewModel {
    var locations: [ParkingLocation] = []
    var isLoading = false
    var error: String?
    var availableHistoryCount = 0
    var selectedFilter: HistoryFilter = .recent

    private let repository: ParkingRepository
    private let preferences: UserPreferences
    let isPro: Bool

    init(repository: ParkingRepository, preferences: UserPreferences, isPro: Bool) {
        self.repository = repository
        self.preferences = preferences
        self.isPro = isPro
    }

    func load() {
        isLoading = true
        defer { isLoading = false }

        do {
            try repository.pruneHistory(retention: effectiveRetention)

            let allHistory = try repository.fetchHistory(includeActive: false)
            availableHistoryCount = allHistory.count

            let filtered = filteredLocations(from: allHistory)
            if isPro {
                locations = filtered
            } else {
                locations = Array(filtered.prefix(1))
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func delete(_ location: ParkingLocation) {
        do {
            try repository.delete(location)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func clearHistory() {
        do {
            try repository.clearHistory()
            load()
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

    func toggleFavorite(_ location: ParkingLocation) {
        do {
            try repository.toggleFavorite(location)
            load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var effectiveRetention: HistoryRetentionOption {
        if isPro {
            return preferences.historyRetention
        }

        switch preferences.historyRetention {
        case .ninetyDays, .forever:
            return .thirtyDays
        case .sevenDays, .thirtyDays:
            return preferences.historyRetention
        }
    }

    private func filteredLocations(from allHistory: [ParkingLocation]) -> [ParkingLocation] {
        if !isPro {
            return allHistory
        }

        switch selectedFilter {
        case .recent, .all:
            return allHistory
        case .favorites:
            return allHistory.filter(\.isFavorite)
        }
    }
}
