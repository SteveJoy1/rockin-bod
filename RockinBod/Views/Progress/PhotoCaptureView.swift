import SwiftUI
import SwiftData
import PhotosUI

struct PhotoCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var capturedPhotos: [CapturedPhoto] = []
    @State private var selectedAngle: PhotoAngle = .front
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var saveError: String?

    struct CapturedPhoto: Identifiable {
        let id = UUID()
        var imageData: Data
        var angle: PhotoAngle
        var image: UIImage?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    angleSelector
                    photoPicker
                    capturedPhotosPreview
                    notesField
                }
                .padding()
            }
            .navigationTitle("Add Progress Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        savePhotos()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(capturedPhotos.isEmpty || isSaving)
                }
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    await loadSelectedPhotos(from: newItems)
                }
            }
            .alert("Save Error", isPresented: .init(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Failed to save photos.")
            }
        }
    }

    // MARK: - Angle Selector

    private var angleSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo Angle")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach([PhotoAngle.front, .side, .back], id: \.rawValue) { angle in
                    angleButton(angle)
                }
            }
        }
    }

    private func angleButton(_ angle: PhotoAngle) -> some View {
        let isSelected = selectedAngle == angle

        return Button {
            selectedAngle = angle
        } label: {
            VStack(spacing: 6) {
                Image(systemName: angle.icon)
                    .font(.title2)
                Text(angle.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Photo Picker

    private var photoPicker: some View {
        VStack(spacing: 12) {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 5,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select from Library")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Choose up to 5 photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Captured Photos Preview

    @ViewBuilder
    private var capturedPhotosPreview: some View {
        if !capturedPhotos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Selected Photos")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(capturedPhotos.count) photo\(capturedPhotos.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(capturedPhotos) { captured in
                            capturedPhotoCard(captured)
                        }
                    }
                }
            }
        }
    }

    private func capturedPhotoCard(_ captured: CapturedPhoto) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let uiImage = captured.image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(3 / 4, contentMode: .fill)
                        .frame(width: 120, height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 120, height: 160)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.quaternary)
                        }
                }

                Button {
                    removePhoto(captured)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .font(.title3)
                }
                .offset(x: 6, y: -6)
            }

            // Angle picker for individual photo
            Menu {
                ForEach([PhotoAngle.front, .side, .back, .custom], id: \.rawValue) { angle in
                    Button {
                        updatePhotoAngle(captured, to: angle)
                    } label: {
                        Label(angle.displayName, systemImage: angle.icon)
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: captured.angle.icon)
                        .font(.system(size: 10))
                    Text(captured.angle.displayName)
                        .font(.caption2)
                        .fontWeight(.medium)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Notes Field

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextField("How are you feeling today?", text: $notes, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Actions

    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        var newPhotos: [CapturedPhoto] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                // Compress to JPEG for storage efficiency
                let jpegData = uiImage.jpegData(compressionQuality: 0.8) ?? data
                let photo = CapturedPhoto(
                    imageData: jpegData,
                    angle: selectedAngle,
                    image: uiImage
                )
                newPhotos.append(photo)
            }
        }

        await MainActor.run {
            capturedPhotos = newPhotos
            assignDefaultAngles()
        }
    }

    /// Assigns front/side/back angles automatically when exactly 3 photos are selected.
    private func assignDefaultAngles() {
        let defaultAngles: [PhotoAngle] = [.front, .side, .back]
        if capturedPhotos.count == defaultAngles.count {
            for i in capturedPhotos.indices {
                capturedPhotos[i].angle = defaultAngles[i]
            }
        }
    }

    private func removePhoto(_ photo: CapturedPhoto) {
        capturedPhotos.removeAll { $0.id == photo.id }
        selectedItems.removeAll()
    }

    private func updatePhotoAngle(_ photo: CapturedPhoto, to angle: PhotoAngle) {
        guard let index = capturedPhotos.firstIndex(where: { $0.id == photo.id }) else { return }
        capturedPhotos[index].angle = angle
    }

    private func savePhotos() {
        isSaving = true

        let notesText = notes.isEmpty ? nil : notes

        for captured in capturedPhotos {
            let progressPhoto = ProgressPhoto(
                date: Date(),
                imageData: captured.imageData,
                angle: captured.angle,
                notes: notesText
            )
            modelContext.insert(progressPhoto)
        }

        do {
            try modelContext.save()
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            saveError = "Failed to save photos: \(error.localizedDescription)"
        }
    }
}

#Preview {
    PhotoCaptureView()
        .modelContainer(for: [ProgressPhoto.self])
}
