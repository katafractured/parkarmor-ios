import ActivityKit
import SwiftUI
import WidgetKit

struct ParkingTimerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ParkingTimerActivityAttributes.self) { context in
            ParkingTimerLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.04, green: 0.10, blue: 0.19))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Parked", systemImage: "car.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "location.fill")
                        .font(.title3)
                        .foregroundStyle(Color(red: 0.18, green: 0.87, blue: 0.95))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(context.state.address)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        HStack {
                            Text("Meter")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(timerInterval: Date()...context.state.expiresAt, countsDown: true)
                                .monospacedDigit()
                                .font(.headline)
                        }

                        Button(intent: ExtendTimerIntent()) {
                            Label("+15 min", systemImage: "plus.circle")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)

                        Text("Tap to return to your car")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.white)
            }
            } compactLeading: {
                Image(systemName: "car.fill")
                    .foregroundStyle(Color(red: 0.18, green: 0.87, blue: 0.95))
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.expiresAt, countsDown: true)
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(Color(red: 0.18, green: 0.87, blue: 0.95))
            }
        }
    }
}

private struct ParkingTimerLockScreenView: View {
    let context: ActivityViewContext<ParkingTimerActivityAttributes>

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.18, green: 0.87, blue: 0.95).opacity(0.18))
                    .frame(width: 54, height: 54)

                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.18, green: 0.87, blue: 0.95))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Parking Meter")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(context.state.address)
                    .font(.headline)
                    .lineLimit(1)

                Text(timerInterval: Date()...context.state.expiresAt, countsDown: true)
                    .monospacedDigit()
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.87, blue: 0.95))
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text("Saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(context.attributes.savedAt, style: .time)
                    .font(.subheadline.weight(.semibold))

                Button(intent: ExtendTimerIntent()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
    }
}
