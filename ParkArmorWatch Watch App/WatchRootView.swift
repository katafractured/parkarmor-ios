import SwiftUI

struct WatchRootView: View {
    @Environment(WatchViewModel.self) private var viewModel

    var body: some View {
        if let parking = viewModel.activeParkingSnapshot {
            WatchActiveParkingView(parking: parking)
        } else {
            WatchNoParkingView()
        }
    }
}

private struct WatchNoParkingView: View {
    @Environment(WatchViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundStyle(.cyan)

            Text("No parking saved")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.saveParking()
            } label: {
                if viewModel.isSavingParking {
                    ProgressView()
                } else {
                    Label("Park Here", systemImage: "pin.fill")
                        .font(.caption.bold())
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(viewModel.isSavingParking || !viewModel.isPhoneReachable)

            if !viewModel.isPhoneReachable {
                Text("iPhone not in range")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if let error = viewModel.saveError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("ParkArmor")
    }
}

private struct WatchActiveParkingView: View {
    @Environment(WatchViewModel.self) private var viewModel
    let parking: WatchViewModel.WatchParkingSnapshot
    @State private var showingEndConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(parking.address)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text(parking.elapsedString)
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.75))

                if let bearing = viewModel.bearingToParking {
                    WatchCompassView(bearing: bearing)
                }

                if let distance = viewModel.distanceToParking {
                    Text(distance)
                        .font(.caption.bold())
                        .foregroundStyle(.cyan)
                }

                if let expiresAt = parking.timerExpiresAt, expiresAt > Date() {
                    let minutes = Int(expiresAt.timeIntervalSinceNow) / 60
                    Label("\(minutes)m left", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }

                Button(role: .destructive) {
                    showingEndConfirmation = true
                } label: {
                    if viewModel.isEndingParking {
                        ProgressView()
                    } else {
                        Label("End Parking", systemImage: "xmark.circle.fill")
                            .font(.caption.bold())
                    }
                }
                .disabled(viewModel.isEndingParking || !viewModel.isPhoneReachable)

                if !viewModel.isPhoneReachable {
                    Text("iPhone not in range")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if let error = viewModel.endError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("My Car")
        .alert("End Parking?", isPresented: $showingEndConfirmation) {
            Button("End", role: .destructive) {
                viewModel.endParking()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end your current parking session.")
        }
    }
}

private struct WatchCompassView: View {
    let bearing: Double

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.cyan.opacity(0.65), lineWidth: 2)
                .frame(width: 60, height: 60)

            Image(systemName: "arrow.up")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(.cyan)
                .rotationEffect(.degrees(bearing))
                .animation(.easeInOut(duration: 0.3), value: bearing)
        }
    }
}
