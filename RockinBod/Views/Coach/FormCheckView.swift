import SwiftUI
import SwiftData
import PhotosUI

struct FormCheckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var aiCoachService: AICoachService

    private let commonExercises = [
        "Barbell Back Squat",
        "Barbell Front Squat",
        "Barbell Bench Press",
        "Barbell Overhead Press",
        "Conventional Deadlift",
        "Sumo Deadlift",
        "Romanian Deadlift",
        "Barbell Row",
        "Pull-Up",
        "Lat Pulldown",
        "Dumbbell Lateral Raise",
        "Barbell Curl",
        "Hip Thrust",
        "Bulgarian Split Squat",
        "Leg Press",
    ]

    @State private var exerciseName = ""
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var thumbnailData: Data?
    @State private var isProcessing = false
    @State private var processingStatus = ""
    @State private var analysisResult: FormAnalysisResult?
    @State private var errorMessage: String?
    @State private var isSaved = false
    @State private var showSuggestions = false

    private var filteredExercises: [String] {
        guard !exerciseName.isEmpty else { return commonExercises }
        return commonExercises.filter {
            $0.localizedCaseInsensitiveContains(exerciseName)
        }
    }

    private var canAnalyze: Bool {
        !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && videoURL != nil
            && !isProcessing
    }

    var body: some View {
        NavigationStack {
            Group {
                if let result = analysisResult {
                    resultsView(result: result)
                } else {
                    inputView
                }
            }
            .navigationTitle(analysisResult != nil ? "Form Analysis" : "Form Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Exercise name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercise")
                        .font(.headline)

                    TextField("e.g. Barbell Back Squat", text: $exerciseName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: exerciseName) { _, newValue in
                            showSuggestions = !newValue.isEmpty
                        }

                    if showSuggestions && !filteredExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(filteredExercises.prefix(5), id: \.self) { exercise in
                                Button {
                                    exerciseName = exercise
                                    showSuggestions = false
                                } label: {
                                    Text(exercise)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                }
                                .foregroundStyle(.primary)

                                if exercise != filteredExercises.prefix(5).last {
                                    Divider()
                                }
                            }
                        }
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal)

                // Video picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Video")
                        .font(.headline)
                        .padding(.horizontal)

                    if let thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.white.opacity(0.8))
                            )
                            .padding(.horizontal)
                    }

                    PhotosPicker(
                        selection: $selectedVideoItem,
                        matching: .videos
                    ) {
                        Label(
                            videoURL != nil ? "Replace Video" : "Select Video",
                            systemImage: "video.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    .onChange(of: selectedVideoItem) { _, newItem in
                        loadVideo(item: newItem)
                    }
                }

                // Analyze button
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text(processingStatus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 24)
                } else {
                    Button {
                        Task { await analyzeForm() }
                    } label: {
                        Label("Analyze Form", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAnalyze)
                    .padding(.horizontal)
                }

                if !aiCoachService.isConfigured {
                    Label("Configure your API key in Settings to use AI features.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .onTapGesture {
            showSuggestions = false
        }
    }

    // MARK: - Results View

    private func resultsView(result: FormAnalysisResult) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overall rating badge
                ratingBadge(rating: FormRating(rawValue: result.overallRating) ?? .needsWork)

                // General feedback
                VStack(alignment: .leading, spacing: 8) {
                    Label("Feedback", systemImage: "text.bubble.fill")
                        .font(.headline)

                    Text(result.feedback)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                .padding(.horizontal)

                // Key points
                if !result.keyPoints.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Key Points", systemImage: "list.bullet.clipboard")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(Array(result.keyPoints.enumerated()), id: \.offset) { _, point in
                            keyPointRow(point: point)
                        }
                    }
                }

                // Save button
                Button {
                    saveResult(result: result)
                } label: {
                    Label(
                        isSaved ? "Results Saved" : "Save Results",
                        systemImage: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaved)
                .padding(.horizontal)

                Button("Done") { dismiss() }
                    .padding(.bottom)
            }
            .padding(.vertical)
        }
    }

    private func ratingBadge(rating: FormRating) -> some View {
        VStack(spacing: 8) {
            Image(systemName: ratingIcon(for: rating))
                .font(.system(size: 40))
                .foregroundStyle(ratingColor(for: rating))

            Text(rating.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(ratingColor(for: rating))

            Text(exerciseName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            ratingColor(for: rating).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .padding(.horizontal)
    }

    private func ratingIcon(for rating: FormRating) -> String {
        switch rating {
        case .excellent: return "star.circle.fill"
        case .good: return "hand.thumbsup.circle.fill"
        case .needsWork: return "exclamationmark.triangle.fill"
        case .poor: return "xmark.circle.fill"
        }
    }

    private func ratingColor(for rating: FormRating) -> Color {
        switch rating {
        case .excellent: return .green
        case .good: return .blue
        case .needsWork: return .orange
        case .poor: return .red
        }
    }

    private func keyPointRow(point: FormAnalysisKeyPoint) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: point.isPositive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(point.isPositive ? .green : .orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(point.area)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(point.observation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(point.suggestion)
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Video Loading

    private func loadVideo(item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            // Load the video as a file URL via transferable
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                let url = movie.url
                await MainActor.run {
                    videoURL = url
                }

                // Generate thumbnail
                if let thumb = try? await VideoProcessingService.generateThumbnail(from: url) {
                    await MainActor.run {
                        thumbnailData = thumb
                    }
                }
            }
        }
    }

    // MARK: - Analysis

    private func analyzeForm() async {
        guard let url = videoURL else { return }
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isProcessing = true
        processingStatus = "Extracting video frames..."

        do {
            let frames = try await VideoProcessingService.extractFrames(from: url)

            await MainActor.run {
                processingStatus = "Analyzing form with AI..."
            }

            let result = try await aiCoachService.analyzeFormVideo(
                frames: frames,
                exerciseName: trimmedName
            )

            await MainActor.run {
                analysisResult = result
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    // MARK: - Save

    private func saveResult(result: FormAnalysisResult) {
        let rating = FormRating(rawValue: result.overallRating) ?? .needsWork

        let keyPoints = result.keyPoints.map { point in
            FormKeyPoint(
                area: point.area,
                observation: point.observation,
                suggestion: point.suggestion,
                isPositive: point.isPositive
            )
        }

        let formCheckResult = FormCheckResult(
            exerciseName: exerciseName.trimmingCharacters(in: .whitespacesAndNewlines),
            feedback: result.feedback,
            overallRating: rating,
            keyPoints: keyPoints
        )

        // Attach thumbnail if available
        formCheckResult.thumbnailData = thumbnailData

        modelContext.insert(formCheckResult)
        try? modelContext.save()
        isSaved = true
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "form_check_\(UUID().uuidString).mov"
            let destination = tempDir.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: received.file, to: destination)

            return VideoTransferable(url: destination)
        }
    }
}

#Preview {
    FormCheckView(aiCoachService: AICoachService())
        .modelContainer(for: [FormCheckResult.self])
}
