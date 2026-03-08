import Foundation
import SwiftData
import HealthKit

// MARK: - Data Aggregation Service

@Observable
final class DataAggregationService {

    // MARK: - Properties

    private let healthKitService: any HealthKitServiceProtocol
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(healthKitService: any HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
    }

    // MARK: - Daily Snapshot

    /// Builds a complete daily snapshot by querying SwiftData models and HealthKit for a given date.
    func buildDailySnapshot(for date: Date, context: ModelContext) async throws -> DailySnapshot {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return DailySnapshot(date: startOfDay, workouts: [])
        }

        // Query SwiftData for workouts, nutrition, and body measurements on this date
        let workouts = try fetchWorkoutSessions(from: startOfDay, to: endOfDay, context: context)
        let nutritionEntry = try fetchNutritionEntry(for: startOfDay, to: endOfDay, context: context)
        let bodyMeasurement = try fetchBodyMeasurement(for: startOfDay, to: endOfDay, context: context)

        // Fetch HealthKit metrics concurrently
        async let stepsTask = fetchStepsSafely(from: startOfDay, to: endOfDay)
        async let caloriesTask = fetchActiveCaloriesSafely(from: startOfDay, to: endOfDay)
        async let heartRateTask = fetchRestingHeartRateSafely(for: date)
        async let sleepTask = fetchSleepHoursSafely(for: date)

        let steps = await stepsTask
        let activeCalories = await caloriesTask
        let restingHeartRate = await heartRateTask
        let sleepHours = await sleepTask

