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
                        if vm.locations.isEmpty {
                            emptyState
                        } else {
                            historyList(vm: vm)
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

                if let vm = viewModel, !vm.locations.isEmpty {
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
    private func historyList(vm: HistoryViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !appViewModel.isPro && vm.availableHistoryCount > vm.locations.count {
                    upgradeCard(hiddenCount: vm.availableHistoryCount - vm.locations.count)
                }

                ForEach(vm.locations) { location in
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
                        onUpgrade: { showingPaywall = true }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private func upgradeCard(hiddenCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Free keeps your most recent parking spot.")
                .font(.headline)
                .foregroundStyle(DesignTokens.parkTextPrimary)

            Text("Upgrade to unlock \(hiddenCount) more saved spot\(hiddenCount == 1 ? "" : "s"), favorites, and longer retention.")
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

private struct HistoryRowView: View {
    let location: ParkingLocation
    let currentLocation: CLLocation?
    let distanceUnit: DistanceUnit
    let isPro: Bool
    var onReactivate: () -> Void
    var onDelete: () -> Void
    var onToggleFavorite: () -> Void
    var onUpgrade: () -> Void

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

            VStack(alignment: .leading, spacing: 4) {
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
                    Button(action: onToggleFavorite) {
                        Label(location.isFavorite ? "Unfavorite" : "Favorite", systemImage: location.isFavorite ? "star.slash" : "star")
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
    }
}
