import Foundation
import HealthKit

// MARK: - HealthKit Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case noData
    case invalidQuantityType
    case queryFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device."
        case .authorizationDenied:
            return "HealthKit authorization was denied."
        case .noData:
            return "No data found for the requested query."
        case .invalidQuantityType:
            return "Invalid quantity type specified."
        case .queryFailed(let error):
            return "HealthKit query failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - HealthKit Service Protocol

/// Protocol for HealthKitService to enable mock-based testing.
protocol HealthKitServiceProtocol {
    var isAuthorized: Bool { get }
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout]
    func fetchSteps(from startDate: Date, to endDate: Date) async throws -> Int
    func fetchActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double
    func fetchRestingHeartRate(for date: Date) async throws -> Double?
    func fetchSleepHours(for date: Date) async throws -> Double?
    func fetchBodyMeasurements(from startDate: Date, to endDate: Date) async throws -> [(date: Date, weight: Double?, bodyFat: Double?, bmi: Double?, leanMass: Double?)]
    func fetchNutrition(for date: Date) async throws -> (calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, sugar: Double, sodium: Double, cholesterol: Double, micros: [String: Double])
}

// MARK: - HealthKit Service

@Observable
final class HealthKitService: HealthKitServiceProtocol {

    // MARK: - Properties

    var isAuthorized: Bool = false

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private let healthStore: HKHealthStore
    private let calendar = Calendar.current

    // MARK: - Quantity Types

    private var readQuantityTypes: Set<HKQuantityType> {
        let types: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .stepCount,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .bodyMass,
            .bodyFatPercentage,
            .bodyMassIndex,
            .leanBodyMass,
            // Dietary macronutrients
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryFiber,
            .dietarySugar,
            .dietarySodium,
            .dietaryCholesterol,
            // Dietary micronutrients
            .dietaryVitaminA,
            .dietaryVitaminC,
            .dietaryVitaminD,
            .dietaryVitaminE,
            .dietaryVitaminK,
            .dietaryVitaminB6,
            .dietaryVitaminB12,
            .dietaryThiamin,
            .dietaryRiboflavin,
            .dietaryNiacin,
            .dietaryFolate,
            .dietaryCalcium,
            .dietaryIron,
            .dietaryMagnesium,
            .dietaryPhosphorus,
            .dietaryPotassium,
            .dietaryZinc,
            .dietarySelenium,
            // Resting heart rate
            .restingHeartRate,
        ]
        return Set(types.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    private var writeQuantityTypes: Set<HKQuantityType> {
        let types: [HKQuantityTypeIdentifier] = [
            .bodyMass,
        ]
        return Set(types.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    private var readCategoryTypes: Set<HKCategoryType> {
        var types = Set<HKCategoryType>()
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        return types
    }

    // MARK: - Initialization

    init() {
        guard Self.isAvailable else {
            self.healthStore = HKHealthStore()
            return
        }
        self.healthStore = HKHealthStore()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard Self.isAvailable else {
            throw HealthKitError.notAvailable
        }

        var allReadTypes = Set<HKSampleType>()
        allReadTypes.formUnion(readQuantityTypes)
        allReadTypes.formUnion(readCategoryTypes)

        // Add workout type
        allReadTypes.insert(HKObjectType.workoutType())

        let allWriteTypes: Set<HKSampleType> = Set(writeQuantityTypes)

        try await healthStore.requestAuthorization(toShare: allWriteTypes, read: allReadTypes)
        isAuthorized = true
    }

    // MARK: - Workouts

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        guard Self.isAvailable else { throw HealthKitError.notAvailable }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                let workouts = (samples as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Steps

    func fetchSteps(from startDate: Date, to endDate: Date) async throws -> Int {
        guard Self.isAvailable else { throw HealthKitError.notAvailable }
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidQuantityType
        }

        let value = try await fetchCumulativeStatistic(
            type: stepsType,
            from: startDate,
            to: endDate
        )
        return Int(value)
    }

    // MARK: - Active Calories

    func fetchActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        guard Self.isAvailable else { throw HealthKitError.notAvailable }
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.invalidQuantityType
        }

        return try await fetchCumulativeStatistic(
            type: caloriesType,
            from: startDate,
            to: endDate
        )
    }

    // MARK: - Resting Heart Rate

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        guard Self.isAvailable else { throw HealthKitError.notAvailable }
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.invalidQuantityType
        }

        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: restingHRType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = sample.quantity.doubleValue(
                    for: HKUnit.count().unitDivided(by: .minute())
                )
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Body Measurements

