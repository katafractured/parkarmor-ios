import SwiftUI

struct CompassArrow: View {
    let bearingDegrees: Double
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            // Compass rose background
            Circle()
                .fill(DesignTokens.parkSurface)
                .frame(width: size * 1.4, height: size * 1.4)

            Circle()
                .strokeBorder(DesignTokens.parkCyan.opacity(0.3), lineWidth: 1)
                .frame(width: size * 1.4, height: size * 1.4)

            // Cardinal labels
            ForEach(Array(zip(["N", "E", "S", "W"], [0.0, 90.0, 180.0, 270.0])), id: \.0) { label, angle in
                Text(label)
                    .font(.system(size: size * 0.13, weight: .semibold))
                    .foregroundStyle(label == "N" ? DesignTokens.parkCyan : DesignTokens.parkTextSecondary)
                    .offset(y: -(size * 0.55))
                    .rotationEffect(.degrees(angle))
            }

            // Arrow
            Image(systemName: "arrow.up")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.4, height: size * 0.4)
                .foregroundStyle(DesignTokens.parkCyan)
                .rotationEffect(.degrees(bearingDegrees))
                .animation(.easeInOut(duration: 0.3), value: bearingDegrees)
        }
        .frame(width: size * 1.4, height: size * 1.4)
    }
}

#Preview {
    ZStack {
        DesignTokens.parkNavy.ignoresSafeArea()
        CompassArrow(bearingDegrees: 45, size: 80)
    }
}
