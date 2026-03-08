import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse)
    private var allWorkouts: [WorkoutSession]

    @State private var selectedType: WorkoutType?

    // MARK: - Filtered Data

    private var filteredWorkouts: [WorkoutSession] {
        guard let selectedType else { return allWorkouts }
        return allWorkouts.filter { $0.workoutType == selectedType }
    }

    /// Workouts grouped by calendar day, each group sorted descending by date.
    private var groupedWorkouts: [(date: Date, workouts: [WorkoutSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredWorkouts) { workout in
            calendar.startOfDay(for: workout.date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, workouts: $0.value) }
    }

    // MARK: - Weekly Stats

    private var thisWeekWorkouts: [WorkoutSession] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return []
        }
        return allWorkouts.filter { $0.date >= weekStart && $0.date <= now }
    }

    private var weeklyWorkoutCount: Int {
        thisWeekWorkouts.count
    }

    private var weeklyTotalMinutes: Double {
        thisWeekWorkouts.reduce(0) { $0 + $1.durationMinutes }
    }

    private var weeklyTotalVolume: Double {
        thisWeekWorkouts.reduce(0.0) { sessionTotal, workout in
            sessionTotal + workout.exercises.reduce(0.0) { setTotal, exercise in
                guard !exercise.isWarmup,
                      let weight = exercise.weightKg,
                      let reps = exercise.reps else {
                    return setTotal
                }
                return setTotal + weight * Double(reps)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                weeklySummaryCard
                workoutTypeFilter
                workoutsList
            }
            .padding()
        }
        .navigationTitle("Workouts")
    }

    // MARK: - Weekly Summary

    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("This Week", systemImage: "calendar")
                .font(.headline)

            HStack(spacing: 0) {
                summaryItem(
                    label: "Workouts",
                    value: "\(weeklyWorkoutCount)",
                    icon: "figure.strengthtraining.traditional",
                    color: .blue
                )

                Divider()
                    .frame(height: 40)

                summaryItem(
                    label: "Minutes",
                    value: "\(Int(weeklyTotalMinutes))",
                    icon: "clock.fill",
                    color: .green
                )

                Divider()
                    .frame(height: 40)

                summaryItem(
                    label: "Volume",
                    value: formattedVolume(weeklyTotalVolume),
                    icon: "scalemass.fill",
                    color: .orange
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

    // MARK: - Workout Type Filter

    private var workoutTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", icon: "list.bullet", isSelected: selectedType == nil) {
                    selectedType = nil
                }

                ForEach(WorkoutType.allCases, id: \.rawValue) { type in
                    filterChip(
                        label: type.displayName,
                        icon: type.icon,
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func filterChip(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workouts List

    @ViewBuilder
    private var workoutsList: some View {
        if groupedWorkouts.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 16, pinnedViews: .sectionHeaders) {
                ForEach(groupedWorkouts, id: \.date) { group in
                    Section {
                        ForEach(group.workouts, id: \.id) { workout in
                            NavigationLink(value: workout.id) {
                                workoutRow(workout)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        sectionHeader(for: group.date)
                    }
                }
            }
            .navigationDestination(for: UUID.self) { workoutID in
                WorkoutDetailView(workoutID: workoutID)
            }
        }
    }

    private func sectionHeader(for date: Date) -> some View {
        HStack {
            Text(formattedSectionDate(date))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial)
    }

    private func workoutRow(_ workout: WorkoutSession) -> some View {
        HStack(spacing: 12) {
            // Workout type icon
            Image(systemName: workout.workoutType.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(colorForWorkoutType(workout.workoutType), in: RoundedRectangle(cornerRadius: 10))

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.name.isEmpty ? workout.workoutType.displayName : workout.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(Int(workout.durationMinutes)) min", systemImage: "clock")

                    if let calories = workout.caloriesBurned {
                        Label("\(Int(calories)) kcal", systemImage: "flame.fill")
                    }

                    let exerciseCount = workout.exercises
                        .map(\.exerciseName)
                        .uniqued()
                        .count
                    if exerciseCount > 0 {
                        Label("\(exerciseCount) ex", systemImage: "figure.strengthtraining.traditional")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Source badge
            sourceBadge(workout.source)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func sourceBadge(_ source: DataSource) -> some View {
        Text(source.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(sourceColor(source).opacity(0.12), in: Capsule())
            .foregroundStyle(sourceColor(source))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.mixed.cardio")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)

            Text("No workouts yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Your workouts will appear here once synced or added manually.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private func formattedSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        }
    }

    private func formattedVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return "\(Int(volume))"
    }

    private func colorForWorkoutType(_ type: WorkoutType) -> Color {
        switch type {
        case .strength:   return .blue
        case .cardio:     return .red
        case .hiit:       return .orange
        case .flexibility: return .purple
        case .sports:     return .green
        case .walking:    return .mint
        case .running:    return .pink
        case .cycling:    return .cyan
        case .swimming:   return .teal
        case .other:      return .gray
        }
    }

    private func sourceColor(_ source: DataSource) -> Color {
        switch source {
        case .healthKit:   return .red
        case .hevy:        return .blue
        case .cronometer:  return .green
        case .renpho:      return .purple
        case .manual:      return .gray
        }
    }
}

// MARK: - Array Extension

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - String Uniqued for exercise names

private extension Array where Element == String {
    // Inherits uniqued() from the Hashable extension above.
}

#Preview {
    WorkoutsView()
        .modelContainer(for: [WorkoutSession.self, ExerciseSet.self])
}
