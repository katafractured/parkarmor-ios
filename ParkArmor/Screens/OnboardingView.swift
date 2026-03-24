import SwiftUI

struct OnboardingView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showPermissions = false

    private let valueProps: [(String, String, String)] = [
        ("location.fill", "One Tap Save", "Press a button. Your exact spot is pinned."),
        ("camera.fill", "Photo + Notes", "Photograph the sign. Add 'Level 3, Row B'."),
        ("arrow.triangle.turn.up.right.diamond.fill", "Walk Back Easy", "Compass + walking directions lead you home."),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.parkNavy.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Hero
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.parkCyan.opacity(0.1))
                                .frame(width: 160, height: 160)

                            Image(systemName: "shield.checkered")
                                .font(.system(size: 72, weight: .medium))
                                .foregroundStyle(DesignTokens.parkCyan)
                        }
                        .padding(.top, 60)

                        Text("ParkArmor")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(DesignTokens.parkTextPrimary)

                        Text("Never forget where you parked.")
                            .font(.title3)
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Value props
                    VStack(spacing: 4) {
                        ForEach(valueProps, id: \.1) { icon, title, description in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(DesignTokens.parkCyan)
                                    .frame(width: 32)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .font(.headline)
                                        .foregroundStyle(DesignTokens.parkTextPrimary)
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(DesignTokens.parkTextSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                        }
                    }
                    .background(DesignTokens.parkSurface.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)

                    Spacer()

                    // CTA
                    VStack(spacing: 12) {
                        Button {
                            showPermissions = true
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(DesignTokens.parkCyan)
                                .foregroundStyle(DesignTokens.parkAccentForeground)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)

                        Button("Skip for Now") {
                            appViewModel.completeOnboarding()
                        }
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                    .padding(.bottom, 48)
                }
            }
            .navigationDestination(isPresented: $showPermissions) {
                OnboardingPermissionsView()
            }
        }
    }
}
