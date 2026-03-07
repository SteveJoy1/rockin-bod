import Foundation

struct DailySnapshot: Identifiable {
    let id = UUID()
    let date: Date
    var workouts: [WorkoutSession]
    var nutrition: NutritionEntry?
    var bodyMeasurement: BodyMeasurement?
    var steps: Int?
    var activeCalories: Double?
    var restingHeartRate: Double?
    var sleepHours: Double?

    var totalWorkoutMinutes: Double {
        workouts.reduce(0) { $0 + $1.durationMinutes }
    }

    var workoutCount: Int {
        workouts.count
    }

    var hasData: Bool {
        !workouts.isEmpty || nutrition != nil || bodyMeasurement != nil
    }
}

struct WeeklySnapshot {
    let startDate: Date
    let endDate: Date
    var dailySnapshots: [DailySnapshot]

    var totalWorkouts: Int {
        dailySnapshots.reduce(0) { $0 + $1.workoutCount }
    }

    var totalWorkoutMinutes: Double {
        dailySnapshots.reduce(0) { $0 + $1.totalWorkoutMinutes }
    }

    var averageCalories: Double {
        let entries = dailySnapshots.compactMap { $0.nutrition?.calories }
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0, +) / Double(entries.count)
    }

    var averageProtein: Double {
        let entries = dailySnapshots.compactMap { $0.nutrition?.proteinGrams }
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0, +) / Double(entries.count)
    }

    var averageCarbs: Double {
        let entries = dailySnapshots.compactMap { $0.nutrition?.carbsGrams }
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0, +) / Double(entries.count)
    }

    var averageFat: Double {
        let entries = dailySnapshots.compactMap { $0.nutrition?.fatGrams }
        guard !entries.isEmpty else { return 0 }
        return entries.reduce(0, +) / Double(entries.count)
    }

    var weightTrend: (start: Double?, end: Double?) {
        let measurements = dailySnapshots
            .compactMap { $0.bodyMeasurement?.weightKg }
        return (measurements.first, measurements.last)
    }

    var averageSteps: Int {
        let steps = dailySnapshots.compactMap { $0.steps }
        guard !steps.isEmpty else { return 0 }
        return steps.reduce(0, +) / steps.count
    }
}
