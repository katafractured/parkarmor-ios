import ARKit
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
    @State private var showingNicknameEditor = false
    @State private var nicknameDraft: String = ""
    @State private var timerSchedulingError: String?

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
                                    CompassArrow(bearingDegrees: vm.bearingDegrees, headingDegrees: vm.headingDegrees, size: 50)
                                    Text("\(vm.compassCardinal) • \(vm.distanceText)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DesignTokens.parkTextPrimary)
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
        .presentationDetents([.large])
        .confirmationDialog(
            "End Parking?",
            isPresented: $showingEndConfirm,
            titleVisibility: .visible
        ) {
            Button("End Parking", role: .destructive) {
                try? viewModel?.endParking(parking: parking)
                Task { await appViewModel.liveActivityManager.endCurrentActivity() }
                onDismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move your parking spot to history.")
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
        .onChange(of: appViewModel.locationManager.heading) { _, heading in
            viewModel?.updateHeading(heading)
        }
        .alert("Couldn't Set Timer", isPresented: Binding(
            get: { timerSchedulingError != nil },
            set: { if !$0 { timerSchedulingError = nil } }
        )) {
            Button("OK", role: .cancel) { timerSchedulingError = nil }
        } message: {
            Text(timerSchedulingError ?? "")
        }
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Parked at", systemImage: "car.fill")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.parkTextSecondary)

                Spacer()

                if appViewModel.isPro {
                    Button {
                        nicknameDraft = parking.nickname ?? ""
                        showingNicknameEditor = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.caption)
                            Text(parking.nickname == nil ? "Add Name" : "Rename")
                                .font(.caption)
                        }
                        .foregroundStyle(DesignTokens.parkCyan)
                    }
                }
            }

            Text(parking.displayAddress)
                .font(.title3.bold())
                .foregroundStyle(DesignTokens.parkTextPrimary)

            // Show raw address as sub-label when a nickname is active
            if let nick = parking.nickname, !nick.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(parking.rawAddress)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.parkTextSecondary)
            }

            Text(parking.savedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(DesignTokens.parkTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .alert("Name This Spot", isPresented: $showingNicknameEditor) {
            TextField("e.g. Work Garage, Airport P3", text: $nicknameDraft)
                .autocorrectionDisabled()
            Button("Save") {
                let trimmed = nicknameDraft.trimmingCharacters(in: .whitespaces)
                try? appViewModel.repository?.updateNickname(parking, nickname: trimmed.isEmpty ? nil : trimmed)
            }
            if parking.nickname != nil {
                Button("Clear Name") {
                    try? appViewModel.repository?.updateNickname(parking, nickname: nil)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A custom name makes it easy to spot this location in your history.")
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes", systemImage: "note.text")
                .font(.caption)
                .foregroundStyle(DesignTokens.parkTextSecondary)
            Text(parking.notes)
                .foregroundStyle(DesignTokens.parkTextPrimary)
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
                        .foregroundStyle(DesignTokens.parkTextPrimary)
                        .font(.subheadline)

                    Button("Cancel Timer") {
                        try? appViewModel.repository?.clearTimer(from: parking)
                        appViewModel.notificationManager.cancelNotification(
                            identifier: timer.notificationIdentifier
                        )
                        appViewModel.liveActivityManager.sync(with: parking)
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

                    HStack {
                        Button("Set Timer") {
                            Task {
                                do {
                                    let id = try await appViewModel.notificationManager.scheduleNotification(
                                        expiresAt: timerDate,
                                        locationName: parking.displayAddress,
                                        parkingId: parking.id,
                                        alertMode: appViewModel.preferences.timerAlertMode
                                    )
                                    try appViewModel.repository?.addTimer(to: parking, expiresAt: timerDate, notificationId: id)
                                    appViewModel.liveActivityManager.sync(with: parking)
                                    showingTimerPicker = false
                                } catch {
                                    timerSchedulingError = error.localizedDescription
                                }
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
                    .foregroundStyle(DesignTokens.parkAccentForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if ARWorldTrackingConfiguration.isSupported {
                NavigationLink {
                    ARWalkBackView(parking: parking)
                } label: {
                    Label("AR Walk-Back", systemImage: "arkit")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(DesignTokens.parkSurface)
                        .foregroundStyle(DesignTokens.parkTextPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(DesignTokens.parkCyan.opacity(0.35), lineWidth: 1)
                        )
                }
            }

            if appViewModel.isPro {
                ShareLink(item: shareMessage, preview: SharePreview("Parked Car Location")) {
                    Label("Share Parked Location", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(DesignTokens.parkSurface)
                        .foregroundStyle(DesignTokens.parkTextPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(DesignTokens.parkCyan.opacity(0.35), lineWidth: 1)
                        )
                }
            } else {
                Button {
                    appViewModel.showingPaywall = true
                } label: {
                    HStack {
                        Label("Share Parked Location", systemImage: "square.and.arrow.up")
                            .font(.headline)
                        Spacer()
                        ProBadge()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .padding(.horizontal, 16)
                    .background(DesignTokens.parkSurface)
                    .foregroundStyle(DesignTokens.parkTextPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(DesignTokens.parkCyan.opacity(0.35), lineWidth: 1)
                    )
                }
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
    }

    private var shareMessage: String {
        var lines = [
            "I parked here:",
            parking.displayAddress,
            appleMapsURL.absoluteString
        ]

        if !parking.notes.isEmpty {
            lines.append("Notes: \(parking.notes)")
        }

        if let timer = parking.timer {
            lines.append("Meter expires: \(timer.expiresAt.formatted(date: .omitted, time: .shortened))")
        }

        return lines.joined(separator: "\n")
    }

    private var appleMapsURL: URL {
        let lat = parking.latitude
        let lon = parking.longitude
        let encodedAddress = parking.displayAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Parked Car"
        return URL(string: "http://maps.apple.com/?ll=\(lat),\(lon)&q=\(encodedAddress)")!
    }
}
