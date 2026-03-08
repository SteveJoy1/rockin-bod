import XCTest
@testable import RockinBod

final class CronometerServiceTests: XCTestCase {

    var service: CronometerService!

    override func setUp() {
        super.setUp()
        service = CronometerService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - parseCSVRows Tests

    func testParseCSVRows_simpleCSV() {
        let csv = "Name,Calories,Protein\nApple,95,0.5\nChicken,165,31"
        let rows = service.parseCSVRows(csv)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], ["Name", "Calories", "Protein"])
        XCTAssertEqual(rows[1], ["Apple", "95", "0.5"])
        XCTAssertEqual(rows[2], ["Chicken", "165", "31"])
    }

    func testParseCSVRows_quotedFieldsWithCommas() {
        let csv = "Name,Description,Calories\n\"Chicken, grilled\",\"High protein, low fat\",165"
        let rows = service.parseCSVRows(csv)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1][0], "Chicken, grilled")
        XCTAssertEqual(rows[1][1], "High protein, low fat")
        XCTAssertEqual(rows[1][2], "165")
    }

    func testParseCSVRows_emptyFields() {
        let csv = "A,B,C\n1,,3\n,,\n4,5,6"
        let rows = service.parseCSVRows(csv)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(rows[1], ["1", "", "3"])
        XCTAssertEqual(rows[2], ["", "", ""])
        XCTAssertEqual(rows[3], ["4", "5", "6"])
    }

    func testParseCSVRows_windowsLineEndings() {
        // Swift treats \r\n as a single grapheme cluster; parser normalizes line endings
        let csv = "A,B\r\n1,2\r\n3,4"
        let rows = service.parseCSVRows(csv)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0], ["A", "B"])
        XCTAssertEqual(rows[1], ["1", "2"])
        XCTAssertEqual(rows[2], ["3", "4"])
    }

    func testParseCSVRows_singleRow() {
        let csv = "A,B,C"
        let rows = service.parseCSVRows(csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0], ["A", "B", "C"])
    }

    // MARK: - parseDate Tests

    func testParseDate_standardFormat() {
        let date = CronometerService.parseDate("2024-01-15")
        XCTAssertNotNil(date)
    }

    func testParseDate_slashFormat() {
        let date = CronometerService.parseDate("01/15/2024")
        XCTAssertNotNil(date)
    }

    func testParseDate_invalidFormat() {
        let date = CronometerService.parseDate("not-a-date")
        XCTAssertNil(date)
    }

    func testParseDate_emptyString() {
        let date = CronometerService.parseDate("")
        XCTAssertNil(date)
    }

    // MARK: - doubleValue Tests

    func testDoubleValue_validNumber() {
        let row = ["Apple", "95.5", "0.5"]
        let columnIndex = ["Name": 0, "Calories": 1, "Protein": 2]
        let result = service.doubleValue(from: row, columnIndex: columnIndex, key: "Calories")
        XCTAssertEqual(result, 95.5, accuracy: 0.001)
    }

    func testDoubleValue_missingColumn() {
        let row = ["Apple", "95"]
        let columnIndex = ["Name": 0, "Calories": 1]
        let result = service.doubleValue(from: row, columnIndex: columnIndex, key: "Protein")
        XCTAssertEqual(result, 0)
    }

    func testDoubleValue_nonNumericValue() {
        let row = ["Apple", "N/A"]
        let columnIndex = ["Name": 0, "Calories": 1]
        let result = service.doubleValue(from: row, columnIndex: columnIndex, key: "Calories")
        XCTAssertEqual(result, 0)
    }
}
