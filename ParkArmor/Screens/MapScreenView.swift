import SwiftUI
import MapKit

struct MapScreenView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var mapVM = MapViewModel()
    @State private var showingSaveParking = false
    @State private var showingPaywall = false
    @State private var showingActiveParking = false
    @State private var allLocations: [ParkingLocation] = []

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen map
            Map(position: $mapVM.cameraPosition) {
                UserAnnotation()

                ForEach(allLocations) { location in
                    Annotation(
                        location.displayAddress,
                        coordinate: location.coordinate
                    ) {
                        Button {
                            if !location.isActive && appViewModel.requiresPro(feature: "history") {
                                return
                            }
                            mapVM.centerOn(parking: location)
                            showingActiveParking = location.isActive
                        } label: {
                            ParkingPinView(isActive: location.isActive)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(location.isActive ? "Active parking location" : "Parking history location")
                        .accessibilityHint(location.isActive ? "Opens your active parking details" : "Opens this saved parking location")
                        .accessibilityValue(location.displayAddress)
                        .simultaneousGesture(TapGesture().onEnded {
                            if !location.isActive && appViewModel.requiresPro(feature: "history") {
                                return
                            }
                        })
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()

            // Active parking banner
            if let active = appViewModel.activeParking {
                ActiveParkingBanner(parking: active) {
                    showingActiveParking = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }

            // FAB — park here
            if appViewModel.activeParking == nil {
                Button {
                    if appViewModel.locationManager.isAuthorized {
                        showingSaveParking = true
                    } else {
                        appViewModel.locationManager.requestPermission()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Park Here")
                            .font(.headline)
                    }
                    .padding(.horizontal, 28)
                    .frame(height: 54)
                    .background(DesignTokens.parkCyan)
                    .foregroundStyle(DesignTokens.parkAccentForeground)
                    .clipShape(Capsule())
                    .shadow(color: DesignTokens.parkCyan.opacity(0.4), radius: 12, y: 4)
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("ParkArmor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(DesignTokens.parkNavy.opacity(0.85), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingSaveParking) {
            SaveParkingView { saved in
                showingSaveParking = false
                appViewModel.activeParking = saved
                refreshLocations()
            }
        }
        .sheet(isPresented: $showingActiveParking) {
            if let active = appViewModel.activeParking {
                ActiveParkingView(parking: active) {
                    showingActiveParking = false
                    appViewModel.refreshActiveParking()
                    refreshLocations()
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(storeKit: appViewModel.storeKitManager) {
                showingPaywall = false
            }
        }
        .onChange(of: appViewModel.showingPaywall) { _, showing in
            showingPaywall = showing
        }
        .onChange(of: appViewModel.shouldPresentActiveParkingFromLiveActivity) { _, shouldPresent in
            guard shouldPresent else { return }
            appViewModel.refreshActiveParking()
            if appViewModel.activeParking != nil {
                showingActiveParking = true
            }
            appViewModel.shouldPresentActiveParkingFromLiveActivity = false
        }
        .onAppear {
            appViewModel.refreshActiveParking()
            refreshLocations()
            if appViewModel.shouldPresentActiveParkingFromLiveActivity,
               appViewModel.activeParking != nil {
                showingActiveParking = true
                appViewModel.shouldPresentActiveParkingFromLiveActivity = false
            }
        }
    }

    private func refreshLocations() {
        allLocations = (try? appViewModel.repository?.fetchHistory()) ?? []
    }
}

// MARK: - Parking Pin

private struct ParkingPinView: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? DesignTokens.parkCyan : Color.gray.opacity(0.4))
                .frame(width: 36, height: 36)

            Image(systemName: isActive ? "car.fill" : "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isActive ? DesignTokens.parkAccentForeground : DesignTokens.parkTextPrimary)
        }
        .shadow(color: isActive ? DesignTokens.parkCyan.opacity(0.5) : .clear, radius: 8)
    }
}

// MARK: - Active Parking Banner

private struct ActiveParkingBanner: View {
    let parking: ParkingLocation
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(DesignTokens.parkCyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(parking.displayAddress)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.parkTextPrimary)
                        .lineLimit(1)

                    CompactTimerDisplay(savedAt: parking.savedAt)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(DesignTokens.parkTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(DesignTokens.parkCyan.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
