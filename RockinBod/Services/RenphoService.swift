import Foundation
import HealthKit

// MARK: - Renpho Errors

enum RenphoError: LocalizedError {
    case healthKitUnavailable
    case healthKitNotAuthorized
    case noData
    case queryFailed(Error)

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit is not available on this device."
        case .healthKitNotAuthorized:
            return "HealthKit authorization is required to access Renpho data."
        case .noData:
            return "No body composition data found."
        case .queryFailed(let error):
            return "Failed to fetch body composition data: \(error.localizedDescription)"
        }
    }
}

// MARK: - Body Composition Snapshot

/// A point-in-time snapshot of body composition metrics.
/// Renpho syncs weight and body fat percentage to Apple Health reliably.
/// Other metrics (muscle mass, bone mass, water percentage, visceral fat,
/// metabolic age, BMR) may or may not be present depending on the user's
/// Renpho app settings and scale model.
struct BodyCompositionSnapshot {
    let date: Date
    let weightKg: Double
    let bodyFatPercentage: Double?
    let muscleMassKg: Double?
    let bmi: Double?
    let boneMassKg: Double?
    let waterPercentage: Double?
    let visceralFat: Double?
    let metabolicAge: Int?
    let basalMetabolicRate: Double?

    var weightLbs: Double {
        weightKg * 2.20462
    }

    /// Estimated lean mass in kg (weight minus fat mass), if body fat data is available.
    var leanMassKg: Double? {
        guard let fatPct = bodyFatPercentage else { return nil }
        return weightKg * (1.0 - fatPct / 100.0)
    }
}

// MARK: - Renpho Service

@Observable
final class RenphoService {

    // MARK: - Properties

    private let healthKitService: HealthKitService
    private let calendar = Calendar.current

    // MARK: - Initialization

    init(healthKitService: HealthKitService) {
        self.healthKitService = healthKitService
    }

    // MARK: - Weight

    /// Fetch the most recent weight value from Apple Health in kilograms.
    func fetchLatestWeight() async throws -> Double? {
        guard HealthKitService.isAvailable else {
            throw RenphoError.healthKitUnavailable
        }

        let now = Date()
        // Look back up to 90 days for the latest weight
        guard let startDate = calendar.date(byAdding: .day, value: -90, to: now) else {
            return nil
        }

        let measurements = try await healthKitService.fetchBodyMeasurements(
            from: startDate,
            to: now
        )

        // Return the most recent weight (measurements are sorted ascending by date)
        return measurements.last(where: { $0.weight != nil })?.weight
    }

    /// Fetch daily weight values over the specified number of days.
    ///
    /// - Parameter days: Number of days to look back from today.
    /// - Returns: An array of date-weight pairs sorted chronologically.
    func fetchWeightTrend(days: Int) async throws -> [(date: Date, weight: Double)] {
        guard HealthKitService.isAvailable else {
            throw RenphoError.healthKitUnavailable
        }

        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return []
        }

        let measurements = try await healthKitService.fetchBodyMeasurements(
            from: startDate,
            to: now
        )

        return measurements.compactMap { measurement in
            guard let weight = measurement.weight else { return nil }
            return (date: measurement.date, weight: weight)
        }
    }

    // MARK: - Body Composition

    /// Fetch the most recent body composition snapshot from Apple Health.
    /// Combines weight, body fat, BMI, and lean mass data from the latest available date.
    func fetchLatestBodyComposition() async throws -> BodyCompositionSnapshot? {
        guard HealthKitService.isAvailable else {
            throw RenphoError.healthKitUnavailable
        }

        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -90, to: now) else {
            return nil
        }

        let measurements = try await healthKitService.fetchBodyMeasurements(
            from: startDate,
            to: now
        )

        // Find the latest entry that has at least a weight value
        guard let latest = measurements.last(where: { $0.weight != nil }),
              let weight = latest.weight else {
            return nil
        }

        return BodyCompositionSnapshot(
            date: latest.date,
            weightKg: weight,
            bodyFatPercentage: latest.bodyFat,
            muscleMassKg: latest.leanMass, // HealthKit provides lean body mass
            bmi: latest.bmi,
            boneMassKg: nil,         // Not available through standard HealthKit
            waterPercentage: nil,    // Not available through standard HealthKit
            visceralFat: nil,        // Not available through standard HealthKit
            metabolicAge: nil,       // Not available through standard HealthKit
            basalMetabolicRate: nil  // Fetched separately below
        )
    }

    /// Fetch body composition snapshots over the specified number of days.
    ///
    /// Each snapshot corresponds to a day where at least a weight measurement exists.
    /// Body fat, BMI, and lean mass are included when available for that day.
    ///
    /// - Parameter days: Number of days to look back from today.
    /// - Returns: An array of `BodyCompositionSnapshot` values sorted chronologically.
    func fetchBodyCompositionTrend(days: Int) async throws -> [BodyCompositionSnapshot] {
        guard HealthKitService.isAvailable else {
            throw RenphoError.healthKitUnavailable
        }

        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return []
        }

        let measurements = try await healthKitService.fetchBodyMeasurements(
            from: startDate,
            to: now
        )

        return measurements.compactMap { measurement in
            guard let weight = measurement.weight else { return nil }

            return BodyCompositionSnapshot(
                date: measurement.date,
                weightKg: weight,
                bodyFatPercentage: measurement.bodyFat,
                muscleMassKg: measurement.leanMass,
                bmi: measurement.bmi,
                boneMassKg: nil,
                waterPercentage: nil,
                visceralFat: nil,
                metabolicAge: nil,
                basalMetabolicRate: nil
            )
        }
    }

    // MARK: - Convenience Computed Properties

    /// Whether the Renpho service can operate (HealthKit is available and authorized).
    var isAvailable: Bool {
        HealthKitService.isAvailable && healthKitService.isAuthorized
    }
}
