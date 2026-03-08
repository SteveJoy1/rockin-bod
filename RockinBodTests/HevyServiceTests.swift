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

    // MARK: - inferWorkoutType Tests (placeholder for Phase 3)
    // Note: inferWorkoutType requires a HevyWorkout struct which may need
    // internal visibility. Tests will be added in Phase 3.
}
