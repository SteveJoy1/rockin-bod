import XCTest
@testable import RockinBod

final class UnitConversionTests: XCTestCase {

    // MARK: - Weight Conversion Tests

    func testKgToLbs() {
        let kg = 100.0
        XCTAssertEqual(kg.kgToLbs, 220.462, accuracy: 0.01)
    }

    func testLbsToKg() {
        let lbs = 220.462
        XCTAssertEqual(lbs.lbsToKg, 100.0, accuracy: 0.01)
    }

    func testKgToLbs_roundTrip() {
        let original = 75.5
        let converted = original.kgToLbs.lbsToKg
        XCTAssertEqual(converted, original, accuracy: 0.01)
    }

    // MARK: - Length Conversion Tests

    func testCmToInches() {
        let cm = 180.0
        XCTAssertEqual(cm.cmToInches, 70.866, accuracy: 0.01)
    }

    func testInchesToCm() {
        let inches = 70.0
        XCTAssertEqual(inches.inchesToCm, 177.8, accuracy: 0.01)
    }

    // MARK: - Formatted Weight Tests (placeholder for Phase 4)
    // formattedWeight(useMetric:) will be added in Phase 4
}
