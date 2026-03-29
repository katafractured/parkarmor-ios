import ARKit
import CoreLocation
import RealityKit
import SwiftUI

struct ARWalkBackView: View {
    let parking: ParkingLocation

    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var arAvailable = ARWorldTrackingConfiguration.isSupported
    @State private var bearing: Double = 0
    @State private var headingDegrees: Double = 0
    @State private var distance: String = ""

    var body: some View {
        ZStack {
            if arAvailable {
                ARNavigationContainer()
                    .ignoresSafeArea()
            } else {
                DesignTokens.parkNavy.ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
            }

            VStack {
                Spacer()

                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.parkSurface.opacity(arAvailable ? 0.75 : 1))
                            .frame(width: 180, height: 180)

                        CompassArrow(bearingDegrees: bearing, headingDegrees: headingDegrees, size: 120)
                    }

                    VStack(spacing: 8) {
                        Text(parking.displayAddress)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 20)

                        Text(distance)
                            .font(.title2.bold())
                            .foregroundStyle(DesignTokens.parkCyan)

                        Text(arAvailable ? "Point camera in the direction of the arrow" : "Follow the compass arrow to your car")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onChange(of: appViewModel.locationManager.currentLocation) { _, location in
            guard let location else { return }
            updateNavigation(userLocation: location)
        }
        .onChange(of: appViewModel.locationManager.heading) { _, heading in
            guard let location = appViewModel.locationManager.currentLocation else { return }
            updateNavigation(userLocation: location, heading: heading)
        }
        .onAppear {
            if let location = appViewModel.locationManager.currentLocation {
                updateNavigation(userLocation: location)
            }
        }
        .navigationBarHidden(true)
    }

    private func updateNavigation(userLocation: CLLocation, heading: CLHeading? = nil) {
        let meters = userLocation.distance(from: parking.clLocation)
        distance = appViewModel.preferences.distanceUnit.formatted(meters)

        let rawBearing = userLocation.coordinate.bearing(to: parking.coordinate)
        if let heading = heading ?? appViewModel.locationManager.heading {
            bearing = (rawBearing - heading.trueHeading + 360).truncatingRemainder(dividingBy: 360)
            headingDegrees = heading.trueHeading
        } else {
            bearing = rawBearing
            headingDegrees = 0
        }
    }
}

struct ARNavigationContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        arView.session.run(configuration)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
