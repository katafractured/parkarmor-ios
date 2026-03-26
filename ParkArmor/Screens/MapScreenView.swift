import SwiftUI
import MapKit

struct MapScreenView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var mapVM = MapViewModel()
    @State private var showingSaveParking = false
    @State private var showingPaywall = false
    @State private var showingActiveParking = false
    @State private var showingAutoDetectPrompt = false
    @State private var allLocations: [ParkingLocation] = []
    @State private var mapSpan: MKCoordinateSpan = .init(latitudeDelta: 0.05, longitudeDelta: 0.05)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen map
            MapReader { proxy in
                Map(position: $mapVM.cameraPosition) {
                    UserAnnotation()

                    // Active parking — always show individually
                    ForEach(allLocations.filter(\.isActive)) { location in
                        Annotation(location.displayAddress, coordinate: location.coordinate) {
                            Button {
                                mapVM.centerOn(parking: location)
                                showingActiveParking = true
                            } label: {
                                ParkingPinView(isActive: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Active parking location")
                            .accessibilityHint("Opens your active parking details")
                            .accessibilityValue(location.displayAddress)
                        }
                    }

                    // History — clustered
                    if appViewModel.isPro {
                        let historyClusters = mapVM.clusters(for: allLocations, span: mapSpan)
                        ForEach(historyClusters) { cluster in
                            if cluster.isSingle, let location = cluster.single {
                                Annotation(location.displayAddress, coordinate: cluster.coordinate) {
                                    Button {
                                        mapVM.centerOn(parking: location)
                                        showingActiveParking = false
                                    } label: {
                                        ParkingPinView(isActive: false)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Parking history location")
                                    .accessibilityValue(location.displayAddress)
                                }
                            } else {
                                Annotation("\(cluster.count) spots", coordinate: cluster.coordinate) {
                                    ClusterPinView(count: cluster.count)
                                        .accessibilityLabel("\(cluster.count) past parking locations")
                                }
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea()
                .onMapCameraChange { context in
                    mapSpan = context.region.span
                }
            }

            // Active parking banner
            if let active = appViewModel.activeParking {
                ActiveParkingBanner(parking: active) {
                    showingActiveParking = true
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
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
        .onChange(of: appViewModel.shouldShowAutoDetectPrompt) { _, should in
            if should {
                showingAutoDetectPrompt = true
                appViewModel.shouldShowAutoDetectPrompt = false
            }
        }
        .confirmationDialog(
            "Did you just park?",
            isPresented: $showingAutoDetectPrompt,
            titleVisibility: .visible
        ) {
            Button("Yes, Save My Spot") {
                showingSaveParking = true
            }
            Button("No", role: .cancel) {}
        } message: {
            Text("ParkArmor detected you may have just parked. Save your location?")
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
        let history = (try? appViewModel.repository?.fetchHistory()) ?? []
        if let active = appViewModel.activeParking {
            allLocations = [active] + history
        } else {
            allLocations = history
        }
    }
}

// MARK: - Parking Pin

private struct ParkingPinView: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? DesignTokens.parkCyan : Color.gray.opacity(0.75))
                .frame(width: 36, height: 36)

            Image(systemName: isActive ? "car.fill" : "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isActive ? DesignTokens.parkAccentForeground : DesignTokens.parkTextPrimary)
        }
        .shadow(color: isActive ? DesignTokens.parkCyan.opacity(0.5) : .clear, radius: 8)
    }
}

// MARK: - Cluster Pin

private struct ClusterPinView: View {
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.82))
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                )

            Text("\(count)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
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
                    .font(.system(size: 20))
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
                    .foregroundStyle(DesignTokens.parkCyan)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(DesignTokens.parkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(DesignTokens.parkCyan.opacity(0.65), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
        }
    }
}
