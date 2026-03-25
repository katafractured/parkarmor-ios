import CoreLocation
import SwiftUI

struct HistoryScreenView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    var showsDismissButton = true
    var onReactivated: ((ParkingLocation) -> Void)?

    @State private var viewModel: HistoryViewModel?
    @State private var showingPaywall = false
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.parkNavy.ignoresSafeArea()

                Group {
                    if let vm = viewModel {
                        if vm.locations.isEmpty && vm.searchQuery.isEmpty {
                            emptyState
                        } else {
                            historyContent(vm: vm)
                        }
                    } else {
                        ProgressView().tint(DesignTokens.parkCyan)
                    }
                }
            }
            .navigationTitle("Parking History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.parkNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(DesignTokens.parkCyan)
                    }
                }

                if let vm = viewModel, !vm.locations.isEmpty || !vm.searchQuery.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if appViewModel.isPro {
                                Picker("History Filter", selection: Binding(
                                    get: { vm.selectedFilter },
                                    set: {
                                        vm.selectedFilter = $0
                                        vm.load()
                                    }
                                )) {
                                    ForEach(HistoryFilter.allCases, id: \.self) { filter in
                                        Text(filter.title).tag(filter)
                                    }
                                }
                            }

                            Button(role: .destructive) {
                                showingClearConfirmation = true
                            } label: {
                                Label("Clear History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(DesignTokens.parkAccentText)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Clear parking history?",
                isPresented: $showingClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    viewModel?.clearHistory()
                }
            } message: {
                Text("This removes saved inactive parking history. Your current active parking spot stays available.")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(storeKit: appViewModel.storeKitManager) {
                    showingPaywall = false
                }
            }
        }
        .task {
            guard let repository = appViewModel.repository else { return }
            let vm = HistoryViewModel(
                repository: repository,
                preferences: appViewModel.preferences,
                isPro: appViewModel.isPro
            )
            viewModel = vm
            vm.load()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(DesignTokens.parkTextSecondary.opacity(0.4))

            Text(emptyTitle)
                .font(.title3.bold())
                .foregroundStyle(DesignTokens.parkTextPrimary)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.parkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var emptyTitle: String {
        if !appViewModel.preferences.saveParkingHistory {
            return "History Saving Is Off"
        }
        return "No Parking History"
    }

    private var emptyMessage: String {
        if !appViewModel.preferences.saveParkingHistory {
            return "Turn on parking history in Settings if you want past parking spots to stay available."
        }
        return "Your recent parking spots will appear here."
    }

    @ViewBuilder
    private func historyContent(vm: HistoryViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                // Search bar (Pro)
                if appViewModel.isPro {
                    searchBar(vm: vm)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }

                // Upgrade nudge for free users
                if !appViewModel.isPro && vm.availableHistoryCount > vm.locations.count {
                    upgradeCard(hiddenCount: vm.availableHistoryCount - vm.locations.count)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                }

                if vm.locations.isEmpty && !vm.searchQuery.isEmpty {
                    // No search results
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(DesignTokens.parkTextSecondary.opacity(0.4))
                        Text("No results for \"\(vm.searchQuery)\"")
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                    .padding(.top, 60)
                } else {
                    // Grouped sections
                    ForEach(vm.groupedLocations, id: \.label) { group in
                        Section {
                            ForEach(group.locations) { location in
                                HistoryRowView(
                                    location: location,
                                    currentLocation: appViewModel.locationManager.currentLocation,
                                    distanceUnit: appViewModel.preferences.distanceUnit,
                                    isPro: appViewModel.isPro,
                                    onReactivate: {
                                        vm.reactivate(location)
                                        onReactivated?(location)
                                        if showsDismissButton {
                                            dismiss()
                                        }
                                    },
                                    onDelete: { vm.delete(location) },
                                    onToggleFavorite: { vm.toggleFavorite(location) },
                                    onUpgrade: { showingPaywall = true },
                                    onNicknameChanged: { newNickname in
                                        try? appViewModel.repository?.updateNickname(location, nickname: newNickname)
                                    }
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                            }
                        } header: {
                            HStack {
                                Text(group.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DesignTokens.parkTextSecondary)
                                    .textCase(nil)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(DesignTokens.parkNavy)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func searchBar(vm: HistoryViewModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DesignTokens.parkTextSecondary)
                .font(.system(size: 15))

            TextField("Search address or notes…", text: Binding(
                get: { vm.searchQuery },
                set: {
                    vm.searchQuery = $0
                    vm.load()
                }
            ))
            .foregroundStyle(DesignTokens.parkTextPrimary)
            .font(.subheadline)
            .autocorrectionDisabled()

            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
                    vm.load()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func upgradeCard(hiddenCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Free keeps your most recent parking spot.")
                .font(.headline)
                .foregroundStyle(DesignTokens.parkTextPrimary)

            Text("Upgrade to unlock \(hiddenCount) more saved spot\(hiddenCount == 1 ? "" : "s"), search, nicknames, and longer retention.")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.parkTextSecondary)

            Button {
                showingPaywall = true
            } label: {
                Text("Unlock Full History")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(DesignTokens.parkCyan)
                    .foregroundStyle(DesignTokens.parkAccentForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - History Row

private struct HistoryRowView: View {
    let location: ParkingLocation
    let currentLocation: CLLocation?
    let distanceUnit: DistanceUnit
    let isPro: Bool
    var onReactivate: () -> Void
    var onDelete: () -> Void
    var onToggleFavorite: () -> Void
    var onUpgrade: () -> Void
    var onNicknameChanged: (String?) -> Void

    @State private var showingNicknameEditor = false
    @State private var nicknameDraft: String = ""

    var distanceText: String? {
        guard let current = currentLocation else { return nil }
        let meters = current.distance(from: location.clLocation)
        return distanceUnit.formatted(meters)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(location.isActive ? DesignTokens.parkCyan.opacity(0.15) : DesignTokens.parkSurfaceElevated)
                    .frame(width: 44, height: 44)

                Image(systemName: location.isActive ? "car.fill" : "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundStyle(location.isActive ? DesignTokens.parkCyan : DesignTokens.parkTextSecondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Primary label (nickname or address)
                HStack(spacing: 6) {
                    Text(location.displayAddress)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.parkTextPrimary)
                        .lineLimit(1)

                    if location.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.parkAccentText)
                    }
                }

                // Show raw address as sub-label when nickname is active
                if let nick = location.nickname, !nick.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(location.rawAddress)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                        .lineLimit(1)
                }

                // Date + distance
                HStack(spacing: 8) {
                    Text(location.savedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(DesignTokens.parkTextSecondary)

                    if let dist = distanceText {
                        Text("•")
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                        Text(dist + " away")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                }

                // Notes preview (if any)
                if !location.notes.isEmpty {
                    Text(location.notes)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.parkTextSecondary.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            if location.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.parkCyan)
            }
        }
        .padding(14)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !location.isActive {
                if isPro {
                    Button {
                        nicknameDraft = location.nickname ?? ""
                        showingNicknameEditor = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(DesignTokens.parkBlue)

                    Button(action: onToggleFavorite) {
                        Label(location.isFavorite ? "Unfavorite" : "Favorite",
                              systemImage: location.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                } else {
                    Button(action: onUpgrade) {
                        Label("Pro", systemImage: "star")
                    }
                    .tint(DesignTokens.parkCyan)
                }

                Button(action: onReactivate) {
                    Label("Set Active", systemImage: "car.fill")
                }
                .tint(DesignTokens.parkAccentText)
            }
        }
        .alert("Rename Location", isPresented: $showingNicknameEditor) {
            TextField("e.g. Work Garage, Airport P3", text: $nicknameDraft)
                .autocorrectionDisabled()
            Button("Save") {
                let trimmed = nicknameDraft.trimmingCharacters(in: .whitespaces)
                onNicknameChanged(trimmed.isEmpty ? nil : trimmed)
            }
            Button("Clear Name") {
                onNicknameChanged(nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Give this spot a custom name to find it faster.")
        }
    }
}
