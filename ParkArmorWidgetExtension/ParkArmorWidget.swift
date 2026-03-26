import CoreLocation
import SwiftData
import SwiftUI
import WidgetKit

struct ParkingWidgetEntry: TimelineEntry {
    let date: Date
    let activeParking: ActiveParkingSnapshot?
    let isPro: Bool
    let distanceText: String?
}

struct ActiveParkingSnapshot {
    let address: String
    let savedAt: Date
    let latitude: Double
    let longitude: Double
    let timerExpiresAt: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var elapsedString: String {
        let elapsed = max(0, Date().timeIntervalSince(savedAt))
        let totalSeconds = Int(elapsed)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "Just parked"
    }

    var timerString: String? {
        guard let expiresAt = timerExpiresAt, expiresAt > Date() else { return nil }
        let remaining = max(0, Int(expiresAt.timeIntervalSinceNow))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60

        if hours > 0 { return "\(hours)h \(minutes)m left" }
        return "\(minutes)m left"
    }
}

struct ParkingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParkingWidgetEntry {
        ParkingWidgetEntry(
            date: .now,
            activeParking: ActiveParkingSnapshot(
                address: "123 Main St, San Francisco",
                savedAt: Date().addingTimeInterval(-2700),
                latitude: 37.7749,
                longitude: -122.4194,
                timerExpiresAt: Date().addingTimeInterval(3600)
            ),
            isPro: true,
            distanceText: "0.4 mi away"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ParkingWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParkingWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let policy: TimelineReloadPolicy

        if entry.activeParking != nil {
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now.addingTimeInterval(300)
            policy = .after(nextRefresh)
        } else {
            policy = .never
        }

        completion(Timeline(entries: [entry], policy: policy))
    }

    private func makeEntry() -> ParkingWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.katafract.ParkArmor")
        let isPro = defaults?.bool(forKey: "isPro") ?? false
        let snapshot = fetchActiveParking()
        let distanceText = snapshot.flatMap { computeDistanceText(to: $0.coordinate, defaults: defaults) }

        return ParkingWidgetEntry(
            date: .now,
            activeParking: snapshot,
            isPro: isPro,
            distanceText: distanceText
        )
    }

    private func fetchActiveParking() -> ActiveParkingSnapshot? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.katafract.ParkArmor"
        ) else { return nil }

        let storeURL = groupURL.appendingPathComponent("parkarmor.store")
        let schema = Schema([ParkingLocation.self, ParkingPhoto.self, ParkingTimer.self])
        let config = ModelConfiguration(nil, schema: schema, url: storeURL, allowsSave: false)

        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return nil
        }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ParkingLocation>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.savedAt, order: .reverse)]
        )

        guard let location = try? context.fetch(descriptor).first else { return nil }

        return ActiveParkingSnapshot(
            address: location.displayAddress,
            savedAt: location.savedAt,
            latitude: location.latitude,
            longitude: location.longitude,
            timerExpiresAt: location.timer?.expiresAt
        )
    }

    private func computeDistanceText(to coordinate: CLLocationCoordinate2D, defaults: UserDefaults?) -> String? {
        guard let defaults,
              defaults.object(forKey: "lastKnownLatitude") != nil,
              defaults.object(forKey: "lastKnownLongitude") != nil
        else { return nil }

        let latitude = defaults.double(forKey: "lastKnownLatitude")
        let longitude = defaults.double(forKey: "lastKnownLongitude")
        let meters = CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))

        let distanceRaw = defaults.string(forKey: "distanceUnit") ?? DistanceUnit.miles.rawValue
        let unit = DistanceUnit(rawValue: distanceRaw) ?? .miles
        return unit.formatted(meters) + " away"
    }
}

struct ParkingWidgetEntryView: View {
    let entry: ParkingWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryRectangular:
            LockScreenWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

private struct SmallWidgetView: View {
    let entry: ParkingWidgetEntry

    var body: some View {
        Group {
            if let parking = entry.activeParking {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Parked", systemImage: "car.fill")
                            .font(.caption.bold())
                            .foregroundStyle(DesignTokens.parkCyan)
                        Spacer()
                    }

                    Spacer()

                    Text(parking.address)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.parkTextPrimary)
                        .lineLimit(2)

                    Label(parking.elapsedString, systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.parkTextSecondary)

                    if let distanceText = entry.distanceText {
                        Label(distanceText, systemImage: "figure.walk")
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }

                    if let timerString = parking.timerString {
                        Label(timerString, systemImage: "exclamationmark.circle.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                }
                .padding(14)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                    Text("No active parking")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                        .multilineTextAlignment(.center)
                    Text("Tap to save your spot")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(14)
            }
        }
        .containerBackground(DesignTokens.parkTabBarBackground, for: .widget)
    }
}

private struct MediumWidgetView: View {
    let entry: ParkingWidgetEntry

    var body: some View {
        Group {
            if let parking = entry.activeParking {
                HStack(spacing: 16) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(DesignTokens.parkCyan.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: "car.fill")
                                .font(.title3)
                                .foregroundStyle(DesignTokens.parkCyan)
                        }

                        Text(parking.elapsedString)
                            .font(.caption.bold())
                            .foregroundStyle(DesignTokens.parkCyan)

                        Text("elapsed")
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }

                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 1)
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Parked at")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.parkTextSecondary)

                        Text(parking.address)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DesignTokens.parkTextPrimary)
                            .lineLimit(2)

                        if let distanceText = entry.distanceText {
                            Label(distanceText, systemImage: "figure.walk")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.parkTextSecondary)
                        }

                        Spacer()

                        if let timerString = parking.timerString {
                            Label(timerString, systemImage: "timer")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                        } else {
                            Label("No meter set", systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.parkTextSecondary)
                        }

                        Text(parking.savedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            } else {
                HStack(spacing: 16) {
                    Image(systemName: "car.fill")
                        .font(.largeTitle)
                        .foregroundStyle(DesignTokens.parkTextSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("No active parking")
                            .font(.headline)
                            .foregroundStyle(DesignTokens.parkTextPrimary)
                        Text("Open ParkArmor and tap \"Park Here\" to save your spot.")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                }
                .padding(16)
            }
        }
        .containerBackground(DesignTokens.parkTabBarBackground, for: .widget)
    }
}

private struct LockScreenWidgetView: View {
    let entry: ParkingWidgetEntry

    var body: some View {
        Group {
            if let parking = entry.activeParking {
                HStack(spacing: 8) {
                    Image(systemName: "car.fill")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.parkCyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(parking.address)
                            .font(.caption.bold())
                            .lineLimit(1)

                        if let distanceText = entry.distanceText {
                            Text(distanceText)
                                .font(.caption2)
                        } else if let timerString = parking.timerString {
                            Text(timerString)
                                .font(.caption2)
                        } else {
                            Text(parking.elapsedString)
                                .font(.caption2)
                        }
                    }
                }
            } else {
                Label("Tap to park", systemImage: "car.fill")
                    .font(.caption)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct ParkArmorWidget: Widget {
    let kind = "com.katafract.ParkArmor.ParkingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkingWidgetProvider()) { entry in
            ParkingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ParkArmor")
        .description("See your parked car location and timer at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
