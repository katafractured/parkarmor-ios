import Foundation
import Observation

enum HistoryFilter: String, CaseIterable {
    case recent
    case favorites

    var title: String {
        switch self {
        case .recent:
            return "Recent"
        case .favorites:
            return "Favorites"
        }
    }
}

@Observable final class HistoryViewModel {
    var locations: [ParkingLocation] = []
    var isLoading = false
    var error: String?
    var availableHistoryCount = 0
    var selectedFilter: HistoryFilter = .recent
    /// Search query — Pro only. Empty string means no filter.
    var searchQuery: String = ""

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

    /// Groups visible locations by date bucket for sectioned display.
    var groupedLocations: [(label: String, locations: [ParkingLocation])] {
        let calendar = Calendar.current
        let now = Date()

        var todayItems: [ParkingLocation] = []
        var yesterdayItems: [ParkingLocation] = []
        var thisWeekItems: [ParkingLocation] = []
        var earlierItems: [ParkingLocation] = []

        for location in locations {
            if calendar.isDateInToday(location.savedAt) {
                todayItems.append(location)
            } else if calendar.isDateInYesterday(location.savedAt) {
                yesterdayItems.append(location)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      location.savedAt >= weekAgo {
                thisWeekItems.append(location)
            } else {
                earlierItems.append(location)
            }
        }

        var groups: [(label: String, locations: [ParkingLocation])] = []
        if !todayItems.isEmpty    { groups.append((label: "Today",     locations: todayItems)) }
        if !yesterdayItems.isEmpty { groups.append((label: "Yesterday", locations: yesterdayItems)) }
        if !thisWeekItems.isEmpty  { groups.append((label: "This Week", locations: thisWeekItems)) }
        if !earlierItems.isEmpty   { groups.append((label: "Earlier",   locations: earlierItems)) }
        return groups
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
        var result = allHistory

        if isPro {
            switch selectedFilter {
            case .recent:
                break
            case .favorites:
                result = result.filter(\.isFavorite)
            }

            // Apply search query if non-empty
            let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
            if !query.isEmpty {
                result = result.filter { location in
                    location.displayAddress.lowercased().contains(query) ||
                    (!location.notes.isEmpty && location.notes.lowercased().contains(query)) ||
                    (!(location.nickname ?? "").isEmpty && (location.nickname ?? "").lowercased().contains(query))
                }
            }
        }

        return result
    }
}
