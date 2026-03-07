import SwiftUI
import SwiftData
import Charts

struct ExerciseProgressChartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSets: [ExerciseSet]

    let exerciseName: String

    init(exerciseName: String) {
        self.exerciseName = exerciseName
        _allSets = Query(
            filter: #Predicate<ExerciseSet> { exerciseSet in
                exerciseSet.exerciseName == exerciseName
            },
            sort: [SortDescriptor(\ExerciseSet.workoutSession?.date)]
        )
    }

    /// Whether this exercise uses weight/reps (true) or duration (false).
    private var isWeightBased: Bool {
        allSets.contains { $0.weightKg != nil && $0.reps != nil }
    }

    // MARK: - Weight-Based Data Points

    /// Per-session data points for weight-based exercises.
    private var sessionDataPoints: [SessionDataPoint] {
        let calendar = Calendar.current

        // Group sets by workout session date.
        var grouped: [Date: [ExerciseSet]] = [:]
        for exerciseSet in allSets {
            guard let sessionDate = exerciseSet.workoutSession?.date else { continue }
            let day = calendar.startOfDay(for: sessionDate)
            grouped[day, default: []].append(exerciseSet)
        }

        return grouped.keys.sorted().compactMap { date in
            let sets = grouped[date]!
            let workingSets = sets.filter { !$0.isWarmup }

            // Max weight in this session
            let maxWeight = workingSets
                .compactMap(\.weightKg)
                .max()

            // Estimated 1RM using Brzycki formula on the best set
            let estimated1RM = workingSets.compactMap { exerciseSet -> Double? in
                guard let weight = exerciseSet.weightKg,
                      let reps = exerciseSet.reps,
                      reps > 0, reps < 37,
                      weight > 0 else {
                    return nil
                }
                return weight * 36.0 / (37.0 - Double(reps))
            }.max()

            guard maxWeight != nil || estimated1RM != nil else { return nil }

            return SessionDataPoint(
                date: date,
                maxWeight: maxWeight,
                estimated1RM: estimated1RM
            )
        }
    }

    // MARK: - Duration-Based Data Points

    /// Per-session data points for duration-based exercises (e.g. planks).
    private var durationDataPoints: [DurationDataPoint] {
        let calendar = Calendar.current

        var grouped: [Date: [ExerciseSet]] = [:]
        for exerciseSet in allSets {
            guard let sessionDate = exerciseSet.workoutSession?.date else { continue }
            let day = calendar.startOfDay(for: sessionDate)
            grouped[day, default: []].append(exerciseSet)
        }

        return grouped.keys.sorted().compactMap { date in
            let sets = grouped[date]!
            let maxDuration = sets
                .compactMap(\.durationSeconds)
                .max()

            guard let maxDuration, maxDuration > 0 else { return nil }

            return DurationDataPoint(
                date: date,
                maxDurationSeconds: maxDuration
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isWeightBased {
                    weightChartSection
                    recentSessionsSection
                } else if !durationDataPoints.isEmpty {
                    durationChartSection
                } else {
                    noDataView
                }
            }
            .padding()
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Weight Chart

    @ViewBuilder
    private var weightChartSection: some View {
        if sessionDataPoints.isEmpty {
            noDataView
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Label("Strength Progress", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)

                latestStatsRow

                Chart {
                    ForEach(sessionDataPoints) { point in
                        if let e1rm = point.estimated1RM {
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Est. 1RM", e1rm),
                                series: .value("Metric", "Est. 1RM")
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            .symbol {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 6, height: 6)
                            }

                            AreaMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Est. 1RM", e1rm)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue.opacity(0.15), .blue.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }

                        if let maxW = point.maxWeight {
                            LineMark(
                                x: .value("Date", point.date, unit: .day),
                                y: .value("Max Weight", maxW),
                                series: .value("Metric", "Max Weight")
                            )
                            .foregroundStyle(.orange)
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .symbol {
                                Circle()
                                    .stroke(.orange, lineWidth: 1.5)
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Est. 1RM": Color.blue,
                    "Max Weight": Color.orange
                ])
                .chartLegend(position: .bottom, alignment: .center)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        AxisGridLine()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    }
                }
                .frame(height: 240)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    private var latestStatsRow: some View {
        HStack(spacing: 0) {
            if let latest = sessionDataPoints.last {
                if let e1rm = latest.estimated1RM {
                    statItem(label: "Est. 1RM", value: formattedWeight(e1rm) + " kg", color: .blue)
                }

                if latest.estimated1RM != nil && latest.maxWeight != nil {
                    Divider().frame(height: 32)
                }

                if let maxW = latest.maxWeight {
                    statItem(label: "Max Weight", value: formattedWeight(maxW) + " kg", color: .orange)
                }
            }

            let allTime1RM = sessionDataPoints.compactMap(\.estimated1RM).max()
            if let pr = allTime1RM {
                Divider().frame(height: 32)
                statItem(label: "All-Time PR", value: formattedWeight(pr) + " kg", color: .green)
            }
        }
    }

    // MARK: - Duration Chart

    @ViewBuilder
    private var durationChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Duration Progress", systemImage: "timer")
                .font(.headline)

            if let latest = durationDataPoints.last {
                HStack(spacing: 0) {
                    statItem(
                        label: "Latest",
                        value: formattedDuration(latest.maxDurationSeconds),
                        color: .blue
                    )

                    Divider().frame(height: 32)

                    let best = durationDataPoints.map(\.maxDurationSeconds).max() ?? 0
                    statItem(
                        label: "Best",
                        value: formattedDuration(best),
                        color: .green
                    )
                }
            }

            Chart(durationDataPoints) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Duration", point.maxDurationSeconds)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .symbol {
                    Circle()
                        .fill(.blue)
                        .frame(width: 6, height: 6)
                }

                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Duration", point.maxDurationSeconds)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue.opacity(0.15), .blue.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: xAxisStrideDuration)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    AxisGridLine()
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(formattedDuration(seconds))
                        }
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                }
            }
            .frame(height: 240)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Recent Sessions

    @ViewBuilder
    private var recentSessionsSection: some View {
        let recentPoints = sessionDataPoints.suffix(5).reversed()

        if !recentPoints.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Recent Sessions", systemImage: "clock.arrow.circlepath")
                    .font(.headline)

                ForEach(Array(recentPoints)) { point in
                    HStack {
                        Text(point.date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)

                        Spacer()

                        if let maxW = point.maxWeight {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(formattedWeight(maxW) + " kg")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("max weight")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        if let e1rm = point.estimated1RM {
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(formattedWeight(e1rm) + " kg")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                                Text("est. 1RM")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(width: 80, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)

                    if point.id != recentPoints.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - No Data

    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)

            Text("No progress data yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Complete more workouts with this exercise to see your progress trends.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Shared Components

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var xAxisStride: Int {
        let count = sessionDataPoints.count
        if count <= 7 { return 1 }
        if count <= 14 { return 2 }
        return 4
    }

    private var xAxisStrideDuration: Int {
        let count = durationDataPoints.count
        if count <= 7 { return 1 }
        if count <= 14 { return 2 }
        return 4
    }

    private func formattedWeight(_ weight: Double) -> String {
        if weight == weight.rounded() {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return "\(secs)s"
    }
}

// MARK: - Data Models

private struct SessionDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let maxWeight: Double?
    let estimated1RM: Double?
}

private struct DurationDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let maxDurationSeconds: Double
}

#Preview {
    NavigationStack {
        ExerciseProgressChartView(exerciseName: "Bench Press")
    }
    .modelContainer(for: [WorkoutSession.self, ExerciseSet.self])
}