    func fetchBodyMeasurements(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [(date: Date, weight: Double?, bodyFat: Double?, bmi: Double?, leanMass: Double?)] {
        guard Self.isAvailable else { throw HealthKitError.notAvailable }

        // Fetch all measurement types concurrently
        async let weightSamples = fetchQuantitySamples(
            identifier: .bodyMass,
            from: startDate,
            to: endDate
        )
        async let bodyFatSamples = fetchQuantitySamples(
            identifier: .bodyFatPercentage,
            from: startDate,
            to: endDate
        )
        async let bmiSamples = fetchQuantitySamples(
            identifier: .bodyMassIndex,
            from: startDate,
            to: endDate
        )
        async let leanMassSamples = fetchQuantitySamples(
            identifier: .leanBodyMass,
            from: startDate,
            to: endDate
        )

        let weights = try await weightSamples
        let bodyFats = try await bodyFatSamples
        let bmis = try await bmiSamples
        let leanMasses = try await leanMassSamples

        // Collect all unique dates across all measurement types
        var allDates = Set<Date>()
        for sample in weights { allDates.insert(calendar.startOfDay(for: sample.startDate)) }
        for sample in bodyFats { allDates.insert(calendar.startOfDay(for: sample.startDate)) }
        for sample in bmis { allDates.insert(calendar.startOfDay(for: sample.startDate)) }
        for sample in leanMasses { allDates.insert(calendar.startOfDay(for: sample.startDate)) }

        // Build lookup dictionaries keyed by start-of-day, using the latest sample per day
        let weightByDate = buildLatestSampleLookup(weights, unit: HKUnit.gramUnit(with: .kilo))
        let bodyFatByDate = buildLatestSampleLookup(bodyFats, unit: HKUnit.percent())
        let bmiByDate = buildLatestSampleLookup(bmis, unit: HKUnit.count())
        let leanMassByDate = buildLatestSampleLookup(leanMasses, unit: HKUnit.gramUnit(with: .kilo))

        // Build result tuples sorted by date
        let results = allDates.sorted().map { date in
            (
                date: date,
                weight: weightByDate[date],
                bodyFat: bodyFatByDate[date].map { $0 * 100 }, // Convert from 0-1 to percentage
                bmi: bmiByDate[date],
                leanMass: leanMassByDate[date]
            )
        }

        return results
    }

    // MARK: - Nutrition

    func fetchNutrition(
        for date: Date
    ) async throws -> (
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double,
        sugar: Double,
        sodium: Double,
        cholesterol: Double,
        micros: [String: Double]
    ) {
        guard Self.isAvailable else { throw HealthKitError.notAvailable }

        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.noData
        }

        // Fetch macros concurrently
        async let caloriesTask = fetchDailyNutrient(.dietaryEnergyConsumed, from: startOfDay, to: endOfDay)
        async let proteinTask = fetchDailyNutrient(.dietaryProtein, from: startOfDay, to: endOfDay)
        async let carbsTask = fetchDailyNutrient(.dietaryCarbohydrates, from: startOfDay, to: endOfDay)
        async let fatTask = fetchDailyNutrient(.dietaryFatTotal, from: startOfDay, to: endOfDay)
        async let fiberTask = fetchDailyNutrient(.dietaryFiber, from: startOfDay, to: endOfDay)
        async let sugarTask = fetchDailyNutrient(.dietarySugar, from: startOfDay, to: endOfDay)
        async let sodiumTask = fetchDailyNutrient(.dietarySodium, from: startOfDay, to: endOfDay)
        async let cholesterolTask = fetchDailyNutrient(.dietaryCholesterol, from: startOfDay, to: endOfDay)

        let calories = try await caloriesTask
        let protein = try await proteinTask
        let carbs = try await carbsTask
        let fat = try await fatTask
        let fiber = try await fiberTask
        let sugar = try await sugarTask
        let sodium = try await sodiumTask
        let cholesterol = try await cholesterolTask

        // Fetch micronutrients concurrently
        let microMapping: [(key: String, identifier: HKQuantityTypeIdentifier)] = [
            (MicronutrientKeys.vitaminA, .dietaryVitaminA),
            (MicronutrientKeys.vitaminC, .dietaryVitaminC),
            (MicronutrientKeys.vitaminD, .dietaryVitaminD),
            (MicronutrientKeys.vitaminE, .dietaryVitaminE),
            (MicronutrientKeys.vitaminK, .dietaryVitaminK),
            (MicronutrientKeys.vitaminB6, .dietaryVitaminB6),
            (MicronutrientKeys.vitaminB12, .dietaryVitaminB12),
            (MicronutrientKeys.thiamin, .dietaryThiamin),
            (MicronutrientKeys.riboflavin, .dietaryRiboflavin),
            (MicronutrientKeys.niacin, .dietaryNiacin),
            (MicronutrientKeys.folate, .dietaryFolate),
            (MicronutrientKeys.calcium, .dietaryCalcium),
            (MicronutrientKeys.iron, .dietaryIron),
            (MicronutrientKeys.magnesium, .dietaryMagnesium),
            (MicronutrientKeys.phosphorus, .dietaryPhosphorus),
            (MicronutrientKeys.potassium, .dietaryPotassium),
            (MicronutrientKeys.zinc, .dietaryZinc),
            (MicronutrientKeys.selenium, .dietarySelenium),
        ]

        var micros: [String: Double] = [:]
        try await withThrowingTaskGroup(of: (String, Double).self) { group in
            for entry in microMapping {
                group.addTask { [self] in
                    let value = try await fetchDailyNutrient(entry.identifier, from: startOfDay, to: endOfDay)
                    return (entry.key, value)
                }
            }
            for try await (key, value) in group {
                if value > 0 {
                    micros[key] = value
                }
            }
        }

        return (
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            sodium: sodium,
            cholesterol: cholesterol,
            micros: micros
        )
    }

