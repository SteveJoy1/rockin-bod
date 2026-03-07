import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \WeeklyReport.weekStartDate, order: .reverse)
    private var weeklyReports: [WeeklyReport]

    var healthKitService: HealthKitService
    var dataService: DataAggregationService

    @State private var todaySnapshot: DailySnapshot?
    @State private var weightTrendData: [TrendDataPoint] = []
    @State private var isSyncing = false
    @State private var isLoading = true
    @State private var syncError: String?

    private var userProfile: UserProfile? { userProfiles.first }
    private var latestReport: WeeklyReport? { weeklyReports.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    greetingSection
                    todaySummaryCard
                    macroProgressSection
                    activityCard
                    weightTrendSection
                    weeklyReviewSection
                    syncButton
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await loadData()
            }
            .task {
                await loadData()
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.title2)
                .fontWeight(.bold)

            Text(todayDateString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greetingText: String {
        let name = userProfile?.name ?? "there"
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12:
            timeGreeting = "Good morning"
        case 12..<17:
            timeGreeting = "Good afternoon"
        default:
            timeGreeting = "Good evening"
        }
        return "\(timeGreeting), \(name)"
    }

    private var todayDateString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    // MARK: - Today's Summary Card

    private var todaySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today's Summary", systemImage: "sun.max.fill")
                .font(.headline)

            HStack(spacing: 0) {
                summaryItem(
                    label: "Calories",
                    value: formattedCalories,
                    icon: "flame.fill",
                    color: .orange
                )

                Divider()
                    .frame(height: 40)

                summaryItem(
                    label: "Protein",
                    value: formattedProtein,
                    icon: "fork.knife",
                    color: .red
                )

                Divider()
                    .frame(height: 40)

                summaryItem(
                    label: "Workouts",
                    value: "\(todaySnapshot?.workoutCount ?? 0)",
                    icon: "dumbbell.fill",
                    color: .blue
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func summaryItem(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Macro Progress

    private var macroProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Macro Targets", systemImage: "chart.bar.fill")
                .font(.headline)

            macroProgressBar(
                label: "Calories",
                current: todaySnapshot?.nutrition?.calories ?? 0,
                target: Double(userProfile?.targetCalories ?? 2200),
                unit: "kcal",
                color: .orange
            )
            macroProgressBar(
                label: "Protein",
                current: todaySnapshot?.nutrition?.proteinGrams ?? 0,
                target: Double(userProfile?.targetProteinGrams ?? 160),
                unit: "g",
                color: .red
            )
            macroProgressBar(
                label: "Carbs",
                current: todaySnapshot?.nutrition?.carbsGrams ?? 0,
                target: Double(userProfile?.targetCarbsGrams ?? 220),
                unit: "g",
                color: .blue
            )
            macroProgressBar(
                label: "Fat",
                current: todaySnapshot?.nutrition?.fatGrams ?? 0,
                target: Double(userProfile?.targetFatGrams ?? 73),
                unit: "g",
                color: .yellow
            )
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func macroProgressBar(label: String, current: Double, target: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: min(geometry.size.width * progressFraction(current: current, target: target), geometry.size.width))
                }
            }
            .frame(height: 8)
        }
    }

    private func progressFraction(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Activity", systemImage: "figure.run")
                .font(.headline)

            HStack(spacing: 12) {
                MetricCardView(
                    title: "Steps",
                    icon: "figure.walk",
                    value: formattedSteps,
                    color: .green
                )

                MetricCardView(
                    title: "Active Cal",
                    icon: "flame.fill",
                    value: formattedActiveCalories,
                    color: .orange
                )

                MetricCardView(
                    title: "Workout",
                    icon: "timer",
                    value: formattedWorkoutMinutes,
                    subtitle: "min",
                    color: .blue
                )
            }
        }
    }

    // MARK: - Weight Trend

    private var weightTrendSection: some View {
        TrendChartView(
            title: "Weight Trend (14 days)",
            data: weightTrendData,
            color: .purple,
            unitLabel: "kg"
        )
    }

    // MARK: - Weekly Review

    @ViewBuilder
    private var weeklyReviewSection: some View {
        if let report = latestReport, let score = report.overallScore {
            VStack(alignment: .leading, spacing: 8) {
                Label("Latest Weekly Review", systemImage: "checkmark.seal.fill")
                    .font(.headline)

                HStack {
                    scoreCircle(score: score)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Week of \(report.weekStartDate.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if !report.summary.isEmpty {
                            Text(report.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer()
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    private func scoreCircle(score: Int) -> some View {
        ZStack {
            Circle()
                .stroke(scoreColor(score).opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(scoreColor(score))
        }
        .frame(width: 56, height: 56)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }

    // MARK: - Sync Button

    private var syncButton: some View {
        Button {
            Task { await syncData() }
        } label: {
            HStack {
                if isSyncing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(isSyncing ? "Syncing..." : "Sync Health Data")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .disabled(isSyncing)
        .alert("Sync Error", isPresented: .init(
            get: { syncError != nil },
            set: { if !$0 { syncError = nil } }
        )) {
            Button("OK", role: .cancel) { syncError = nil }
        } message: {
            Text(syncError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Formatting Helpers

    private var formattedCalories: String {
        guard let cals = todaySnapshot?.nutrition?.calories, cals > 0 else { return "--" }
        return "\(Int(cals))"
    }

    private var formattedProtein: String {
        guard let protein = todaySnapshot?.nutrition?.proteinGrams, protein > 0 else { return "--" }
        return "\(Int(protein))g"
    }

    private var formattedSteps: String {
        guard let steps = todaySnapshot?.steps else { return "--" }
        return steps.formatted()
    }

    private var formattedActiveCalories: String {
        guard let cal = todaySnapshot?.activeCalories else { return "--" }
        return "\(Int(cal))"
    }

    private var formattedWorkoutMinutes: String {
        guard let snapshot = todaySnapshot else { return "--" }
        let minutes = snapshot.totalWorkoutMinutes
        return minutes > 0 ? "\(Int(minutes))" : "0"
    }

    // MARK: - Data Loading

    private func loadData() async {
        do {
            let snapshot = try await dataService.buildDailySnapshot(for: Date(), context: modelContext)
            let trend = try await dataService.getProgressTrend(days: 14, context: modelContext)

            let trendPoints: [TrendDataPoint] = trend.compactMap { daily in
                guard let weight = daily.bodyMeasurement?.weightKg else { return nil }
                return TrendDataPoint(date: daily.date, value: weight)
            }

            await MainActor.run {
                todaySnapshot = snapshot
                weightTrendData = trendPoints
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func syncData() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            if !healthKitService.isAuthorized {
                try await healthKitService.requestAuthorization()
            }

            let calendar = Calendar.current
            let today = Date()
            guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) else { return }

            try await dataService.syncHealthKitData(from: twoWeeksAgo, to: today, context: modelContext)
            await loadData()
        } catch {
            syncError = error.localizedDescription
        }
    }
}

#Preview {
    DashboardView(
        healthKitService: HealthKitService(),
        dataService: DataAggregationService(healthKitService: HealthKitService())
    )
    .modelContainer(for: [UserProfile.self, WeeklyReport.self, WorkoutSession.self, NutritionEntry.self, BodyMeasurement.self])
}
