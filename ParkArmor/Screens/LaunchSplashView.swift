import SwiftUI
import KatafractStyle

struct LaunchSplashView: View {
    @Binding var isShowing: Bool
    @State private var trimEnd: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        ZStack {
            Color.kataMidnight.ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    // Outer hairline ring
                    Circle()
                        .trim(from: 0, to: trimEnd)
                        .stroke(Color.kataGold, style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    // Inner hairline ring
                    Circle()
                        .trim(from: 0, to: trimEnd)
                        .stroke(Color.kataGold.opacity(0.5), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "car.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.kataGold)
                        .opacity(trimEnd)
                }

                Text("ParkArmor")
                    .font(.kataDisplay(28))
                    .foregroundStyle(Color.kataIce)
                    .opacity(trimEnd)
            }
        }
        .opacity(opacity)
        .task {
            withAnimation(.easeOut(duration: 0.45)) {
                trimEnd = 1
            }
            try? await Task.sleep(for: .milliseconds(400))
            KataHaptic.unlocked.fire()
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeIn(duration: 0.15)) {
                opacity = 0
            }
            try? await Task.sleep(for: .milliseconds(150))
            isShowing = false
        }
    }
}
