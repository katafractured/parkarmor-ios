import SwiftUI
import KatafractStyle

/// Full-screen ceremonial "Parked." state shown after user saves a parking location.
struct ParkedSuccessView: View {
    let address: String
    let savedAt: Date
    var onDone: () -> Void

    @State private var outerTrim: CGFloat = 0
    @State private var innerTrim: CGFloat = 0
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.kataMidnight.ignoresSafeArea()

            VStack(spacing: 24) {
                // Concentric hairline rings
                ZStack {
                    Circle()
                        .trim(from: 0, to: outerTrim)
                        .stroke(Color.kataGold, style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: 0, to: innerTrim)
                        .stroke(Color.kataGold.opacity(0.5), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "car.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.kataGold)
                        .opacity(innerTrim)
                }

                // "Parked." headline
                Text("Parked.")
                    .font(.kataDisplay(36))
                    .foregroundStyle(Color.kataChampagne)
                    .opacity(contentOpacity)

                // Address + timestamp
                VStack(spacing: 6) {
                    Text(address)
                        .font(.kataMono(12))
                        .foregroundStyle(Color.kataGold.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(savedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.kataMono(11))
                        .foregroundStyle(Color.kataGold.opacity(0.5))
                }
                .opacity(contentOpacity)
                .padding(.horizontal, 32)

                // Done button
                Button {
                    onDone()
                } label: {
                    Text("Done")
                        .font(.kataHeadline(16))
                        .foregroundStyle(Color.kataIce)
                        .frame(width: 140, height: 44)
                        .background(Color.kataSapphire)
                        .overlay(
                            Capsule()
                                .stroke(Color.kataGold.opacity(0.5), lineWidth: 0.5)
                        )
                        .clipShape(Capsule())
                }
                .opacity(contentOpacity)
            }
        }
        .task {
            // Outer ring draws first
            withAnimation(.easeOut(duration: 0.4)) {
                outerTrim = 1
            }
            try? await Task.sleep(for: .milliseconds(200))
            // Inner ring + haptic
            withAnimation(.easeOut(duration: 0.3)) {
                innerTrim = 1
            }
            KataHaptic.saved.fire()
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeIn(duration: 0.2)) {
                contentOpacity = 1
            }
        }
    }
}
