import KatafractStyle
import SwiftUI
import PhotosUI
import UIKit

struct SaveParkingView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    var onSaved: (ParkingLocation) -> Void

    @State private var viewModel: SaveParkingViewModel?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoThumbnails: [Data] = []
    @State private var showingPhotoSourceDialog = false
    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false
    @State private var nickname: String = ""
    @State private var savedParking: ParkingLocation?
    @State private var showingSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.parkNavy.ignoresSafeArea()

                if let vm = viewModel {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Nearby previous visits banner
                            if !vm.nearbyPreviousVisits.isEmpty {
                                nearbyBanner(visits: vm.nearbyPreviousVisits)
                            }

                            // Location info card
                            locationCard(vm: vm)

                            // Nickname field (Pro)
                            if appViewModel.isPro {
                                nicknameField()
                            }

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
                    KataProgressRing(size: 24)
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
            guard let repo = appViewModel.repository else { return }
            let vm = SaveParkingViewModel(
                mapKitHelper: appViewModel.mapKitHelper,
                photoManager: appViewModel.photoManager,
                repository: repo,
                notificationManager: appViewModel.notificationManager,
                liveActivityManager: appViewModel.liveActivityManager,
                preferences: appViewModel.preferences
            )
            viewModel = vm
            if let loc = appViewModel.locationManager.currentLocation {
                vm.beginSave(coordinate: loc.coordinate)
            }
        }
        .confirmationDialog("Add Parking Photo", isPresented: $showingPhotoSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    showingCamera = true
                }
            }
            Button("Choose from Library") {
                showingPhotoLibrary = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showingPhotoLibrary,
            selection: $selectedPhotoItems,
            maxSelectionCount: max(0, 3 - viewModelPhotoCount),
            matching: .images
        )
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                guard let image else { return }
                let compressed = appViewModel.photoManager.compressImage(image.jpegData(compressionQuality: 0.9) ?? Data())
                photoThumbnails.append(compressed)
                viewModel?.capturedPhotoData.append(compressed)
            }
        }
        .fullScreenCover(isPresented: $showingSuccess) {
            if let saved = savedParking {
                ParkedSuccessView(
                    address: saved.displayAddress,
                    savedAt: saved.savedAt
                ) {
                    showingSuccess = false
                    onSaved(saved)
                }
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
                    KataProgressRing(size: 24)
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
                Button {
                    showingPhotoSourceDialog = true
                } label: {
                    Label("Add Photos", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.parkCyan)
                }
                .disabled(viewModelPhotoCount >= 3)
                .onChange(of: selectedPhotoItems) { _, items in
                    vm.selectedPhotos = items
                    Task {
                        let libraryThumbnails = (try? await appViewModel.photoManager.loadImages(from: items)) ?? []
                        photoThumbnails = vm.capturedPhotoData + libraryThumbnails
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
    private func nearbyBanner(visits: [ParkingLocation]) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 18))
                .foregroundStyle(DesignTokens.parkCyan)

            VStack(alignment: .leading, spacing: 2) {
                Text("You've parked here \(visits.count == 1 ? "before" : "\(visits.count) times before")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignTokens.parkTextPrimary)

                if let last = visits.first {
                    let notePreview = last.notes.isEmpty ? "" : " · \(last.notes)"
                    Text("Last: \(last.savedAt.formatted(date: .abbreviated, time: .shortened))\(notePreview)")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.parkTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(DesignTokens.parkCyan.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(DesignTokens.parkCyan.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func nicknameField() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Nickname (Optional)", systemImage: "tag.fill")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.parkCyan)
                Spacer()
                ProBadge()
            }

            TextField("e.g. Work Garage, Airport Terminal B", text: $nickname)
                .foregroundStyle(DesignTokens.parkTextPrimary)
                .font(.body)
                .autocorrectionDisabled()
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
                // Quick duration chips
                HStack(spacing: 8) {
                    ForEach([15, 30, 60, 120], id: \.self) { minutes in
                        Button {
                            KataHaptic.tap.fire()
                            vm.timerDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
                        } label: {
                            Text(minutes < 60 ? "+\(minutes)m" : "+\(minutes/60)h")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(DesignTokens.parkCyan)
                    }
                }

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
            vm.confirmSave(nickname: nickname.trimmingCharacters(in: .whitespaces)) { saved in
                savedParking = saved
                showingSuccess = true
            }
        } label: {
            if vm.isSaving {
                KataProgressRing(size: 28)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.kataSapphire)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                Text("Save Parking")
                    .accessibilityLabel("Save parking location")
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

    private var viewModelPhotoCount: Int {
        let libraryCount = selectedPhotoItems.count
        let capturedCount = viewModel?.capturedPhotoData.count ?? 0
        return libraryCount + capturedCount
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

private struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: (UIImage?) -> Void

        init(onImagePicked: @escaping (UIImage?) -> Void) {
            self.onImagePicked = onImagePicked
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImagePicked(nil)
            picker.dismiss(animated: true)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onImagePicked(image)
            picker.dismiss(animated: true)
        }
    }
}
