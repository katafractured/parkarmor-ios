import SwiftUI

struct TimerDisplay: View {
    let elapsedSeconds: TimeInterval
    var style: Style = .large

    enum Style {
        case large, compact
    }

    private var hours: Int { Int(elapsedSeconds) / 3600 }
    private var minutes: Int { (Int(elapsedSeconds) % 3600) / 60 }
    private var seconds: Int { Int(elapsedSeconds) % 60 }

    private var displayText: String {
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var body: some View {
        Text(displayText)
            .font(style == .large ? .system(size: 48, weight: .bold, design: .monospaced) : .system(size: 16, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.linear(duration: 0.2), value: displayText)
            .foregroundStyle(DesignTokens.parkCyan)
    }
}

struct CompactTimerDisplay: View {
    let savedAt: Date

    var body: some View {
        TimelineView(.periodic(from: savedAt, by: 1)) { context in
            let elapsed = context.date.timeIntervalSince(savedAt)
            TimerDisplay(elapsedSeconds: max(0, elapsed), style: .compact)
        }
    }
}

struct CompactCountdownDisplay: View {
    let expiresAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, expiresAt.timeIntervalSince(context.date))
            TimerDisplay(elapsedSeconds: remaining, style: .compact)
                .foregroundStyle(remaining < 5 * 60
                    ? DesignTokens.parkDestructive
                    : DesignTokens.parkCyan)
        }
    }
}

#Preview {
    ZStack {
        DesignTokens.parkNavy.ignoresSafeArea()
        VStack(spacing: 20) {
            TimerDisplay(elapsedSeconds: 8115, style: .large)
            TimerDisplay(elapsedSeconds: 305, style: .compact)
        }
    }
}
