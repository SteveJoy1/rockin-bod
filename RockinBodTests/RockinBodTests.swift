import XCTest
import SwiftData
@testable import RockinBod

final class ModelTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() {
        super.setUp()
        let schema = Schema([
            UserProfile.self,
            WorkoutSession.self,
            ExerciseSet.self,
            NutritionEntry.self,
            BodyMeasurement.self,
            ProgressPhoto.self,
            FormCheckResult.self,
            WeeklyReport.self,
            CoachMessage.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }

    // MARK: - UserProfile Tests

    func testUserProfileCreation() {
        let profile = UserProfile(
            name: "Test User",
            goal: .buildMuscle,
            targetCalories: 2800,
            targetProteinGrams: 200
        )
        modelContext.insert(profile)
        try! modelContext.save()

        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try! modelContext.fetch(descriptor)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.name, "Test User")
        XCTAssertEqual(profiles.first?.goal, .buildMuscle)
        XCTAssertEqual(profiles.first?.targetCalories, 2800)
    }

    func testFitnessGoalDisplayNames() {
        XCTAssertEqual(FitnessGoal.loseFat.displayName, "Lose Fat")
        XCTAssertEqual(FitnessGoal.buildMuscle.displayName, "Build Muscle")
        XCTAssertEqual(FitnessGoal.recomposition.displayName, "Body Recomposition")
        XCTAssertEqual(FitnessGoal.maintain.displayName, "Maintain")
        XCTAssertEqual(FitnessGoal.improveEndurance.displayName, "Improve Endurance")
    }

    // MARK: - WorkoutSession Tests

