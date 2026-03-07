import SwiftUI
import SwiftData
import Charts

struct ProgressTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.date, order: .reverse)
    private var photos: [ProgressPhoto]
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var selectedSegment: ProgressSegment = .photos
    @State private var showingPhotoCapture = false
    @State private var selectedPhoto: ProgressPhoto?
    @State private var showingComparison = false
    @State private var comparisonPhotos: (before: ProgressPhoto, after: ProgressPhoto)?

    enum ProgressSegment: String, CaseIterable {
        case photos = "Photos"
        case bodyMetrics = "Body Metrics"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                segmentedControl
                    .padding(.horizontal)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedSegment {
                        case .photos:
                            photosSection
                        case .bodyMetrics:
                            bodyMetricsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Progress")
            .toolbar {
                if selectedSegment == .photos {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingPhotoCapture = true
                        } label: {
                            Label("Add Photos", systemImage: "camera.fill")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPhotoCapture) {
                PhotoCaptureView()
            }
            .fullScreenCover(item: $selectedPhoto) { photo in
                PhotoDetailView(
                    photo: photo,
                    allPhotos: photos,
                    onCompare: { before, after in
                        comparisonPhotos = (before: before, after: after)
                        showingComparison = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showingComparison) {
                if let pair = comparisonPhotos {
                    PhotoComparisonView(before: pair.before, after: pair.after)
                }
            }
        }
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        Picker("Segment", selection: $selectedSegment) {
            ForEach(ProgressSegment.allCases, id: \.self) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Photos Section

    @ViewBuilder
    private var photosSection: some View {
        if photos.isEmpty {
            photosEmptyState
        } else {
            photosGrid
        }
    }

    private var photosEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.on.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)

            Text("No progress photos yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Take your first progress photo to start tracking your transformation.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showingPhotoCapture = true
            } label: {
                Label("Add Photos", systemImage: "camera.fill")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var photosGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(photos, id: \.id) { photo in
                photoGridItem(photo)
                    .onTapGesture {
                        selectedPhoto = photo
                    }
            }
        }
    }

    private func photoGridItem(_ photo: ProgressPhoto) -> some View {
        ZStack(alignment: .bottom) {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(3 / 4, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .aspectRatio(3 / 4, contentMode: .fill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.quaternary)
                    }
            }

            VStack(spacing: 2) {
                Text(photo.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .fontWeight(.semibold)

                HStack(spacing: 2) {
                    Image(systemName: photo.angle.icon)
                        .font(.system(size: 8))
                    Text(photo.angle.displayName)
                        .font(.system(size: 9))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial.opacity(0.9))
            .environment(\.colorScheme, .dark)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Body Metrics Section

    private var bodyMetricsSection: some View {
        VStack(spacing: 16) {
            NavigationLink {
                BodyMetricsChartView()
            } label: {
                HStack {
                    Text("View Detailed Charts")
                        .font(.subheadline)
                        .fontWeight(.medium)
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

            TrendChartView(
                title: "Weight",
                data: weightTrendData,
                color: .purple,
                unitLabel: "kg"
            )

            TrendChartView(
                title: "Body Fat",
                data: bodyFatTrendData,
                color: .orange,
                unitLabel: "%"
            )

            if !muscleMassTrendData.isEmpty {
                TrendChartView(
                    title: "Muscle Mass",
                    data: muscleMassTrendData,
                    color: .green,
                    unitLabel: "kg"
                )
            }

            TrendChartView(
                title: "BMI",
                data: bmiTrendData,
                color: .blue,
                unitLabel: ""
            )

            tapeMeasurementsSection
        }
    }

    // MARK: - Tape Measurements

    @ViewBuilder
    private var tapeMeasurementsSection: some View {
        let latest = measurements.first
        let hasTapeMeasurements = latest != nil && (
            latest!.chestCm != nil ||
            latest!.waistCm != nil ||
            latest!.hipsCm != nil ||
            latest!.leftArmCm != nil ||
            latest!.rightArmCm != nil ||
            latest!.leftThighCm != nil ||
            latest!.rightThighCm != nil
        )

        if hasTapeMeasurements {
            VStack(alignment: .leading, spacing: 12) {
                Label("Tape Measurements", systemImage: "ruler")
                    .font(.headline)

                if let measurement = latest {
                    tapeMeasurementGrid(measurement)
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    private func tapeMeasurementGrid(_ m: BodyMeasurement) -> some View {
        let items: [(String, Double?)] = [
            ("Chest", m.chestCm),
            ("Waist", m.waistCm),
            ("Hips", m.hipsCm),
            ("L Arm", m.leftArmCm),
            ("R Arm", m.rightArmCm),
            ("L Thigh", m.leftThighCm),
            ("R Thigh", m.rightThighCm)
        ]

        let validItems = items.filter { $0.1 != nil }

        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(validItems, id: \.0) { label, value in
                VStack(spacing: 4) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f cm", value!))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Trend Data Helpers

    private var weightTrendData: [TrendDataPoint] {
        measurements.compactMap { m in
            guard let weight = m.weightKg else { return nil }
            return TrendDataPoint(date: m.date, value: weight)
        }.reversed()
    }

    private var bodyFatTrendData: [TrendDataPoint] {
        measurements.compactMap { m in
            guard let bf = m.bodyFatPercentage else { return nil }
            return TrendDataPoint(date: m.date, value: bf)
        }.reversed()
    }

    private var muscleMassTrendData: [TrendDataPoint] {
        measurements.compactMap { m in
            guard let mm = m.muscleMassKg else { return nil }
            return TrendDataPoint(date: m.date, value: mm)
        }.reversed()
    }

    private var bmiTrendData: [TrendDataPoint] {
        measurements.compactMap { m in
            guard let bmi = m.bmi else { return nil }
            return TrendDataPoint(date: m.date, value: bmi)
        }.reversed()
    }
}

// MARK: - Photo Detail View (Full Screen)

private struct PhotoDetailView: View {
    let photo: ProgressPhoto
    let allPhotos: [ProgressPhoto]
    let onCompare: (ProgressPhoto, ProgressPhoto) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingCompareSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    photoInfoBar
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCompareSheet = true
                    } label: {
                        Label("Compare", systemImage: "rectangle.on.rectangle.angled")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .disabled(comparablePhotos.isEmpty)
                }
            }
            .sheet(isPresented: $showingCompareSheet) {
                comparePhotoSelector
            }
        }
    }

    private var photoInfoBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(photo.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Image(systemName: photo.angle.icon)
                    Text(photo.angle.displayName)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            if let notes = photo.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
                    .frame(maxWidth: 160, alignment: .trailing)
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.6))
        .environment(\.colorScheme, .dark)
    }

    private var comparablePhotos: [ProgressPhoto] {
        allPhotos.filter { $0.id != photo.id }
    }

    private var comparePhotoSelector: some View {
        NavigationStack {
            ScrollView {
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ]

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(comparablePhotos, id: \.id) { otherPhoto in
                        Button {
                            let earlier = photo.date < otherPhoto.date ? photo : otherPhoto
                            let later = photo.date < otherPhoto.date ? otherPhoto : photo
                            showingCompareSheet = false
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onCompare(earlier, later)
                            }
                        } label: {
                            comparePhotoThumbnail(otherPhoto)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Photo to Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCompareSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func comparePhotoThumbnail(_ photo: ProgressPhoto) -> some View {
        ZStack(alignment: .bottom) {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(3 / 4, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))
                    .aspectRatio(3 / 4, contentMode: .fill)
            }

            Text(photo.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Identifiable conformance for sheet presentation

extension ProgressPhoto: @retroactive Identifiable {}

#Preview {
    ProgressTrackingView()
        .modelContainer(for: [ProgressPhoto.self, BodyMeasurement.self])
}
