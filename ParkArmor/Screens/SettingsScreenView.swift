import StoreKit
import SwiftUI

struct SettingsScreenView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingPaywall = false
    @State private var showingClearHistoryConfirmation = false
    @State private var distanceUnit: DistanceUnit = .miles
    @State private var timeFormat: TimeFormat = .elapsed
    @State private var timerAlertMode: TimerAlertMode = .atExpiration
    @State private var historyRetention: HistoryRetentionOption = .thirtyDays

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
                    subscriptionSection
                    preferencesSection
                    aboutSection
                }
                .listStyle(.insetGrouped)
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
            .confirmationDialog(
                "Clear parking history?",
                isPresented: $showingClearHistoryConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) {
                    try? appViewModel.repository?.clearHistory()
                }
            } message: {
                Text("This deletes saved inactive parking history. Your active parking session stays intact.")
            }
            .task {
                distanceUnit = appViewModel.preferences.distanceUnit
                timeFormat = appViewModel.preferences.timeFormat
                timerAlertMode = appViewModel.preferences.timerAlertMode
                historyRetention = clampedHistoryRetention(appViewModel.preferences.historyRetention)
            }
            .onChange(of: distanceUnit) { _, newValue in
                appViewModel.preferences.distanceUnit = newValue
            }
            .onChange(of: timeFormat) { _, newValue in
                appViewModel.preferences.timeFormat = newValue
            }
            .onChange(of: timerAlertMode) { _, newValue in
                appViewModel.preferences.timerAlertMode = newValue
            }
            .onChange(of: historyRetention) { _, newValue in
                let clampedValue = clampedHistoryRetention(newValue)
                if historyRetention != clampedValue {
                    historyRetention = clampedValue
                }
                appViewModel.preferences.historyRetention = clampedValue
            }
        }
    }

    private var subscriptionSection: some View {
        Section("Pro Access") {
            if appViewModel.isPro {
                HStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(DesignTokens.parkBlue)
                    Text("ParkArmor Pro")
                        .foregroundStyle(DesignTokens.parkTextPrimary)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DesignTokens.parkBlue)
                }
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.checkered")
                            .foregroundStyle(DesignTokens.parkAccentText)
                        Text("Upgrade to Pro")
                            .foregroundStyle(DesignTokens.parkTextPrimary)
                        Spacer()
                        Text(appViewModel.storeKitManager.proProduct?.displayPrice ?? "$3.99")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DesignTokens.parkAccentText)
                    }
                }

                Button {
                    Task { await appViewModel.storeKitManager.restorePurchases() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                        Text("Restore Purchase")
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                }
            }
        }
        .listRowBackground(DesignTokens.parkSurface)
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            preferenceMenuRow(
                title: "Distance",
                systemImage: "ruler",
                selection: $distanceUnit,
                options: DistanceUnit.allCases,
                titleForOption: { $0.rawValue.capitalized }
            )

            preferenceMenuRow(
                title: "Time Display",
                systemImage: "clock",
                selection: $timeFormat,
                options: TimeFormat.allCases,
                titleForOption: {
                    switch $0 {
                    case .elapsed: return "Elapsed (2h 15m)"
                    case .clockTime: return "Clock time (Parked at 2:30 PM)"
                    }
                }
            )

            settingsToggleRow(
                title: "Notifications",
                systemImage: "bell.fill",
                isOn: Binding(
                    get: { appViewModel.preferences.notificationsEnabled },
                    set: { appViewModel.preferences.notificationsEnabled = $0 }
                )
            )

            if appViewModel.isPro {
                preferenceMenuRow(
                    title: "Timer Alerts",
                    systemImage: "timer",
                    selection: $timerAlertMode,
                    options: TimerAlertMode.allCases,
                    titleForOption: \.title
                )
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Label("Advanced Timer Alerts", systemImage: "timer")
                            .foregroundStyle(DesignTokens.parkTextPrimary)
                        Spacer()
                        ProBadge()
                    }
                }
            }

            settingsToggleRow(
                title: "Save Parking History",
                systemImage: "clock.arrow.circlepath",
                isOn: Binding(
                    get: { appViewModel.preferences.saveParkingHistory },
                    set: { appViewModel.preferences.saveParkingHistory = $0 }
                )
            )

            if appViewModel.preferences.saveParkingHistory {
                preferenceMenuRow(
                    title: "History Retention",
                    systemImage: "archivebox",
                    selection: $historyRetention,
                    options: availableHistoryRetentionOptions,
                    titleForOption: \.title
                )
            }

            Button(role: .destructive) {
                showingClearHistoryConfirmation = true
            } label: {
                HStack(spacing: 12) {
                    Label("Clear History", systemImage: "trash")
                    Spacer()
                }
                .foregroundStyle(DesignTokens.parkDestructive)
            }
        }
        .listRowBackground(DesignTokens.parkSurface)
    }

    private var aboutSection: some View {
        Section("About") {
            settingsLinkRow(
                title: "Privacy Policy",
                systemImage: "lock.shield",
                urlString: "https://katafract.com/privacy/parkarmor"
            )

            settingsLinkRow(
                title: "Terms of Service",
                systemImage: "doc.text",
                urlString: "https://katafract.com/terms/parkarmor"
            )

            HStack(spacing: 12) {
                Label("Version", systemImage: "info.circle")
                    .foregroundStyle(DesignTokens.parkTextPrimary)
                Spacer()
                Text(appVersion)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.parkTextSecondary)
            }
        }
        .listRowBackground(DesignTokens.parkSurface)
    }

    private func settingsToggleRow(title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(DesignTokens.parkTextPrimary)
            Spacer(minLength: 16)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DesignTokens.parkBlue)
        }
    }

    private func settingsLinkRow(title: String, systemImage: String, urlString: String) -> some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(DesignTokens.parkTextPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.parkTextSecondary)
            }
        }
    }

    private func preferenceMenuRow<Option: Hashable>(
        title: String,
        systemImage: String,
        selection: Binding<Option>,
        options: [Option],
        titleForOption: @escaping (Option) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(DesignTokens.parkTextPrimary)

            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(titleForOption(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(DesignTokens.parkAccentText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignTokens.parkAccentSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 2)
    }

    private var availableHistoryRetentionOptions: [HistoryRetentionOption] {
        if appViewModel.isPro {
            return HistoryRetentionOption.allCases
        }
        return [.sevenDays, .thirtyDays]
    }

    private func clampedHistoryRetention(_ option: HistoryRetentionOption) -> HistoryRetentionOption {
        if appViewModel.isPro {
            return option
        }
        switch option {
        case .ninetyDays, .forever:
            return .thirtyDays
        case .sevenDays, .thirtyDays:
            return option
        }
    }
}
