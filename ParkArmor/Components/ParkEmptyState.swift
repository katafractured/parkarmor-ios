import SwiftUI
import KatafractStyle

/// Branded empty state — shown before the first park is recorded.
struct ParkEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "car")
                .font(.system(size: 60))
                .foregroundStyle(Color.kataGold.opacity(0.5))

            Text("No park recorded.")
                .font(.kataDisplay(18))
                .foregroundStyle(Color.kataIce)

            Text("Tap the button when you park to drop a pin.")
                .font(.kataBody(13))
                .foregroundStyle(Color.kataGold.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 32)
    }
}