        return DailySnapshot(
            date: startOfDay,
            workouts: workouts,
            nutrition: nutritionEntry,
            bodyMeasurement: bodyMeasurement,
            steps: steps,
            activeCalories: activeCalories,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours
        )
    }

    // MARK: - Weekly Snapshot

    /// Builds a weekly snapshot by aggregating daily snapshots for each day of the week containing the given date.
    func buildWeeklySnapshot(weekOf date: Date, context: ModelContext) async throws -> WeeklySnapshot {
        let startOfWeek = calendar.startOfWeek(for: date)
        guard let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return WeeklySnapshot(startDate: date, endDate: date, dailySnapshots: [])
        }

        var dailySnapshots: [DailySnapshot] = []
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek) else {
                continue
            }
            let snapshot = try await buildDailySnapshot(for: day, context: context)
            dailySnapshots.append(snapshot)
        }

        let lastDay = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? endOfWeek
        return WeeklySnapshot(
            startDate: startOfWeek,
            endDate: lastDay,
            dailySnapshots: dailySnapshots
        )
    }

    // MARK: - Sync HealthKit Data

    /// Fetches workouts, body measurements, and nutrition from HealthKit and creates or updates
    /// corresponding SwiftData records, avoiding duplicates by checking existing records for the date range.
    func syncHealthKitData(from startDate: Date, to endDate: Date, context: ModelContext) async throws {
        try await syncWorkouts(from: startDate, to: endDate, context: context)
        try await syncBodyMeasurements(from: startDate, to: endDate, context: context)
        try await syncNutrition(from: startDate, to: endDate, context: context)

        try context.save()
    }

    // MARK: - Progress Trend

    /// Returns daily snapshots for the last N days, ordered from oldest to newest.
    func getProgressTrend(days: Int, context: ModelContext) async throws -> [DailySnapshot] {
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }

        var snapshots: [DailySnapshot] = []
        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
                continue
            }
            let snapshot = try await buildDailySnapshot(for: day, context: context)
            snapshots.append(snapshot)
        }

        return snapshots
    }

    // MARK: - Private SwiftData Queries

    private func fetchWorkoutSessions(
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) throws -> [WorkoutSession] {
        let predicate = #Predicate<WorkoutSession> { workout in
            workout.date >= startDate && workout.date < endDate
        }
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        descriptor.fetchLimit = nil
        return try context.fetch(descriptor)
    }

    private func fetchNutritionEntry(
        for startOfDay: Date,
        to endOfDay: Date,
        context: ModelContext
    ) throws -> NutritionEntry? {
        let predicate = #Predicate<NutritionEntry> { entry in
            entry.date >= startOfDay && entry.date < endOfDay
        }
        var descriptor = FetchDescriptor<NutritionEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchBodyMeasurement(
        for startOfDay: Date,
        to endOfDay: Date,
        context: ModelContext
    ) throws -> BodyMeasurement? {
        let predicate = #Predicate<BodyMeasurement> { measurement in
            measurement.date >= startOfDay && measurement.date < endOfDay
        }
        var descriptor = FetchDescriptor<BodyMeasurement>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Private HealthKit Helpers (Safe Wrappers)

    /// These wrappers return nil/optional on failure rather than throwing,
    /// so a single HealthKit failure doesn't prevent building the snapshot.

    private func fetchStepsSafely(from startDate: Date, to endDate: Date) async -> Int? {
        do {
            let steps = try await healthKitService.fetchSteps(from: startDate, to: endDate)
            return steps > 0 ? steps : nil
        } catch {
            return nil
        }
    }

    private func fetchActiveCaloriesSafely(from startDate: Date, to endDate: Date) async -> Double? {
        do {
            let calories = try await healthKitService.fetchActiveCalories(from: startDate, to: endDate)
            return calories > 0 ? calories : nil
        } catch {
            return nil
        }
    }

    private func fetchRestingHeartRateSafely(for date: Date) async -> Double? {
        do {
            return try await healthKitService.fetchRestingHeartRate(for: date)
        } catch {
            return nil
        }
    }

    private func fetchSleepHoursSafely(for date: Date) async -> Double? {
        do {
            return try await healthKitService.fetchSleepHours(for: date)
        } catch {
            return nil
        }
    }

    // MARK: - Private Sync Helpers

    private func syncWorkouts(
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) async throws {
        let hkWorkouts = try await healthKitService.fetchWorkouts(from: startDate, to: endDate)

        // Fetch existing HealthKit-sourced workouts in the date range to avoid duplicates
        let healthKitSourceRaw = DataSource.healthKit.rawValue
        let existingPredicate = #Predicate<WorkoutSession> { workout in
            workout.date >= startDate && workout.date < endDate && workout.sourceRaw == healthKitSourceRaw
        }
        let existingDescriptor = FetchDescriptor<WorkoutSession>(predicate: existingPredicate)
        let existingWorkouts = try context.fetch(existingDescriptor)

        // Build a set of existing workout identifiers (date + duration + type) for dedup
        let existingKeys = Set(existingWorkouts.map { workoutDeduplicationKey(date: $0.date, durationMinutes: $0.durationMinutes, typeRaw: $0.workoutTypeRaw) })

        for hkWorkout in hkWorkouts {
            let workoutType = HealthKitService.workoutType(from: hkWorkout)
            let durationMinutes = hkWorkout.duration / 60.0
            let workoutDate = hkWorkout.startDate

            let key = workoutDeduplicationKey(
                date: workoutDate,
                durationMinutes: durationMinutes,
                typeRaw: workoutType.rawValue
            )

            guard !existingKeys.contains(key) else { continue }

            // Extract calories and heart rate statistics
            let caloriesBurned = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie())

            // Fetch per-workout heart rate (gracefully handle missing data)
            let heartRate = try? await healthKitService.fetchWorkoutHeartRate(
                from: hkWorkout.startDate,
                to: hkWorkout.endDate
            )
            let averageHeartRate = heartRate?.average
            let maxHeartRate = heartRate?.max

            let session = WorkoutSession(
                date: workoutDate,
                endDate: hkWorkout.endDate,
                name: workoutType.displayName,
                workoutType: workoutType,
                durationMinutes: durationMinutes,
                caloriesBurned: caloriesBurned,
                averageHeartRate: averageHeartRate,
                maxHeartRate: maxHeartRate,
                source: .healthKit
            )
            context.insert(session)
        }
    }

    private func syncBodyMeasurements(
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) async throws {
        let hkMeasurements = try await healthKitService.fetchBodyMeasurements(
            from: startDate,
            to: endDate
        )

        // Fetch existing HealthKit-sourced body measurements in the date range
        let healthKitSourceRaw = DataSource.healthKit.rawValue
        let existingPredicate = #Predicate<BodyMeasurement> { measurement in
            measurement.date >= startDate && measurement.date < endDate && measurement.sourceRaw == healthKitSourceRaw
        }
        let existingDescriptor = FetchDescriptor<BodyMeasurement>(predicate: existingPredicate)
        let existingMeasurements = try context.fetch(existingDescriptor)

        // Build a set of existing measurement dates (start of day) for dedup
        let existingDates = Set(existingMeasurements.map { calendar.startOfDay(for: $0.date) })

        for hkMeasurement in hkMeasurements {
            let measurementDate = calendar.startOfDay(for: hkMeasurement.date)

            if existingDates.contains(measurementDate) {
                // Update existing record with latest values
                if let existing = existingMeasurements.first(where: { calendar.startOfDay(for: $0.date) == measurementDate }) {
                    if let weight = hkMeasurement.weight { existing.weightKg = weight }
                    if let bodyFat = hkMeasurement.bodyFat { existing.bodyFatPercentage = bodyFat }
                    if let bmi = hkMeasurement.bmi { existing.bmi = bmi }
                    if let leanMass = hkMeasurement.leanMass { existing.muscleMassKg = leanMass }
                }
            } else {
                let measurement = BodyMeasurement(
                    date: measurementDate,
                    source: .healthKit,
                    weightKg: hkMeasurement.weight,
                    bodyFatPercentage: hkMeasurement.bodyFat,
                    muscleMassKg: hkMeasurement.leanMass,
                    bmi: hkMeasurement.bmi
                )
                context.insert(measurement)
            }
        }
    }

    private func syncNutrition(
        from startDate: Date,
        to endDate: Date,
        context: ModelContext
    ) async throws {
        // Iterate day by day since HealthKit nutrition is fetched per day
        var currentDate = calendar.startOfDay(for: startDate)
        let endOfRange = calendar.startOfDay(for: endDate)

        // Fetch existing HealthKit-sourced nutrition entries in the date range
        let healthKitSourceRaw = DataSource.healthKit.rawValue
        let existingPredicate = #Predicate<NutritionEntry> { entry in
            entry.date >= startDate && entry.date < endDate && entry.sourceRaw == healthKitSourceRaw
        }
        let existingDescriptor = FetchDescriptor<NutritionEntry>(predicate: existingPredicate)
        let existingEntries = try context.fetch(existingDescriptor)
        let existingDates = Set(existingEntries.map { calendar.startOfDay(for: $0.date) })

        while currentDate < endOfRange {
            if existingDates.contains(currentDate) {
                // Update existing record
                if let existing = existingEntries.first(where: { calendar.startOfDay(for: $0.date) == currentDate }) {
                    do {
                        let nutrition = try await healthKitService.fetchNutrition(for: currentDate)
                        // Only update if there is meaningful data
                        if nutrition.calories > 0 {
                            existing.calories = nutrition.calories
                            existing.proteinGrams = nutrition.protein
                            existing.carbsGrams = nutrition.carbs
                            existing.fatGrams = nutrition.fat
                            existing.fiberGrams = nutrition.fiber
                            existing.sugarGrams = nutrition.sugar
                            existing.sodiumMg = nutrition.sodium
                            existing.cholesterolMg = nutrition.cholesterol
                            if !nutrition.micros.isEmpty {
                                existing.micronutrients = nutrition.micros
                            }
                        }
                    } catch {
                        // Skip this day's update on failure
                    }
                }
            } else {
                // Create new entry if HealthKit has data for this day
                do {
                    let nutrition = try await healthKitService.fetchNutrition(for: currentDate)
                    if nutrition.calories > 0 {
                        let entry = NutritionEntry(
                            date: currentDate,
                            source: .healthKit,
                            calories: nutrition.calories,
                            proteinGrams: nutrition.protein,
                            carbsGrams: nutrition.carbs,
                            fatGrams: nutrition.fat,
                            fiberGrams: nutrition.fiber,
                            sugarGrams: nutrition.sugar,
                            sodiumMg: nutrition.sodium,
                            cholesterolMg: nutrition.cholesterol,
                            micronutrients: nutrition.micros
                        )
                        context.insert(entry)
                    }
                } catch {
                    // Skip this day on failure
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDay
        }
    }

    // MARK: - Deduplication Helpers

    /// Generates a string key for workout deduplication based on date (rounded to minute), duration, and type.
    private func workoutDeduplicationKey(date: Date, durationMinutes: Double, typeRaw: String) -> String {
        let timestamp = Int(date.timeIntervalSince1970 / 60) // Round to nearest minute
        let durationKey = Int(durationMinutes * 10) // Tenths of a minute precision
        return "\(timestamp)_\(durationKey)_\(typeRaw)"
    }
}

// MARK: - Calendar Extension

private extension Calendar {
    /// Returns the start of the week (Monday) containing the given date.
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
