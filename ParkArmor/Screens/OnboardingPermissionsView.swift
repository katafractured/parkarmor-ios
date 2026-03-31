import SwiftUI
import CoreLocation

struct OnboardingPermissionsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            DesignTokens.parkNavy.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Illustration
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.parkCyan.opacity(0.12))
                            .frame(width: 140, height: 140)

                        Image(systemName: "location.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(DesignTokens.parkCyan)
                    }

                    Text("Enable Location")
                        .font(.largeTitle.bold())
                        .foregroundStyle(DesignTokens.parkTextPrimary)

                    Text("ParkArmor uses GPS to save where you parked. Your location never leaves your device.")
                        .font(.body)
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                // Privacy note
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(DesignTokens.parkCyan)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("100% Private")
                            .font(.headline)
                            .foregroundStyle(DesignTokens.parkTextPrimary)
                        Text("No accounts. No cloud. No data collection whatsoever.")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                    Spacer()
                }
                .padding()
                .background(DesignTokens.parkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.bottom, 32)

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        appViewModel.locationManager.requestPermission()
                    } label: {
                        Text("Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(DesignTokens.parkCyan)
                            .foregroundStyle(DesignTokens.parkAccentForeground)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            let status = appViewModel.locationManager.authorizationStatus
            if status == .denied || status == .restricted {
                showPaywall = true
            }
        }
        .onChange(of: appViewModel.locationManager.authorizationStatus) { _, status in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                appViewModel.locationManager.startUpdating()
                showPaywall = true
            case .denied, .restricted:
                showPaywall = true
            default:
                break
            }
        }
        .navigationDestination(isPresented: $showPaywall) {
            OnboardingPaywallView()
        }
    }
}
