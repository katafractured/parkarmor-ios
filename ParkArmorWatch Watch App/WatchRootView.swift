import SwiftUI

struct WatchRootView: View {
    @Environment(WatchViewModel.self) private var viewModel

    var body: some View {
        Group {
            if viewModel.syncState == .syncing {
                WatchSyncingView()
            } else if let parking = viewModel.activeParkingSnapshot {
                WatchActiveParkingView(parking: parking)
            } else {
                WatchNoParkingView()
            }
        }
    }
}

private struct WatchSyncingView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(.cyan)

            Text("Syncing iPhone…")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("ParkArmor")
    }
}

private struct WatchStatusRow: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.green.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct WatchNoParkingView: View {
    @Environment(WatchViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)

            Image(systemName: "car.fill")
                .font(.title3)
                .foregroundStyle(.cyan)

            Text("Ready to save your spot")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Group {
                if let statusMessage = viewModel.statusMessage {
                    WatchStatusRow(message: statusMessage)
                } else if viewModel.syncState == .cached {
                    WatchCachedRow()
                } else if viewModel.isSavingParking && viewModel.userLocation == nil {
                    watchHelperText("Getting location…")
                } else if !viewModel.isPhoneReachable {
                    watchHelperText("iPhone not in range")
                } else if let error = viewModel.saveError {
                    watchErrorText(error)
                } else {
                    watchHelperText("Tap once after you park.")
                }
            }

            Button {
                viewModel.saveParking()
            } label: {
                if viewModel.isSavingParking {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Park Here", systemImage: "pin.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(viewModel.isSavingParking || !viewModel.isPhoneReachable)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("ParkArmor")
    }
}

private struct WatchActiveParkingView: View {
    @Environment(WatchViewModel.self) private var viewModel
    let parking: WatchViewModel.WatchParkingSnapshot
    @State private var showingEndConfirmation = false

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 8) {
                Text(parking.address)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text(parking.elapsedString)
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.75))

                if let bearing = viewModel.bearingToParking {
                    WatchCompassView(bearing: bearing, headingDegrees: viewModel.heading?.trueHeading ?? 0)
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
            }

            Group {
                if let statusMessage = viewModel.statusMessage {
                    WatchStatusRow(message: statusMessage)
                } else if viewModel.syncState == .cached {
                    WatchCachedRow()
                } else if !viewModel.isPhoneReachable {
                    watchHelperText("iPhone not in range")
                } else if let error = viewModel.endError {
                    watchErrorText(error)
                }
            }

            Spacer(minLength: 0)

            Button(role: .destructive) {
                showingEndConfirmation = true
            } label: {
                if viewModel.isEndingParking {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Label("End Parking", systemImage: "xmark.circle.fill")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
            }
            .disabled(viewModel.isEndingParking || !viewModel.isPhoneReachable)
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct WatchCachedRow: View {
    var body: some View {
        Label("Cached data, waiting to sync", systemImage: "clock.arrow.circlepath")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.yellow)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.yellow.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private func watchHelperText(_ text: String) -> some View {
    Text(text)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
}

private func watchErrorText(_ text: String) -> some View {
    Text(text)
        .font(.caption2)
        .foregroundStyle(.red)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
}

private struct WatchCompassView: View {
    let bearing: Double
    var headingDegrees: Double = 0

    var body: some View {
        ZStack {
            // Ring + cardinal labels rotate so N tracks true north
            Group {
                Circle()
                    .strokeBorder(.cyan.opacity(0.65), lineWidth: 2)
                    .frame(width: 60, height: 60)

                ForEach(Array(zip(["N", "E", "S", "W"], [0.0, 90.0, 180.0, 270.0])), id: \.0) { label, angle in
                    Text(label)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(label == "N" ? Color.cyan : Color.white.opacity(0.5))
                        .offset(y: -24)
                        .rotationEffect(.degrees(angle))
                }
            }
            .rotationEffect(.degrees(-headingDegrees))
            .animation(.easeInOut(duration: 0.3), value: headingDegrees)

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
