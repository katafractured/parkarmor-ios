import CoreLocation
import MapKit
import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {
    static let parkNavy = Color(uiColor: .systemBackground)
    static let parkCyan = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.18, green: 0.87, blue: 0.95, alpha: 1.0)
            }
            return UIColor(red: 0.00, green: 0.37, blue: 0.51, alpha: 1.0)
        }
    )
    static let parkAccentForeground = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.04, green: 0.10, blue: 0.19, alpha: 1.0)
            }
            return .white
        }
    )
    static let parkAccentText = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.54, green: 0.92, blue: 0.97, alpha: 1.0)
            }
            return UIColor(red: 0.00, green: 0.29, blue: 0.40, alpha: 1.0)
        }
    )
    static let parkAccentSurface = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.10, green: 0.20, blue: 0.26, alpha: 1.0)
            }
            return UIColor(red: 0.90, green: 0.96, blue: 0.98, alpha: 1.0)
        }
    )
    static let parkSurface = Color(uiColor: .secondarySystemBackground)
    static let parkSurfaceElevated = Color(uiColor: .tertiarySystemBackground)
    static let parkTextPrimary = Color(uiColor: .label)
    static let parkTextSecondary = Color(uiColor: .secondaryLabel)
    static let parkDestructive = Color(uiColor: .systemRed)
}

// MARK: - Double Extensions

extension Double {
    var toRadians: Double { self * .pi / 180 }
    var toDegrees: Double { self * 180 / .pi }
}

// MARK: - CLLocationCoordinate2D Extensions

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to)
    }

    /// Returns bearing in degrees (0–360) from self to `other`.
    func bearing(to other: CLLocationCoordinate2D) -> Double {
        let lat1 = latitude.toRadians
        let lat2 = other.latitude.toRadians
        let dLon = (other.longitude - longitude).toRadians

        let x = sin(dLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var bearing = atan2(x, y).toDegrees
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        return bearing
    }
}

// MARK: - CLLocation Extensions

extension CLLocation {
    convenience init(coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Returns a human-readable elapsed time string, e.g. "2h 15m" or "45m" or "30s".
    func elapsedString(since referenceDate: Date = Date()) -> String {
        let elapsed = max(0, referenceDate.timeIntervalSince(self))
        return Self.formatElapsed(elapsed)
    }

    static func formatElapsed(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(secs)s"
        }
    }

    /// Returns a countdown string to a future date, e.g. "1h 30m remaining".
    func timeRemainingString() -> String {
        let remaining = timeIntervalSinceNow
        guard remaining > 0 else { return "Expired" }
        return Date.formatElapsed(remaining) + " remaining"
    }
}

// MARK: - Cardinal Direction

extension Double {
    /// Returns a cardinal compass direction string for a bearing in degrees.
    var cardinalDirection: String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((self + 22.5) / 45) % 8
        return directions[index]
    }
}

// MARK: - Distance Formatting

enum DistanceUnit: String, CaseIterable {
    case miles = "miles"
    case kilometers = "km"

    func formatted(_ meters: CLLocationDistance) -> String {
        switch self {
        case .miles:
            let miles = meters / 1609.344
            if miles < 0.1 {
                return "\(Int(meters * 3.28084)) ft"
            }
            return String(format: "%.1f mi", miles)
        case .kilometers:
            if meters < 1000 {
                return "\(Int(meters)) m"
            }
            return String(format: "%.1f km", meters / 1000)
        }
    }
}