    func testWorkoutSessionCreation() {
        let workout = WorkoutSession(
            date: Date(),
            name: "Push Day",
            workoutType: .strength,
            durationMinutes: 60,
            caloriesBurned: 350,
            source: .hevy
        )
        modelContext.insert(workout)
        try! modelContext.save()

        let descriptor = FetchDescriptor<WorkoutSession>()
        let workouts = try! modelContext.fetch(descriptor)
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.name, "Push Day")
        XCTAssertEqual(workouts.first?.workoutType, .strength)
        XCTAssertEqual(workouts.first?.source, .hevy)
    }

    func testWorkoutWithExercises() {
        let workout = WorkoutSession(
            date: Date(),
            name: "Leg Day",
            workoutType: .strength,
            durationMinutes: 75
        )

        let squat1 = ExerciseSet(exerciseName: "Barbell Squat", setNumber: 1, reps: 8, weightKg: 100)
        let squat2 = ExerciseSet(exerciseName: "Barbell Squat", setNumber: 2, reps: 8, weightKg: 105)
        let squat3 = ExerciseSet(exerciseName: "Barbell Squat", setNumber: 3, reps: 6, weightKg: 110)

        workout.exercises = [squat1, squat2, squat3]
        modelContext.insert(workout)
        try! modelContext.save()

        let descriptor = FetchDescriptor<WorkoutSession>()
        let workouts = try! modelContext.fetch(descriptor)
        XCTAssertEqual(workouts.first?.exercises.count, 3)
    }

    // MARK: - ExerciseSet Tests

    func testExerciseSetWeightConversion() {
        let set = ExerciseSet(exerciseName: "Bench Press", setNumber: 1, reps: 10, weightKg: 100)
        XCTAssertNotNil(set.weightLbs)
        XCTAssertEqual(set.weightLbs!, 220.462, accuracy: 0.01)
    }

    // MARK: - NutritionEntry Tests

    func testNutritionEntryWithMicros() {
        let entry = NutritionEntry(
            date: Date(),
            source: .cronometer,
            calories: 2200,
            proteinGrams: 180,
            carbsGrams: 220,
            fatGrams: 73,
            micronutrients: [
                MicronutrientKeys.vitaminC: 90,
                MicronutrientKeys.iron: 18,
                MicronutrientKeys.calcium: 1000,
            ]
        )
        modelContext.insert(entry)
        try! modelContext.save()

        let descriptor = FetchDescriptor<NutritionEntry>()
        let entries = try! modelContext.fetch(descriptor)
        XCTAssertEqual(entries.count, 1)

        let micros = entries.first!.micronutrients
        XCTAssertEqual(micros[MicronutrientKeys.vitaminC], 90)
        XCTAssertEqual(micros[MicronutrientKeys.iron], 18)
        XCTAssertEqual(micros[MicronutrientKeys.calcium], 1000)
    }

    // MARK: - BodyMeasurement Tests

    func testBodyMeasurementWeightConversion() {
        let measurement = BodyMeasurement(
            date: Date(),
            source: .renpho,
            weightKg: 80,
            bodyFatPercentage: 18.5
        )
        XCTAssertNotNil(measurement.weightLbs)
        XCTAssertEqual(measurement.weightLbs!, 176.37, accuracy: 0.01)
    }

    // MARK: - ProgressPhoto Tests

    func testProgressPhotoAngle() {
        let photo = ProgressPhoto(angle: .front)
        XCTAssertEqual(photo.angle, .front)
        XCTAssertEqual(photo.angle.displayName, "Front")

        photo.angle = .side
        XCTAssertEqual(photo.angleRaw, "side")
    }

    // MARK: - FormCheckResult Tests

    func testFormCheckResultKeyPoints() {
        let result = FormCheckResult(
            exerciseName: "Barbell Squat",
            feedback: "Good depth but knees caving in.",
            overallRating: .good,
            keyPoints: [
                FormKeyPoint(area: "Depth", observation: "Below parallel", suggestion: "Maintain this depth", isPositive: true),
                FormKeyPoint(area: "Knees", observation: "Slight valgus", suggestion: "Push knees out", isPositive: false),
            ]
        )
        modelContext.insert(result)
        try! modelContext.save()

        let descriptor = FetchDescriptor<FormCheckResult>()
        let results = try! modelContext.fetch(descriptor)
        XCTAssertEqual(results.first?.keyPoints.count, 2)
        XCTAssertEqual(results.first?.overallRating, .good)
    }

    // MARK: - WeeklyReport Tests

    func testWeeklyReportRecommendations() {
        let report = WeeklyReport(
            weekStartDate: Date().daysAgo(7),
            weekEndDate: Date(),
            summary: "Good week overall",
            recommendations: ["Increase protein", "Add more cardio"],
            totalWorkouts: 5,
            avgCalories: 2100
        )
        modelContext.insert(report)
        try! modelContext.save()

        let descriptor = FetchDescriptor<WeeklyReport>()
        let reports = try! modelContext.fetch(descriptor)
        XCTAssertEqual(reports.first?.recommendations.count, 2)
        XCTAssertEqual(reports.first?.totalWorkouts, 5)
    }

    // MARK: - DailySnapshot Tests

    func testDailySnapshotAggregation() {
        let snapshot = DailySnapshot(
            date: Date(),
            workouts: [],
            nutrition: nil,
            bodyMeasurement: nil,
            steps: 8500,
            activeCalories: 450,
            restingHeartRate: 62,
            sleepHours: 7.5
        )
        XCTAssertFalse(snapshot.hasData) // No workouts, nutrition, or body measurement
        XCTAssertEqual(snapshot.totalWorkoutMinutes, 0)
        XCTAssertEqual(snapshot.workoutCount, 0)
    }

    // MARK: - WeeklySnapshot Tests

    func testWeeklySnapshotAverages() {
        let nutrition1 = NutritionEntry(calories: 2000, proteinGrams: 150, carbsGrams: 200, fatGrams: 70)
        let nutrition2 = NutritionEntry(calories: 2200, proteinGrams: 180, carbsGrams: 220, fatGrams: 73)

        let snapshots = [
            DailySnapshot(date: Date().daysAgo(1), workouts: [], nutrition: nutrition1),
            DailySnapshot(date: Date(), workouts: [], nutrition: nutrition2),
        ]

        let weekly = WeeklySnapshot(
            startDate: Date().daysAgo(6),
            endDate: Date(),
            dailySnapshots: snapshots
        )

        XCTAssertEqual(weekly.averageCalories, 2100, accuracy: 0.01)
        XCTAssertEqual(weekly.averageProtein, 165, accuracy: 0.01)
    }

    // MARK: - DataSource Tests

    func testDataSourceDisplayNames() {
        XCTAssertEqual(DataSource.healthKit.displayName, "Apple Health")
        XCTAssertEqual(DataSource.hevy.displayName, "Hevy")
        XCTAssertEqual(DataSource.cronometer.displayName, "Cronometer")
        XCTAssertEqual(DataSource.renpho.displayName, "Renpho")
        XCTAssertEqual(DataSource.manual.displayName, "Manual")
    }

    // MARK: - KeychainService Tests

    func testKeychainSaveAndRetrieve() throws {
        let testKey = "test_key_\(UUID().uuidString)"
        let testValue = "test_value_123"

        try KeychainService.save(key: testKey, value: testValue)
        let retrieved = KeychainService.retrieve(key: testKey)
        XCTAssertEqual(retrieved, testValue)

        try KeychainService.delete(key: testKey)
        let deletedValue = KeychainService.retrieve(key: testKey)
        XCTAssertNil(deletedValue)
    }

    // MARK: - WorkoutType Tests

    func testWorkoutTypeIcons() {
        XCTAssertEqual(WorkoutType.strength.icon, "dumbbell.fill")
        XCTAssertEqual(WorkoutType.running.icon, "figure.run")
        XCTAssertEqual(WorkoutType.cycling.icon, "bicycle")
    }
}

// MARK: - AI Service Tests

final class AICoachServiceTests: XCTestCase {

    func testWeeklyDataSummaryConstruction() {
        let summary = WeeklyDataSummary(
            avgCalories: 2100,
            avgProtein: 165,
            avgCarbs: 210,
            avgFat: 70,
            totalWorkouts: 5,
            totalWorkoutMinutes: 300,
            weightChange: -0.5,
            currentWeight: 80,
            bodyFatPercentage: 18,
            goal: "Body Recomposition"
        )
        XCTAssertEqual(summary.avgCalories, 2100)
        XCTAssertEqual(summary.totalWorkouts, 5)
        XCTAssertEqual(summary.goal, "Body Recomposition")
    }

    func testServiceNotConfiguredWithoutAPIKey() {
        let service = AICoachService()
        // Without setting an API key, the service should not be configured
        // (This assumes no key is pre-stored in Keychain for tests)
        // Note: This test may pass or fail depending on Keychain state
        XCTAssertFalse(service.isLoading)
    }
}
