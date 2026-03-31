import CoreLocation
import SwiftUI
import WidgetKit

private enum SharedKeys {
    static let suiteName = "group.com.katafract.ParkArmor"
    static let activeParkingAddress = "watchActiveParkingAddress"
    static let activeParkingLatitude = "watchActiveParkingLatitude"
    static let activeParkingLongitude = "watchActiveParkingLongitude"
    static let activeParkingSavedAt = "watchActiveParkingSavedAt"
    static let activeParkingTimerExpiresAt = "watchActiveParkingTimerExpiresAt"
    static let userLatitude = "watchUserLatitude"
    static let userLongitude = "watchUserLongitude"
    static let distanceUnit = "distanceUnit"
    static let watchSyncState = "watchSyncState"
}

struct ParkArmorComplicationEntry: TimelineEntry {
    let date: Date
    let address: String?
    let distanceText: String?
    let timerText: String?
    let isParked: Bool
    let isCached: Bool
}

struct ParkArmorComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ParkArmorComplicationEntry {
        ParkArmorComplicationEntry(
            date: .now,
            address: "123 Main St",
            distanceText: "0.3 mi",
            timerText: "42m left",
            isParked: true,
            isCached: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ParkArmorComplicationEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ParkArmorComplicationEntry>) -> Void) {
        let entry = makeEntry()
        let policy: TimelineReloadPolicy

        if entry.isParked {
            policy = .after(.now.addingTimeInterval(300))
        } else {
            policy = .never
        }

        completion(Timeline(entries: [entry], policy: policy))
    }

    private func makeEntry() -> ParkArmorComplicationEntry {
        guard let defaults = UserDefaults(suiteName: SharedKeys.suiteName),
              let address = defaults.string(forKey: SharedKeys.activeParkingAddress),
              defaults.object(forKey: SharedKeys.activeParkingLatitude) != nil,
              defaults.object(forKey: SharedKeys.activeParkingLongitude) != nil,
              defaults.object(forKey: SharedKeys.activeParkingSavedAt) != nil
        else {
            return ParkArmorComplicationEntry(date: .now, address: nil, distanceText: nil, timerText: nil, isParked: false, isCached: false)
        }

        let parkingLatitude = defaults.double(forKey: SharedKeys.activeParkingLatitude)
        let parkingLongitude = defaults.double(forKey: SharedKeys.activeParkingLongitude)
        let distanceText = formattedDistance(from: defaults, to: CLLocationCoordinate2D(latitude: parkingLatitude, longitude: parkingLongitude))
        let timerText = formattedTimer(from: defaults)
        let isCached = defaults.string(forKey: SharedKeys.watchSyncState) == "cached"

        return ParkArmorComplicationEntry(
            date: .now,
            address: address,
            distanceText: distanceText,
            timerText: timerText,
            isParked: true,
            isCached: isCached
        )
    }

    private func formattedDistance(from defaults: UserDefaults, to parking: CLLocationCoordinate2D) -> String? {
        guard defaults.object(forKey: SharedKeys.userLatitude) != nil,
              defaults.object(forKey: SharedKeys.userLongitude) != nil
        else { return nil }

        let user = CLLocation(
            latitude: defaults.double(forKey: SharedKeys.userLatitude),
            longitude: defaults.double(forKey: SharedKeys.userLongitude)
        )
        let car = CLLocation(latitude: parking.latitude, longitude: parking.longitude)
        let meters = user.distance(from: car)

        let distanceUnit = defaults.string(forKey: SharedKeys.distanceUnit) ?? "miles"
        if meters < 50 { return "Here" }

        if distanceUnit == "km" {
            if meters < 1000 {
                return "\(Int(meters)) m"
            }
            return String(format: "%.1f km", meters / 1000)
        }

        let miles = meters / 1609.344
        if miles < 0.1 {
            return "\(Int(meters * 3.28084)) ft"
        }
        return String(format: "%.1f mi", miles)
    }

    private func formattedTimer(from defaults: UserDefaults) -> String? {
        guard defaults.object(forKey: SharedKeys.activeParkingTimerExpiresAt) != nil else { return nil }
        let expiresAt = defaults.double(forKey: SharedKeys.activeParkingTimerExpiresAt)
        guard expiresAt > 0 else { return nil }

        let remaining = Date(timeIntervalSince1970: expiresAt).timeIntervalSinceNow
        guard remaining > 0 else { return nil }

        let totalMinutes = Int(remaining) / 60
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)h \(minutes)m"
        }
        return "\(totalMinutes)m"
    }
}

struct ParkArmorWatchComplicationEntryView: View {
    let entry: ParkArmorComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            inlineView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.isParked {
                VStack(spacing: 2) {
                    Image(systemName: entry.isCached ? "clock.arrow.circlepath" : "car.fill")
                    Text(circularPrimaryText)
                        .font(.system(size: 10, weight: .bold))
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(entry.isCached ? .yellow : .cyan)
            } else {
                Image(systemName: "car")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var cornerView: some View {
        Group {
            if entry.isParked {
                Label {
                    Text(entry.isCached ? "Cached" : (entry.distanceText ?? "--"))
                } icon: {
                    Image(systemName: entry.isCached ? "clock.arrow.circlepath" : "car.fill")
                }
            } else {
                Label("No car", systemImage: "car")
            }
        }
    }

    private var inlineView: some View {
        Group {
            if entry.isParked {
                Label(inlineText, systemImage: entry.isCached ? "clock.arrow.circlepath" : "car.fill")
            } else {
                Label("No car", systemImage: "car")
            }
        }
    }

    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "car.fill")
                .foregroundStyle(entry.isCached ? .yellow : .cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.address ?? "No active parking")
                    .font(.caption.bold())
                    .lineLimit(1)
                if entry.isCached {
                    Text(rectangularCachedText)
                        .font(.caption2)
                } else {
                    Text(entry.timerText ?? entry.distanceText ?? "Tap to park")
                        .font(.caption2)
                }
            }
        }
    }

    private var circularPrimaryText: String {
        if entry.isCached { return "..." }
        return entry.distanceText ?? "--"
    }

    private var inlineText: String {
        if entry.isCached { return "Cached car" }
        return entry.distanceText ?? "Parked"
    }

    private var rectangularCachedText: String {
        if let timerText = entry.timerText {
            return "Cached • \(timerText)"
        }
        if let distanceText = entry.distanceText {
            return "Cached • \(distanceText)"
        }
        return "Cached, waiting to sync"
    }
}

struct ParkArmorWatchComplication: Widget {
    let kind = "com.katafract.ParkArmor.watchkitapp.complication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ParkArmorComplicationProvider()) { entry in
            ParkArmorWatchComplicationEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("ParkArmor")
        .description("Distance to your parked car.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

#Preview(as: .accessoryCircular) {
    ParkArmorWatchComplication()
} timeline: {
    ParkArmorComplicationEntry(
        date: .now,
        address: "123 Main St",
        distanceText: "0.3 mi",
        timerText: "42m",
        isParked: true,
        isCached: false
    )
}
