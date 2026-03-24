import SwiftUI
import SwiftData

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

        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // If migration fails, wipe and start fresh (acceptable for local-only data).
            let wipeConfig = ModelConfiguration(schema: schema, url: storeURL, allowsSave: true)
            return (try? ModelContainer(for: schema, configurations: [wipeConfig]))
                ?? (try! ModelContainer(for: schema))
        }
    }()

    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appViewModel)
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
                NavigationStack {
                    MapScreenView()
                }
            } else {
                OnboardingView()
            }
        }
        .task {
            appViewModel.configure(context: modelContext)
            await appViewModel.onAppLaunch()
        }
    }
}
