import SwiftUI
import WidgetKit

@main
struct ParkArmorWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        ParkArmorWidget()
        ParkingTimerLiveActivityWidget()
    }
}
