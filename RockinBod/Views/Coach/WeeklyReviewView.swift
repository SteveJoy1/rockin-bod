import SwiftUI
import SwiftData
import PhotosUI

struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \WeeklyReport.weekStartDate, order: .reverse)
    private var previousReports: [WeeklyReport]

    var aiCoachService: AICoachService
    var dataService: DataAggregationService

    enum Step: Int, CaseIterable {
        case photos = 0
        case dataSummary = 1
        case generating = 2
        case results = 3

        var title: String {
            switch self {
            case .photos: return "Progress Photos"
            case .dataSummary: return "Data Summary"
            case .generating: return "Generating Review"
            case .results: return "Your Review"
            }
        }
    }

    @State private var currentStep: Step = .photos
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var photoDataByAngle: [PhotoAngle: Data] = [:]
    @State private var weeklySnapshot: WeeklySnapshot?
    @State private var reviewResult: WeeklyReviewResult?
    @State private var errorMessage: String?
    @State private var isSaved = false

    private var userProfile: UserProfile? { userProfiles.first }
    private var latestReport: WeeklyReport? { previousReports.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                stepIndicator
                    .padding()

                Divider()

                // Step content
                switch currentStep {
                case .photos:
                    photosStep
                case .dataSummary:
                    dataSummaryStep
                case .generating:
                    generatingStep
                case .results:
                    resultsStep
                }
            }
            .navigationTitle(currentStep.title)
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

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Step 1: Photos

    private var photosStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Take or select progress photos for each angle. Photos are optional but help the AI provide better body composition feedback.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                ForEach([PhotoAngle.front, .side, .back], id: \.self) { angle in
                    photoPickerCard(for: angle)
                }

                Button {
                    currentStep = .dataSummary
                    Task { await loadWeeklyData() }
                } label: {
                    Text(photoDataByAngle.isEmpty ? "Skip Photos" : "Continue")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    private func photoPickerCard(for angle: PhotoAngle) -> some View {
        VStack(spacing: 8) {
            HStack {
                Label(angle.displayName, systemImage: angle.icon)
                    .font(.headline)
                Spacer()

                if photoDataByAngle[angle] != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if let data = photoDataByAngle[angle], let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            PhotosPicker(
                selection: Binding(
                    get: { nil as PhotosPickerItem? },
                    set: { item in
                        if let item {
                            loadPhoto(item: item, for: angle)
                        }
                    }
                ),
                matching: .images
            ) {
                Label(
                    photoDataByAngle[angle] != nil ? "Replace Photo" : "Select Photo",
                    systemImage: "photo.on.rectangle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func loadPhoto(item: PhotosPickerItem, for angle: PhotoAngle) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    photoDataByAngle[angle] = data
                }
            }
        }
    }

    // MARK: - Step 2: Data Summary

    private var dataSummaryStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let snapshot = weeklySnapshot {
                    let weekRange = "\(snapshot.startDate.formatted(.dateTime.month(.abbreviated).day())) - \(snapshot.endDate.formatted(.dateTime.month(.abbreviated).day()))"
                    Text("Week of \(weekRange)")
                        .font(.headline)

                    // Macro averages
                    dataSummaryCard(title: "Nutrition Averages") {
                        dataRow(label: "Avg Calories", value: "\(Int(snapshot.averageCalories)) kcal")
                        dataRow(label: "Avg Protein", value: "\(Int(snapshot.averageProtein))g")
                        dataRow(label: "Avg Carbs", value: "\(Int(snapshot.averageCarbs))g")
                        dataRow(label: "Avg Fat", value: "\(Int(snapshot.averageFat))g")
                    }

                    // Training
                    dataSummaryCard(title: "Training") {
                        dataRow(label: "Total Workouts", value: "\(snapshot.totalWorkouts)")
                        dataRow(label: "Total Minutes", value: "\(Int(snapshot.totalWorkoutMinutes))")
                    }

                    // Weight
                    dataSummaryCard(title: "Weight") {
                        if let startWeight = snapshot.weightTrend.start {
                            dataRow(label: "Start", value: String(format: "%.1f kg", startWeight))
                        }
                        if let endWeight = snapshot.weightTrend.end {
                            dataRow(label: "End", value: String(format: "%.1f kg", endWeight))
                        }
                        if let start = snapshot.weightTrend.start, let end = snapshot.weightTrend.end {
                            let change = end - start
                            let sign = change >= 0 ? "+" : ""
                            dataRow(label: "Change", value: "\(sign)\(String(format: "%.1f", change)) kg")
                        }
                    }

                    Button {
                        currentStep = .generating
                        Task { await generateReview() }
                    } label: {
                        Label("Generate AI Review", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                } else {
                    ProgressView("Loading weekly data...")
                }
            }
            .padding(.vertical)
        }
    }

    private func dataSummaryCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func dataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Step 3: Generating

    private var generatingStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .controlSize(.large)

            Text("Analyzing your week...")
                .font(.title3)
                .fontWeight(.medium)

            Text("The AI coach is reviewing your training, nutrition, and progress to generate personalized feedback.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Step 4: Results

    private var resultsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let result = reviewResult {
                    if result.isRawTextFallback {
                        // AI returned unstructured text — show as a single response card
                        feedbackCard(title: "AI Response", icon: "brain", content: result.summary)
                    } else {
                        // Structured JSON response — show each section
                        if let score = result.overallScore {
                            overallScoreGauge(score: score)
                        }

                        feedbackCard(title: "Summary", icon: "doc.text.fill", content: result.summary)

                        if !result.trainingFeedback.isEmpty {
                            feedbackCard(title: "Training", icon: "dumbbell.fill", content: result.trainingFeedback)
                        }

                        if !result.nutritionFeedback.isEmpty {
                            feedbackCard(title: "Nutrition", icon: "fork.knife", content: result.nutritionFeedback)
                        }

                        if !result.bodyCompFeedback.isEmpty {
                            feedbackCard(title: "Body Composition", icon: "figure.stand", content: result.bodyCompFeedback)
                        }
                    }

                    // Recommendations
                    if !result.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Recommendations", systemImage: "lightbulb.fill")
                                .font(.headline)

                            ForEach(Array(result.recommendations.enumerated()), id: \.offset) { index, rec in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.accentColor)
                                    Text(rec)
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                        .padding(.horizontal)
                    }

                    // Save button
                    Button {
                        saveReport(result: result)
                    } label: {
                        Label(isSaved ? "Report Saved" : "Save Report", systemImage: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaved)
                    .padding(.horizontal)

                    Button("Done") { dismiss() }
                        .padding(.bottom)
                } else {
                    Text("No results available.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical)
        }
    }

    private func overallScoreGauge(score: Int) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(scoreColor(score).opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 10.0)
                    .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(score))
                    Text("/ 10")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            Text("Overall Score")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 8...10: return .green
        case 6..<8: return .yellow
        case 4..<6: return .orange
        default: return .red
        }
    }

    private func feedbackCard(title: String, icon: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)

            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }

    // MARK: - Data Loading & Generation

    private func loadWeeklyData() async {
        do {
            let snapshot = try await dataService.buildWeeklySnapshot(
                weekOf: Date(),
                context: modelContext
            )
            await MainActor.run {
                weeklySnapshot = snapshot
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateReview() async {
        guard let snapshot = weeklySnapshot else {
            errorMessage = "Weekly data not loaded."
            currentStep = .dataSummary
            return
        }

        do {
            let weeklyData = WeeklyDataSummary(
                avgCalories: snapshot.averageCalories,
                avgProtein: snapshot.averageProtein,
                avgCarbs: snapshot.averageCarbs,
                avgFat: snapshot.averageFat,
                totalWorkouts: snapshot.totalWorkouts,
                totalWorkoutMinutes: snapshot.totalWorkoutMinutes,
                weightChange: {
                    guard let start = snapshot.weightTrend.start,
                          let end = snapshot.weightTrend.end else { return nil }
                    return end - start
                }(),
                currentWeight: snapshot.weightTrend.end,
                bodyFatPercentage: snapshot.dailySnapshots.compactMap({ $0.bodyMeasurement?.bodyFatPercentage }).last,
                goal: userProfile?.goal.displayName ?? "General fitness"
            )

            let photoData: [Data] = [PhotoAngle.front, .side, .back].compactMap { photoDataByAngle[$0] }

            let previousRecs = latestReport?.recommendations

            let result = try await aiCoachService.generateWeeklyReview(
                weeklyData: weeklyData,
                photos: photoData.isEmpty ? nil : photoData,
                previousRecommendations: previousRecs
            )

            await MainActor.run {
                reviewResult = result
                currentStep = .results
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                currentStep = .dataSummary
            }
        }
    }

    // MARK: - Save

    private func saveReport(result: WeeklyReviewResult) {
        guard let snapshot = weeklySnapshot else { return }

        let report = WeeklyReport(
            weekStartDate: snapshot.startDate,
            weekEndDate: snapshot.endDate,
            summary: result.summary,
            trainingFeedback: result.trainingFeedback,
            nutritionFeedback: result.nutritionFeedback,
            bodyCompFeedback: result.bodyCompFeedback,
            recommendations: result.recommendations,
            overallScore: result.overallScore,
            totalWorkouts: snapshot.totalWorkouts,
            totalWorkoutMinutes: snapshot.totalWorkoutMinutes,
            avgCalories: snapshot.averageCalories,
            avgProtein: snapshot.averageProtein,
            avgCarbs: snapshot.averageCarbs,
            avgFat: snapshot.averageFat,
            startWeight: snapshot.weightTrend.start,
            endWeight: snapshot.weightTrend.end
        )

        // Save progress photos
        for (angle, data) in photoDataByAngle {
            let photo = ProgressPhoto(imageData: data, angle: angle)
            report.photos.append(photo)
        }

        modelContext.insert(report)
        do {
            try modelContext.save()
            isSaved = true
        } catch {
            errorMessage = "Failed to save report: \(error.localizedDescription)"
        }
    }
}

#Preview {
    WeeklyReviewView(
        aiCoachService: AICoachService(),
        dataService: DataAggregationService(healthKitService: HealthKitService())
    )
    .modelContainer(for: [UserProfile.self, WeeklyReport.self, ProgressPhoto.self, WorkoutSession.self, NutritionEntry.self, BodyMeasurement.self])
}
