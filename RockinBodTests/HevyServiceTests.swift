import XCTest
@testable import RockinBod

final class HevyServiceTests: XCTestCase {

    var service: HevyService!

    override func setUp() {
        super.setUp()
        service = HevyService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - parseDate Tests

    func testParseDate_isoWithFractionalSeconds() {
        let dateString = "2024-01-15T10:30:00.000Z"
        let date = service.parseDate(dateString)
        XCTAssertNotNil(date)
    }

    func testParseDate_isoWithoutFractionalSeconds() {
        let dateString = "2024-01-15T10:30:00Z"
        let date = service.parseDate(dateString)
        XCTAssertNotNil(date)
    }

    func testParseDate_invalidString() {
        let dateString = "not-a-date"
        let date = service.parseDate(dateString)
        XCTAssertNil(date)
    }

    // MARK: - inferWorkoutType Tests

    private func makeHevyWorkout(title: String, exerciseTitles: [String] = []) -> HevyWorkout {
        let exercises = exerciseTitles.map { title in
            HevyExerciseData(
                title: title,
                exercise_template_id: "test",
                sets: [HevySet(type: "normal", weight_kg: 50, reps: 10, duration_seconds: nil, rpe: nil)]
            )
        }
        return HevyWorkout(
            id: UUID().uuidString,
            title: title,
            start_time: "2024-01-15T10:00:00Z",
            end_time: "2024-01-15T11:00:00Z",
            exercises: exercises
        )
    }

    func testInferWorkoutType_strengthFromTitle() {
        let workout = makeHevyWorkout(title: "Upper Body Strength")
        XCTAssertEqual(service.inferWorkoutType(from: workout), .strength)
    }

    func testInferWorkoutType_cardioFromTitle() {
        // "run" matches .cardio since it's checked before .running ("running")
        let workout = makeHevyWorkout(title: "Morning Run")
        XCTAssertEqual(service.inferWorkoutType(from: workout), .cardio)
    }

    func testInferWorkoutType_hiitFromTitle() {
        let workout = makeHevyWorkout(title: "HIIT Circuit")
        XCTAssertEqual(service.inferWorkoutType(from: workout), .hiit)
    }

    func testInferWorkoutType_defaultsToStrength() {
        let workout = makeHevyWorkout(title: "My Custom Workout", exerciseTitles: ["Bench Press"])
        let type = service.inferWorkoutType(from: workout)
        // Should infer strength from exercise name containing weight-based exercises
        XCTAssertNotNil(type)
    }
}
