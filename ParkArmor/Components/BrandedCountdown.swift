import SwiftUI
import KatafractStyle

/// Branded large-format parking meter countdown.
/// kataIce when > 5 min, kataChampagne when ≤ 5 min.
/// Fires KataHaptic.revealed once when crossing the 5-min threshold.
struct BrandedCountdown: View {
    let expiresAt: Date

    @State private var firedWarningHaptic = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, expiresAt.timeIntervalSince(context.date))
            let isWarning = remaining <= 5 * 60 && remaining > 0
            let isExpired = remaining <= 0

            let color: Color = (isWarning || isExpired) ? Color.kataChampagne : Color.kataIce

            VStack(spacing: 8) {
                Text(formatRemaining(remaining))
                    .font(.kataDisplay(64))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.3), value: remaining)

                Text(isExpired ? "expired" : "on meter")
                    .font(.kataMono(12))
                    .foregroundStyle(Color.kataGold.opacity(0.6))
            }
            .onChange(of: isWarning) { _, nowWarning in
                if nowWarning && !firedWarningHaptic {
                    firedWarningHaptic = true
                    KataHaptic.revealed.fire()
                }
            }
            .onChange(of: isExpired) { _, nowExpired in
                if nowExpired {
                    KataHaptic.denied.fire()
                }
            }
        }
    }

    private func formatRemaining(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
