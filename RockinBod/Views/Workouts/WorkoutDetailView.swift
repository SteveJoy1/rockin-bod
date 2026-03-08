import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var workouts: [WorkoutSession]

    @AppStorage("useMetricUnits") private var useMetricUnits = true

    let workoutID: UUID

    init(workoutID: UUID) {
        self.workoutID = workoutID
        _workouts = Query(
            filter: #Predicate<WorkoutSession> { session in
                session.id == workoutID
            }
        )
    }

    private var workout: WorkoutSession? { workouts.first }

    /// All exercises grouped by name, preserving the order they first appear.
    private var exerciseGroups: [(name: String, sets: [ExerciseSet])] {
        guard let workout else { return [] }
        var order: [String] = []
        var grouped: [String: [ExerciseSet]] = [:]

        for exercise in workout.exercises.sorted(by: { $0.setNumber < $1.setNumber }) {
            if grouped[exercise.exerciseName] == nil {
                order.append(exercise.exerciseName)
            }
            grouped[exercise.exerciseName, default: []].append(exercise)
        }

        return order.compactMap { name in
            guard let sets = grouped[name] else { return nil }
            return (name: name, sets: sets)
        }
    }

    /// Total workout volume (weight x reps for all working sets).
    private var totalVolume: Double {
        guard let workout else { return 0 }
        return workout.exercises.reduce(0.0) { total, exercise in
            guard !exercise.isWarmup,
                  let weight = exercise.weightKg,
                  let reps = exercise.reps else {
                return total
            }
            return total + weight * Double(reps)
        }
    }

    /// Volume broken down per exercise name.
    private var volumeByExercise: [(name: String, volume: Double)] {
        exerciseGroups.compactMap { group in
            let vol = group.sets.reduce(0.0) { total, exercise in
                guard !exercise.isWarmup,
                      let weight = exercise.weightKg,
                      let reps = exercise.reps else {
                    return total
                }
                return total + weight * Double(reps)
            }
            guard vol > 0 else { return nil }
            return (name: group.name, volume: vol)
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let workout {
                ScrollView {
                    VStack(spacing: 16) {
                        headerCard(workout)
                        heartRateCard(workout)
                        volumeSummaryCard
                        exerciseListSection
                        volumeBreakdownSection
                        notesSection(workout)
                    }
                    .padding()
                }
                .navigationTitle(workout.name.isEmpty ? workout.workoutType.displayName : workout.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ContentUnavailableView(
                    "Workout Not Found",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This workout could not be loaded.")
                )
            }
        }
    }

    // MARK: - Header Card

    private func headerCard(_ workout: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: workout.workoutType.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(colorForWorkoutType(workout.workoutType), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name.isEmpty ? workout.workoutType.displayName : workout.name)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(workout.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(workout.source.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }

            Divider()

            HStack(spacing: 0) {
                detailMetric(
                    label: "Duration",
                    value: "\(Int(workout.durationMinutes))",
                    unit: "min",
                    icon: "clock.fill",
                    color: .blue
                )

                Divider()
                    .frame(height: 36)

                if let calories = workout.caloriesBurned {
                    detailMetric(
                        label: "Calories",
                        value: "\(Int(calories))",
                        unit: "kcal",
                        icon: "flame.fill",
                        color: .orange
                    )

                    Divider()
                        .frame(height: 36)
                }

                let exerciseCount = exerciseGroups.count
                detailMetric(
                    label: "Exercises",
                    value: "\(exerciseCount)",
                    unit: "",
                    icon: "figure.strengthtraining.traditional",
                    color: .green
                )
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func detailMetric(label: String, value: String, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            HStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Heart Rate Card

    @ViewBuilder
    private func heartRateCard(_ workout: WorkoutSession) -> some View {
        if workout.averageHeartRate != nil || workout.maxHeartRate != nil {
            VStack(alignment: .leading, spacing: 12) {
                Label("Heart Rate", systemImage: "heart.fill")
                    .font(.headline)
                    .foregroundStyle(.red)

                HStack(spacing: 0) {
                    if let avg = workout.averageHeartRate {
                        VStack(spacing: 4) {
                            Text("\(Int(avg))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                            Text("Avg BPM")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }

                    if workout.averageHeartRate != nil && workout.maxHeartRate != nil {
                        Divider()
                            .frame(height: 36)
                    }

                    if let max = workout.maxHeartRate {
                        VStack(spacing: 4) {
                            Text("\(Int(max))")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                            Text("Max BPM")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Volume Summary

    @ViewBuilder
    private var volumeSummaryCard: some View {
        if totalVolume > 0 {
            HStack {
                Label("Total Volume", systemImage: "scalemass.fill")
                    .font(.headline)
                Spacer()
                Text(formattedWeight(totalVolume) + " kg")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.orange)
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Exercise List

    @ViewBuilder
    private var exerciseListSection: some View {
        if !exerciseGroups.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Label("Exercises", systemImage: "list.bullet")
                    .font(.headline)

                ForEach(exerciseGroups, id: \.name) { group in
                    exerciseGroupCard(group)
                }
            }
        }
    }

    private func exerciseGroupCard(_ group: (name: String, sets: [ExerciseSet])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                NavigationLink {
                    ExerciseProgressChartView(exerciseName: group.name)
                } label: {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }

            // Set header
            HStack(spacing: 0) {
                Text("Set")
                    .frame(width: 36, alignment: .leading)
                Text("Weight")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Reps")
                    .frame(width: 50, alignment: .center)
                Text("RPE")
                    .frame(width: 40, alignment: .trailing)
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)

            ForEach(group.sets, id: \.id) { exerciseSet in
                setRow(exerciseSet)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func setRow(_ exerciseSet: ExerciseSet) -> some View {
        let opacity: Double = exerciseSet.isWarmup ? 0.5 : 1.0

        return HStack(spacing: 0) {
            HStack(spacing: 2) {
                if exerciseSet.isWarmup {
                    Text("W")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text("\(exerciseSet.setNumber)")
                }
            }
            .frame(width: 36, alignment: .leading)

            // Weight or duration
            Group {
                if let weightKg = exerciseSet.weightKg {
                    Text(formattedWeight(weightKg) + " kg")
                } else if let duration = exerciseSet.durationSeconds {
                    Text(formattedDuration(duration))
                } else {
                    Text("--")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Reps
            Group {
                if let reps = exerciseSet.reps {
                    Text("\(reps)")
                } else {
                    Text("--")
                }
            }
            .frame(width: 50, alignment: .center)

            // RPE
            Group {
                if let rpe = exerciseSet.rpe {
                    Text(String(format: "%.0f", rpe))
                        .foregroundStyle(rpeColor(rpe))
                } else {
                    Text("--")
                }
            }
            .frame(width: 40, alignment: .trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .opacity(opacity)
        .background(
            exerciseSet.isWarmup
                ? Color.orange.opacity(0.04)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    // MARK: - Volume Breakdown

    @ViewBuilder
    private var volumeBreakdownSection: some View {
        if !volumeByExercise.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Volume by Exercise", systemImage: "chart.bar.fill")
                    .font(.headline)

                let maxVolume = volumeByExercise.map(\.volume).max() ?? 1

                ForEach(volumeByExercise, id: \.name) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.name)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(formattedWeight(entry.volume) + " kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.gradient)
                                .frame(width: geometry.size.width * (entry.volume / maxVolume))
                        }
                        .frame(height: 8)
                    }
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private func notesSection(_ workout: WorkoutSession) -> some View {
        // Filter out Hevy UUIDs that were stored as notes in older imports
        if let notes = workout.notes, !notes.isEmpty, !isHevyUUID(notes, source: workout.source) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Notes", systemImage: "note.text")
                    .font(.headline)

                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
    }

    /// Check if a notes string is actually a Hevy workout UUID stored by older import code.
    private func isHevyUUID(_ text: String, source: DataSource) -> Bool {
        guard source == .hevy else { return false }
        // Hevy IDs are UUID-like strings (hex + hyphens, 32-36 chars)
        let uuidPattern = #"^[0-9a-fA-F-]{32,36}$"#
        return text.range(of: uuidPattern, options: .regularExpression) != nil
    }

    // MARK: - Helpers

    private func formattedWeight(_ weight: Double) -> String {
        let displayWeight = useMetricUnits ? weight : weight.kgToLbs
        let unit = useMetricUnits ? "kg" : "lbs"
        if displayWeight >= 1000 {
            return String(format: "%.0f %@", displayWeight, unit)
        }
        if displayWeight == displayWeight.rounded() {
            return String(format: "%.0f %@", displayWeight, unit)
        }
        return String(format: "%.1f %@", displayWeight, unit)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        }
        return "\(secs)s"
    }

    private func rpeColor(_ rpe: Double) -> Color {
        switch rpe {
        case 9...10: return .red
        case 7..<9:  return .orange
        case 5..<7:  return .yellow
        default:     return .green
        }
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
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workoutID: UUID())
    }
    .modelContainer(for: [WorkoutSession.self, ExerciseSet.self])
}
