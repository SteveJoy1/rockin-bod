import XCTest
import HealthKit
@testable import RockinBod

// MARK: - Mock HealthKit Service

final class MockHealthKitService: HealthKitServiceProtocol {
    var isAuthorized: Bool = true

    var mockSteps: Int = 8000
    var mockActiveCalories: Double = 500.0
    var mockRestingHeartRate: Double? = 62.0
    var mockSleepHours: Double? = 7.5
    var mockWorkouts: [HKWorkout] = []
    var mockBodyMeasurements: [(date: Date, weight: Double?, bodyFat: Double?, bmi: Double?, leanMass: Double?)] = []
    var mockNutrition: (calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, sugar: Double, sodium: Double, cholesterol: Double, micros: [String: Double]) = (
        calories: 2200, protein: 180, carbs: 250, fat: 70, fiber: 30,
        sugar: 40, sodium: 2000, cholesterol: 200, micros: [:]
    )

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        return mockWorkouts
    }

    func fetchSteps(from startDate: Date, to endDate: Date) async throws -> Int {
        return mockSteps
    }

    func fetchActiveCalories(from startDate: Date, to endDate: Date) async throws -> Double {
        return mockActiveCalories
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        return mockRestingHeartRate
    }

    func fetchSleepHours(for date: Date) async throws -> Double? {
        return mockSleepHours
    }

    func fetchBodyMeasurements(from startDate: Date, to endDate: Date) async throws -> [(date: Date, weight: Double?, bodyFat: Double?, bmi: Double?, leanMass: Double?)] {
        return mockBodyMeasurements
    }

    func fetchNutrition(for date: Date) async throws -> (calories: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, sugar: Double, sodium: Double, cholesterol: Double, micros: [String: Double]) {
        return mockNutrition
    }

    var mockWorkoutHeartRate: (average: Double?, max: Double?) = (average: 145.0, max: 175.0)

    func fetchWorkoutHeartRate(from startDate: Date, to endDate: Date) async throws -> (average: Double?, max: Double?) {
        return mockWorkoutHeartRate
    }
}

// MARK: - DataAggregationService Tests

final class DataAggregationServiceTests: XCTestCase {

    // MARK: - Mock Initialization Test

    func testServiceAcceptsMockHealthKit() {
        let mock = MockHealthKitService()
        let service = DataAggregationService(healthKitService: mock)
        XCTAssertNotNil(service)
    }

    func testMockHealthKitDefaults() {
        let mock = MockHealthKitService()
        XCTAssertTrue(mock.isAuthorized)
        XCTAssertEqual(mock.mockSteps, 8000)
        XCTAssertEqual(mock.mockActiveCalories, 500.0)
    }

    // MARK: - Heart Rate Mock Tests

    func testMockHeartRateDefaults() async throws {
        let mock = MockHealthKitService()
        let hr = try await mock.fetchWorkoutHeartRate(from: Date(), to: Date())
        XCTAssertEqual(hr.average, 145.0)
        XCTAssertEqual(hr.max, 175.0)
    }

    func testMockHeartRateNilValues() async throws {
        let mock = MockHealthKitService()
        mock.mockWorkoutHeartRate = (average: nil, max: nil)
        let hr = try await mock.fetchWorkoutHeartRate(from: Date(), to: Date())
        XCTAssertNil(hr.average)
        XCTAssertNil(hr.max)
    }
}
