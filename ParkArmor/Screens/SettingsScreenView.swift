import SwiftUI

struct SettingsScreenView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingPaywall = false
    var showsDismissButton = true

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.parkNavy.ignoresSafeArea()

                List {
                    // Pro status
                    Section {
                        if appViewModel.isPro {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .foregroundStyle(DesignTokens.parkCyan)
                                Text("ParkArmor Pro")
                                    .foregroundStyle(DesignTokens.parkTextPrimary)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DesignTokens.parkCyan)
                            }
                        } else {
                            Button {
                                showingPaywall = true
                            } label: {
                                HStack {
                                    Image(systemName: "shield.checkered")
                                        .foregroundStyle(DesignTokens.parkAccentText)
                                    Text("Upgrade to Pro")
                                        .foregroundStyle(DesignTokens.parkTextPrimary)
                                    Spacer()
                                    Text("$2.99")
                                        .foregroundStyle(DesignTokens.parkAccentText)
                                        .font(.subheadline.bold())
                                }
                            }

                            Button {
                                Task { await appViewModel.storeKitManager.restorePurchases() }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundStyle(DesignTokens.parkTextSecondary)
                                    Text("Restore Purchase")
                                        .foregroundStyle(DesignTokens.parkTextSecondary)
                                }
                            }
                        }
                    } header: {
                        Text("Subscription")
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                    .listRowBackground(DesignTokens.parkSurface)

                    // Preferences
                    Section {
                        HStack {
                            Label("Distance", systemImage: "ruler")
                                .foregroundStyle(DesignTokens.parkTextPrimary)
                            Spacer()
                            Menu {
                                ForEach(DistanceUnit.allCases, id: \.self) { unit in
                                    Button(unit.rawValue.capitalized) {
                                        appViewModel.preferences.distanceUnit = unit
                                    }
                                }
                            } label: {
                                settingsValueLabel(appViewModel.preferences.distanceUnit.rawValue.capitalized)
                            }
                        }

                        HStack {
                            Label("Notifications", systemImage: "bell.fill")
                                .foregroundStyle(DesignTokens.parkTextPrimary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appViewModel.preferences.notificationsEnabled },
                                set: { appViewModel.preferences.notificationsEnabled = $0 }
                            ))
                            .tint(DesignTokens.parkCyan)
                            .labelsHidden()
                        }

                        if appViewModel.isPro {
                            HStack {
                                Label("Timer Alerts", systemImage: "timer")
                                    .foregroundStyle(DesignTokens.parkTextPrimary)
                                Spacer()
                                Menu {
                                    ForEach(TimerAlertMode.allCases, id: \.self) { mode in
                                        Button(mode.title) {
                                            appViewModel.preferences.timerAlertMode = mode
                                        }
                                    }
                                } label: {
                                    settingsValueLabel(appViewModel.preferences.timerAlertMode.title)
                                }
                            }
                        } else {
                            Button {
                                showingPaywall = true
                            } label: {
                                HStack {
                                    Label("Advanced Timer Alerts", systemImage: "timer")
                                        .foregroundStyle(DesignTokens.parkTextPrimary)
                                    Spacer()
                                    ProBadge()
                                }
                            }
                        }
                    } header: {
                        Text("Preferences")
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                    .listRowBackground(DesignTokens.parkSurface)

                    // About
                    Section {
                        HStack {
                            Label("Privacy Policy", systemImage: "lock.shield")
                                .foregroundStyle(DesignTokens.parkTextPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.parkTextSecondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: "https://katafract.com/privacy-parkarmor.html") {
                                UIApplication.shared.open(url)
                            }
                        }

                        HStack {
                            Label("Terms of Service", systemImage: "doc.text")
                                .foregroundStyle(DesignTokens.parkTextPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.parkTextSecondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let url = URL(string: "https://katafract.com/terms-parkarmor") {
                                UIApplication.shared.open(url)
                            }
                        }

                        HStack {
                            Label("Version", systemImage: "info.circle")
                                .foregroundStyle(DesignTokens.parkTextPrimary)
                            Spacer()
                            Text(appVersion)
                                .foregroundStyle(DesignTokens.parkTextSecondary)
                                .font(.caption)
                        }
                    } header: {
                        Text("About")
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                    .listRowBackground(DesignTokens.parkSurface)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.parkNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(DesignTokens.parkAccentText)
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(storeKit: appViewModel.storeKitManager) {
                    showingPaywall = false
                }
            }
        }
    }

    private func settingsValueLabel(_ value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(DesignTokens.parkAccentText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(DesignTokens.parkAccentSurface)
        .clipShape(Capsule())
    }
}
