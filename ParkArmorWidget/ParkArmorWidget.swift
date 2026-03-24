import WidgetKit
import SwiftUI
import SwiftData
import CoreLocation

// MARK: - Snapshot Model (no SwiftData dependency in widget views)

struct ParkingLocationSnapshot {
    let address: String
    let savedAt: Date
    let latitude: Double
    let longitude: Double
    let isPro: Bool

    static let placeholder = ParkingLocationSnapshot(
        address: "123 Main Street",
        savedAt: Date().addingTimeInterval(-5400),
        latitude: 37.3317,
        longitude: -122.0307,
        isPro: false
    )
}

// MARK: - Timeline Entry

struct ParkArmorEntry: TimelineEntry {
    let date: Date
    let snapshot: ParkingLocationSnapshot?
}

// MARK: - Timeline Provider

struct ParkArmorTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParkArmorEntry {
        ParkArmorEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ParkArmorEntry) -> Void) {
        completion(ParkArmorEntry(date: Date(), snapshot: fetchSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParkArmorEntry>) -> Void) {
        let snapshot = fetchSnapshot()
        let now = Date()

        // Generate 60 entries at 1-minute intervals for elapsed timer
        var entries: [ParkArmorEntry] = []
        for offset in 0..<60 {
            let entryDate = now.addingTimeInterval(Double(offset) * 60)
            entries.append(ParkArmorEntry(date: entryDate, snapshot: snapshot))
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func fetchSnapshot() -> ParkingLocationSnapshot? {
        let defaults = UserDefaults(suiteName: "group.com.katafract.ParkArmor")
        let isPro = defaults?.bool(forKey: "isPro") ?? false

        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.katafract.ParkArmor"
        ) else { return nil }

        let storeURL = groupURL.appendingPathComponent("parkarmor.store")
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }

        do {
            let schema = Schema([ParkingLocationModel.self])
            let config = ModelConfiguration(schema: schema, url: storeURL, allowsSave: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)

            let descriptor = FetchDescriptor<ParkingLocationModel>(
                predicate: #Predicate { $0.isActive }
            )
            if let active = try context.fetch(descriptor).first {
                return ParkingLocationSnapshot(
                    address: active.address,
                    savedAt: active.savedAt,
                    latitude: active.latitude,
                    longitude: active.longitude,
                    isPro: isPro
                )
            }
        } catch {}
        return nil
    }
}

// MARK: - Lightweight Model for Widget

// The widget must redeclare the model to avoid importing the app target.
// This model mirrors ParkingLocation but is named differently to avoid conflicts.
@Model final class ParkingLocationModel {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var address: String
    var notes: String
    var savedAt: Date
    var isActive: Bool
    var isPinned: Bool

    init() {
        self.id = UUID()
        self.latitude = 0
        self.longitude = 0
        self.address = ""
        self.notes = ""
        self.savedAt = Date()
        self.isActive = false
        self.isPinned = false
    }
}

// MARK: - Widget Views

struct ParkArmorWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: ParkArmorEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: Small Widget (2×2)

private struct SmallWidgetView: View {
    let entry: ParkArmorEntry

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.055, blue: 0.102)

            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 0, green: 0.941, blue: 1.0))

                    Spacer()

                    Text("Parked")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))

                    Text(timerText(since: snapshot.savedAt))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0, green: 0.941, blue: 1.0))
                        .minimumScaleFactor(0.7)
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                noActiveParkingSmall
            }
        }
    }

    private var noActiveParkingSmall: some View {
        VStack(spacing: 6) {
            Image(systemName: "car.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.3))
            Text("No parking\nsaved")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.4))
        }
    }
}

// MARK: Medium Widget (2×4)

private struct MediumWidgetView: View {
    let entry: ParkArmorEntry
    let cyan = Color(red: 0, green: 0.941, blue: 1.0)
    let navy = Color(red: 0.039, green: 0.055, blue: 0.102)

    var body: some View {
        ZStack {
            navy

            if let snapshot = entry.snapshot {
                HStack(spacing: 16) {
                    // Left: icon + timer
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(cyan)

                        Spacer()

                        Text("Parked for")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))

                        Text(timerText(since: snapshot.savedAt))
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundStyle(cyan)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxHeight: .infinity, alignment: .leading)

                    Divider()
                        .background(.white.opacity(0.15))

                    // Right: address
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))

                        Text(snapshot.address.isEmpty ? "Saved Location" : snapshot.address)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(3)

                        Spacer()

                        Text(snapshot.savedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxHeight: .infinity, alignment: .leading)
                }
                .padding(16)
            } else {
                noActiveParkingMedium
            }
        }
    }

    private var noActiveParkingMedium: some View {
        HStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.2))
            VStack(alignment: .leading) {
                Text("ParkArmor")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.6))
                Text("No active parking saved")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(16)
    }
}

// MARK: Large Widget (4×4)

private struct LargeWidgetView: View {
    let entry: ParkArmorEntry
    let cyan = Color(red: 0, green: 0.941, blue: 1.0)
    let navy = Color(red: 0.039, green: 0.055, blue: 0.102)

    var body: some View {
        ZStack {
            navy

            if let snapshot = entry.snapshot {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundStyle(cyan)
                        Text("ParkArmor")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Active")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(cyan.opacity(0.2))
                            .foregroundStyle(cyan)
                            .clipShape(Capsule())
                    }

                    Divider().background(.white.opacity(0.15))

                    // Address
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Parked at")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(snapshot.address.isEmpty ? "Saved Location" : snapshot.address)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }

                    // Timer
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(timerText(since: snapshot.savedAt))
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundStyle(cyan)
                    }

                    Spacer()

                    // Time saved
                    Text("Saved \(snapshot.savedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(20)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("No Active Parking")
                        .font(.title3.bold())
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Open ParkArmor to save your spot")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.3))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

// MARK: - Elapsed Timer Helper

private func timerText(since date: Date) -> String {
    let elapsed = max(0, Date().timeIntervalSince(date))
    let h = Int(elapsed) / 3600
    let m = (Int(elapsed) % 3600) / 60
    let s = Int(elapsed) % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%d:%02d", m, s)
}

// MARK: - Widget

struct ParkArmorWidget: Widget {
    let kind: String = "ParkArmorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkArmorTimelineProvider()) { entry in
            ParkArmorWidgetEntryView(entry: entry)
                .containerBackground(Color(red: 0.039, green: 0.055, blue: 0.102), for: .widget)
        }
        .configurationDisplayName("My Car Location")
        .description("See your current parking spot and elapsed time.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
