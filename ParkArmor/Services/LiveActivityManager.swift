import ActivityKit
import Foundation
import Observation

@Observable final class LiveActivityManager {
    var lastErrorMessage: String?

    func sync(with parking: ParkingLocation?) {
        guard let parking, let timer = parking.timer else {
            Task { await endCurrentActivity() }
            return
        }

        Task {
            await startOrUpdate(for: parking, timer: timer)
        }
    }

    func endCurrentActivity() async {
        for activity in Activity<ParkingTimerActivityAttributes>.activities {
            let finalState = ParkingTimerActivityAttributes.ContentState(
                expiresAt: activity.content.state.expiresAt,
                address: activity.content.state.address
            )
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
    }

    private func startOrUpdate(for parking: ParkingLocation, timer: ParkingTimer) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ParkingTimerActivityAttributes(
            parkingID: parking.id,
            savedAt: parking.savedAt
        )
        let state = ParkingTimerActivityAttributes.ContentState(
            expiresAt: timer.expiresAt,
            address: parking.displayAddress
        )
        let content = ActivityContent(
            state: state,
            staleDate: timer.expiresAt
        )

        if let activity = Activity<ParkingTimerActivityAttributes>.activities.first(
            where: { $0.attributes.parkingID == parking.id }
        ) {
            await activity.update(content)
            return
        }

        for activity in Activity<ParkingTimerActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        do {
            _ = try Activity<ParkingTimerActivityAttributes>.request(
                attributes: attributes,
                content: content
            )
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
