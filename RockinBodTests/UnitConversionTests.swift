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

    // MARK: - Formatted Weight Tests

    func testFormattedWeight_metric() {
        let weight = 85.3
        XCTAssertEqual(weight.formattedWeight(useMetric: true), "85.3 kg")
    }

    func testFormattedWeight_imperial() {
        let weight = 85.3 // kg
        let result = weight.formattedWeight(useMetric: false)
        XCTAssertTrue(result.contains("lbs"))
        // 85.3 * 2.20462 ≈ 188.05, formatted to one decimal
        XCTAssertTrue(result.contains("188."))
    }

    func testFormattedLength_metric() {
        let length = 180.0
        XCTAssertEqual(length.formattedLength(useMetric: true), "180.0 cm")
    }

    func testFormattedLength_imperial() {
        let length = 180.0 // cm
        let result = length.formattedLength(useMetric: false)
        XCTAssertTrue(result.contains("in"))
        XCTAssertTrue(result.contains("70.9")) // 180 / 2.54 ≈ 70.9
    }
}
