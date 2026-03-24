import CoreLocation
import SwiftUI

struct HistoryScreenView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    var onReactivated: ((ParkingLocation) -> Void)?

    @State private var viewModel: HistoryViewModel?
    @State private var showingPaywall = false

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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(DesignTokens.parkCyan)
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(storeKit: appViewModel.storeKitManager) {
                    showingPaywall = false
                }
            }
        }
        .task {
            let vm = HistoryViewModel(repository: appViewModel.repository!, isPro: appViewModel.isPro)
            viewModel = vm
            vm.load()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(DesignTokens.parkTextSecondary.opacity(0.4))

            Text("No Parking History")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text("Your past parking spots will appear here.")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.parkTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private func historyList(vm: HistoryViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.locations) { location in
                    HistoryRowView(
                        location: location,
                        currentLocation: appViewModel.locationManager.currentLocation,
                        distanceUnit: appViewModel.preferences.distanceUnit,
                        isPro: appViewModel.isPro,
                        onReactivate: {
                            vm.reactivate(location)
                            onReactivated?(location)
                            dismiss()
                        },
                        onDelete: { vm.delete(location) },
                        onUpgrade: { showingPaywall = true }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .overlay(alignment: .bottom) {
            if !vm.isPro && vm.locations.count > 1 {
                proGateOverlay
            }
        }
    }

    private var proGateOverlay: some View {
        VStack(spacing: 12) {
            Text("Unlock Full History with Pro")
                .font(.headline)
                .foregroundStyle(.white)

            Button {
                showingPaywall = true
            } label: {
                Text("Upgrade — $2.99")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(DesignTokens.parkCyan)
                    .foregroundStyle(DesignTokens.parkNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
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
    var onUpgrade: () -> Void

    var distanceText: String? {
        guard let current = currentLocation else { return nil }
        let meters = current.distance(from: location.clLocation)
        return distanceUnit.formatted(meters)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(location.isActive ? DesignTokens.parkCyan.opacity(0.15) : DesignTokens.parkSurfaceElevated)
                    .frame(width: 44, height: 44)

                Image(systemName: location.isActive ? "car.fill" : "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundStyle(location.isActive ? DesignTokens.parkCyan : DesignTokens.parkTextSecondary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(location.displayAddress)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

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
        .swipeActions(edge: .leading) {
            if !location.isActive {
                Button(action: onReactivate) {
                    Label("Set Active", systemImage: "car.fill")
                }
                .tint(DesignTokens.parkCyan)
            }
        }
        .blur(radius: !isPro && !location.isActive ? 4 : 0)
        .overlay {
            if !isPro && !location.isActive {
                RoundedRectangle(cornerRadius: 14)
                    .fill(DesignTokens.parkNavy.opacity(0.5))
                    .overlay {
                        Button("Pro") { onUpgrade() }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(DesignTokens.parkCyan)
                            .foregroundStyle(DesignTokens.parkNavy)
                            .clipShape(Capsule())
                    }
            }
        }
    }
}