    // MARK: - Sleep

    func fetchSleepHours(for date: Date) async throws -> Double? {
        guard Self.isAvailable else { throw HealthKitError.notAvailable }
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.invalidQuantityType
        }

        // Sleep data typically spans the night before the target date.
        // Query from 6 PM the previous day to 12 PM (noon) of the target day.
        let startOfDay = calendar.startOfDay(for: date)
        guard let sleepWindowStart = calendar.date(byAdding: .hour, value: -6, to: startOfDay),
              let sleepWindowEnd = calendar.date(byAdding: .hour, value: 12, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: sleepWindowStart,
            end: sleepWindowEnd,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Only count asleep stages (not inBed or awake)
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]

                let totalSeconds = categorySamples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { total, sample in
                        total + sample.endDate.timeIntervalSince(sample.startDate)
                    }

                let hours = totalSeconds / 3600.0
                continuation.resume(returning: hours > 0 ? hours : nil)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Workout Type Mapping

    static func workoutType(from hkWorkout: HKWorkout) -> WorkoutType {
        switch hkWorkout.workoutActivityType {
        // Strength-related
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return .strength

        // HIIT
        case .highIntensityIntervalTraining, .crossTraining:
            return .hiit

        // Flexibility
        case .yoga, .pilates, .flexibility, .mindAndBody:
            return .flexibility

        // Walking
        case .walking:
            return .walking

        // Running
        case .running:
            return .running

        // Cycling
        case .cycling:
            return .cycling

        // Swimming
        case .swimming:
            return .swimming

        // Sports
        case .basketball, .soccer, .tennis, .volleyball, .baseball, .softball,
             .golf, .hockey, .lacrosse, .rugby, .badminton, .handball,
             .racquetball, .squash, .tableTennis, .wrestling,
             .americanFootball, .australianFootball, .cricket, .fencing,
             .boxing, .kickboxing, .martialArts:
            return .sports

        // General cardio
        case .elliptical, .rowing, .stairClimbing,
             .jumpRope, .dance, .cooldown,
             .coreTraining, .stairs, .stepTraining:
            return .cardio

        // Hiking maps to cardio (walking variant with higher intensity)
        case .hiking:
            return .cardio

        default:
            return .other
        }
    }

    // MARK: - Save Body Mass

