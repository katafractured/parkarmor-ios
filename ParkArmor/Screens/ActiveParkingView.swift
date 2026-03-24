import SwiftUI

struct ActiveParkingView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let parking: ParkingLocation
    var onDismiss: () -> Void

    @State private var viewModel: ActiveParkingViewModel?
    @State private var showingEndConfirm = false
    @State private var selectedPhotoData: Data?
    @State private var showingTimerPicker = false
    @State private var timerDate = Date().addingTimeInterval(7200)

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.parkNavy.ignoresSafeArea()

                if let vm = viewModel {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Address
                            addressCard

                            // Timer + compass row
                            HStack(spacing: 16) {
                                // Elapsed time
                                VStack(spacing: 6) {
                                    Text("Parked for")
                                        .font(.caption)
                                        .foregroundStyle(DesignTokens.parkTextSecondary)
                                    TimerDisplay(elapsedSeconds: vm.elapsedSeconds)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(DesignTokens.parkSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))

                                // Compass
                                VStack(spacing: 6) {
                                    CompassArrow(bearingDegrees: vm.bearingDegrees, size: 50)
                                    Text("\(vm.compassCardinal) • \(vm.distanceText)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(DesignTokens.parkSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            // Notes
                            if !parking.notes.isEmpty {
                                notesCard
                            }

                            // Photos
                            if !parking.photos.isEmpty {
                                photosCard
                            }

                            // Meter timer card
                            meterTimerCard(vm: vm)

                            // Action buttons
                            actionsCard(vm: vm)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                } else {
                    ProgressView().tint(DesignTokens.parkCyan)
                }
            }
            .navigationTitle("My Car")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.parkNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { onDismiss() }
                        .foregroundStyle(DesignTokens.parkCyan)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { selectedPhotoData != nil },
                    set: { if !$0 { selectedPhotoData = nil } }
                )
            ) {
                if let data = selectedPhotoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }
            }
        }
        .task {
            let vm = ActiveParkingViewModel(
                mapKitHelper: appViewModel.mapKitHelper,
                repository: appViewModel.repository!,
                notificationManager: appViewModel.notificationManager,
                preferences: appViewModel.preferences
            )
            viewModel = vm
            vm.start(for: parking)
        }
        .onDisappear {
            viewModel?.stop()
        }
        .onChange(of: appViewModel.locationManager.currentLocation) { _, loc in
            if let loc, let vm = viewModel {
                vm.update(userLocation: loc, parking: parking, heading: appViewModel.locationManager.heading)
            }
        }
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Parked at", systemImage: "car.fill")
                .font(.caption)
                .foregroundStyle(DesignTokens.parkTextSecondary)

            Text(parking.displayAddress)
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text(parking.savedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(DesignTokens.parkTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.caption)
                .foregroundStyle(DesignTokens.parkTextSecondary)
            Text(parking.notes)
                .foregroundStyle(.white)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var photosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Photos", systemImage: "photo.stack.fill")
                .font(.caption)
                .foregroundStyle(DesignTokens.parkTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(parking.photos) { photo in
                        if let ui = UIImage(data: photo.imageData) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .onTapGesture { selectedPhotoData = photo.imageData }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func meterTimerCard(vm: ActiveParkingViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Parking Meter", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.parkCyan)
                Spacer()
            }

            if let timer = parking.timer {
                if timer.isExpired {
                    Text("Meter expired")
                        .foregroundStyle(DesignTokens.parkDestructive)
                        .font(.subheadline.bold())
                } else {
                    Text(timer.expiresAt.timeRemainingString())
                        .foregroundStyle(.white)
                        .font(.subheadline)

                    Button("Cancel Timer") {
                        try? appViewModel.repository?.clearTimer(from: parking)
                        appViewModel.notificationManager.cancelNotification(
                            identifier: timer.notificationIdentifier
                        )
                    }
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.parkDestructive)
                }
            } else {
                if showingTimerPicker {
                    DatePicker(
                        "Expires at",
                        selection: $timerDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)

                    HStack {
                        Button("Set Timer") {
                            Task {
                                do {
                                    let id = try await appViewModel.notificationManager.scheduleNotification(
                                        expiresAt: timerDate,
                                        locationName: parking.displayAddress,
                                        parkingId: parking.id
                                    )
                                    try appViewModel.repository?.addTimer(to: parking, expiresAt: timerDate, notificationId: id)
                                    showingTimerPicker = false
                                } catch {}
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DesignTokens.parkCyan)

                        Button("Cancel") { showingTimerPicker = false }
                            .foregroundStyle(DesignTokens.parkTextSecondary)
                    }
                } else {
                    Button("Set Parking Timer") {
                        showingTimerPicker = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.parkCyan)
                }
            }
        }
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func actionsCard(vm: ActiveParkingViewModel) -> some View {
        VStack(spacing: 12) {
            Button {
                vm.openDirections(to: parking)
            } label: {
                Label("Get Walking Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DesignTokens.parkCyan)
                    .foregroundStyle(DesignTokens.parkNavy)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button(role: .destructive) {
                showingEndConfirm = true
            } label: {
                Text("End Parking")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DesignTokens.parkDestructive.opacity(0.15))
                    .foregroundStyle(DesignTokens.parkDestructive)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(DesignTokens.parkDestructive.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .confirmationDialog(
            "End Parking?",
            isPresented: $showingEndConfirm,
            titleVisibility: .visible
        ) {
            Button("End Parking", role: .destructive) {
                try? vm.endParking(parking: parking)
                onDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move your parking spot to history.")
        }
    }
}
