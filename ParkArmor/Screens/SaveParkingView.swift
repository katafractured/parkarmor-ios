import SwiftUI
import PhotosUI

struct SaveParkingView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    var onSaved: (ParkingLocation) -> Void

    @State private var viewModel: SaveParkingViewModel?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoThumbnails: [Data] = []

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.parkNavy.ignoresSafeArea()

                if let vm = viewModel {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Location info card
                            locationCard(vm: vm)

                            // Notes field
                            notesField(vm: vm)

                            // Photo picker
                            photoSection(vm: vm)

                            // Timer section
                            timerSection(vm: vm)

                            // Save button
                            saveButton(vm: vm)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                } else {
                    ProgressView()
                        .tint(DesignTokens.parkCyan)
                }
            }
            .navigationTitle("Save Parking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignTokens.parkNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DesignTokens.parkCyan)
                }
            }
        }
        .task {
            let vm = SaveParkingViewModel(
                mapKitHelper: appViewModel.mapKitHelper,
                photoManager: appViewModel.photoManager,
                repository: appViewModel.repository!,
                notificationManager: appViewModel.notificationManager,
                liveActivityManager: appViewModel.liveActivityManager,
                preferences: appViewModel.preferences
            )
            viewModel = vm
            if let loc = appViewModel.locationManager.currentLocation {
                vm.beginSave(coordinate: loc.coordinate)
            }
        }
    }

    @ViewBuilder
    private func locationCard(vm: SaveParkingViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Location", systemImage: "location.fill")
                .font(.headline)
                .foregroundStyle(DesignTokens.parkCyan)

            if vm.isGeocodingAddress {
                HStack {
                    ProgressView()
                        .tint(DesignTokens.parkCyan)
                    Text("Finding address…")
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                }
            } else {
                TextField("Address", text: Binding(get: { vm.address }, set: { vm.address = $0 }))
                    .foregroundStyle(DesignTokens.parkTextPrimary)
                    .font(.body)
            }
        }
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func notesField(vm: SaveParkingViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Notes (Optional)", systemImage: "note.text")
                .font(.headline)
                .foregroundStyle(DesignTokens.parkCyan)

            TextEditor(text: Binding(get: { vm.notes }, set: { vm.notes = $0 }))
                .frame(minHeight: 80)
                .scrollContentBackground(.hidden)
                .foregroundStyle(DesignTokens.parkTextPrimary)
                .font(.body)
                .overlay(
                    Group {
                        if vm.notes.isEmpty {
                            Text("e.g. Level 3, Row B, near elevator")
                                .foregroundStyle(DesignTokens.parkTextSecondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    },
                    alignment: .topLeading
                )
        }
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func photoSection(vm: SaveParkingViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Photos (Optional)", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.parkCyan)
                Spacer()
                if !appViewModel.isPro {
                    ProBadge()
                }
            }

            if appViewModel.isPro {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 3,
                    matching: .images
                ) {
                    Label("Add Photos", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.parkCyan)
                }
                .onChange(of: selectedPhotoItems) { _, items in
                    vm.selectedPhotos = items
                    Task {
                        photoThumbnails = (try? await appViewModel.photoManager.loadImages(from: items)) ?? []
                    }
                }

                if !photoThumbnails.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(photoThumbnails.enumerated()), id: \.offset) { _, data in
                                if let ui = UIImage(data: data) {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Upgrade to Pro to add photos")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.parkTextSecondary)
            }
        }
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func timerSection(vm: SaveParkingViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Parking Meter Timer", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.parkCyan)
                Spacer()
                Toggle("", isOn: Binding(get: { vm.hasTimer }, set: { vm.hasTimer = $0 }))
                    .tint(DesignTokens.parkCyan)
                    .labelsHidden()
            }

            if vm.hasTimer {
                DatePicker(
                    "Expires at",
                    selection: Binding(get: { vm.timerDate }, set: { vm.timerDate = $0 }),
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .foregroundStyle(DesignTokens.parkTextPrimary)
            }
        }
        .padding(16)
        .background(DesignTokens.parkSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func saveButton(vm: SaveParkingViewModel) -> some View {
        Button {
            vm.confirmSave { saved in
                onSaved(saved)
            }
        } label: {
            if vm.isSaving {
                ProgressView()
                    .tint(DesignTokens.parkAccentForeground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DesignTokens.parkCyan)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Text("Save Parking")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(DesignTokens.parkCyan)
                    .foregroundStyle(DesignTokens.parkAccentForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .disabled(vm.isSaving)

        if let error = vm.error {
            Text(error)
                .font(.caption)
                .foregroundStyle(DesignTokens.parkDestructive)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Pro Badge

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(DesignTokens.parkCyan.opacity(0.2))
            .foregroundStyle(DesignTokens.parkCyan)
            .clipShape(Capsule())
    }
}