    func saveBodyMass(weightKg: Double, date: Date = Date()) async throws {
        guard Self.isAvailable else { throw HealthKitError.notAvailable }
        guard let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.invalidQuantityType
        }

        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weightKg)
        let sample = HKQuantitySample(
            type: bodyMassType,
            quantity: quantity,
            start: date,
            end: date
        )

        try await healthStore.save(sample)
    }

    // MARK: - Private Helpers

    /// Fetch a cumulative statistic (e.g., steps, calories) over a date range.
    private func fetchCumulativeStatistic(
        type: HKQuantityType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                let unit = self.preferredUnit(for: type)
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch individual quantity samples for a given identifier in a date range.
    private func fetchQuantitySamples(
        identifier: HKQuantityTypeIdentifier,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKQuantitySample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            throw HealthKitError.invalidQuantityType
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                let quantitySamples = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: quantitySamples)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch a daily cumulative nutrient value.
    private func fetchDailyNutrient(
        _ identifier: HKQuantityTypeIdentifier,
        from startDate: Date,
        to endDate: Date
    ) async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }

                let unit = self.preferredUnit(for: type)
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    /// Build a dictionary of the latest sample value per day from an array of quantity samples.
    private func buildLatestSampleLookup(
        _ samples: [HKQuantitySample],
        unit: HKUnit
    ) -> [Date: Double] {
        var lookup: [Date: Double] = [:]
        // Samples are sorted ascending by date, so later entries overwrite earlier ones for the same day
        for sample in samples {
            let dayStart = calendar.startOfDay(for: sample.startDate)
            lookup[dayStart] = sample.quantity.doubleValue(for: unit)
        }
        return lookup
    }

    /// Determine the preferred HKUnit for a given quantity type.
    private func preferredUnit(for quantityType: HKQuantityType) -> HKUnit {
        switch quantityType.identifier {
        // Counts
        case HKQuantityTypeIdentifier.stepCount.rawValue:
            return .count()
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue:
            return HKUnit.count().unitDivided(by: .minute())

        // Energy
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue:
            return .kilocalorie()

        // Body mass
        case HKQuantityTypeIdentifier.bodyMass.rawValue,
             HKQuantityTypeIdentifier.leanBodyMass.rawValue:
            return HKUnit.gramUnit(with: .kilo)

        // Percentages
        case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue:
            return .percent()

        // BMI (dimensionless)
        case HKQuantityTypeIdentifier.bodyMassIndex.rawValue:
            return .count()

        // Macronutrients in grams
        case HKQuantityTypeIdentifier.dietaryProtein.rawValue,
             HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue,
             HKQuantityTypeIdentifier.dietaryFatTotal.rawValue,
             HKQuantityTypeIdentifier.dietaryFiber.rawValue,
             HKQuantityTypeIdentifier.dietarySugar.rawValue:
            return .gram()

        // Sodium and cholesterol in milligrams
        case HKQuantityTypeIdentifier.dietarySodium.rawValue,
             HKQuantityTypeIdentifier.dietaryCholesterol.rawValue:
            return HKUnit.gramUnit(with: .milli)

        // Vitamins and minerals - use the units matching MicronutrientKeys
        case HKQuantityTypeIdentifier.dietaryVitaminA.rawValue,
             HKQuantityTypeIdentifier.dietaryVitaminD.rawValue,
             HKQuantityTypeIdentifier.dietaryVitaminK.rawValue,
             HKQuantityTypeIdentifier.dietaryVitaminB12.rawValue,
             HKQuantityTypeIdentifier.dietaryFolate.rawValue,
             HKQuantityTypeIdentifier.dietarySelenium.rawValue:
            // These are stored in mcg in the MicronutrientKeys system
            return HKUnit.gramUnit(with: .micro)

        case HKQuantityTypeIdentifier.dietaryVitaminC.rawValue,
             HKQuantityTypeIdentifier.dietaryVitaminE.rawValue,
             HKQuantityTypeIdentifier.dietaryVitaminB6.rawValue,
             HKQuantityTypeIdentifier.dietaryThiamin.rawValue,
             HKQuantityTypeIdentifier.dietaryRiboflavin.rawValue,
             HKQuantityTypeIdentifier.dietaryNiacin.rawValue,
             HKQuantityTypeIdentifier.dietaryCalcium.rawValue,
             HKQuantityTypeIdentifier.dietaryIron.rawValue,
             HKQuantityTypeIdentifier.dietaryMagnesium.rawValue,
             HKQuantityTypeIdentifier.dietaryPhosphorus.rawValue,
             HKQuantityTypeIdentifier.dietaryPotassium.rawValue,
             HKQuantityTypeIdentifier.dietaryZinc.rawValue:
            // These are stored in mg in the MicronutrientKeys system
            return HKUnit.gramUnit(with: .milli)

        default:
            return .count()
        }
    }
}
