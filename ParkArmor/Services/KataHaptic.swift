import UIKit

enum KataHaptic {
    case saved          // Action completed
    case unlocked       // Purchase/unlock succeeded
    case denied         // Action failed/denied
    case revealed       // Modal/sheet appeared
    case destructive    // Destructive confirmed
    case tap            // Selection/tap

    func fire() {
        switch self {
        case .saved, .unlocked:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .denied:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .revealed, .tap:
            UISelectionFeedbackGenerator().selectionChanged()
        case .destructive:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}
