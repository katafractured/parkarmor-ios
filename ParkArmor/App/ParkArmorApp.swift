import KatafractStyle
import SwiftData
import SwiftUI
import WidgetKit

@main
struct ParkArmorApp: App {
    // ModelContainer stored as a property so it's initialized once and shared.
    // Uses the App Group URL so the widget can read the same store.
    let container: ModelContainer = {
        let schema = Schema([
            ParkingLocation.self,
            ParkingPhoto.self,
            ParkingTimer.self,
        ])

        // Prefer shared App Group container; fall back to default location.
        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.katafract.ParkArmor"
        ) {
            storeURL = groupURL.appendingPathComponent("parkarmor.store")
        } else {
            storeURL = URL.applicationSupportDirectory.appendingPathComponent("parkarmor.store")
        }

        let config = ModelConfiguration(nil, schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If migration fails, wipe and start fresh (acceptable for local-only data).
            let wipeConfig = ModelConfiguration(nil, schema: schema, url: storeURL, allowsSave: true)
            return (try? ModelContainer(for: schema, configurations: [wipeConfig]))
                ?? (try! ModelContainer(for: schema))
        }
    }()

    @State private var appViewModel = AppViewModel()
    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(appViewModel)
                    .tint(KataAccent.gold)

                if showingSplash {
                    LaunchSplashView(isShowing: $showingSplash)
                        .zIndex(1)
                }
            }
        }
        .modelContainer(container)
    }
}

// MARK: - Root View

struct RootView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if appViewModel.hasSeenOnboarding {
                AppTabView()
            } else {
                OnboardingView()
            }
        }
        .task {
            appViewModel.configure(context: modelContext)
            await appViewModel.onAppLaunch()
        }
        .onContinueUserActivity(NSUserActivityTypeLiveActivity) { _ in
            appViewModel.selectedTab = .map
            appViewModel.shouldPresentActiveParkingFromLiveActivity = true
        }
    }
}

enum AppTab: Hashable {
    case map
    case history
    case settings
}

struct AppTabView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        TabView(selection: Binding(
            get: { appViewModel.selectedTab },
            set: { appViewModel.selectedTab = $0 }
        )) {
            NavigationStack {
                MapScreenView()
            }
            .tag(AppTab.map)
            .tabItem {
                Label("Map", systemImage: "map.fill")
            }

            HistoryScreenView(showsDismissButton: false)
                .tag(AppTab.history)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsScreenView(showsDismissButton: false)
                .tag(AppTab.settings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(DesignTokens.parkTabBarAccent)
        .toolbarBackground(DesignTokens.parkTabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
    }
}
