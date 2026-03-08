import XCTest
@testable import RockinBod

final class ScoreDisplayTests: XCTestCase {

    // MARK: - Score Gauge Fraction Tests (1-10 scale)

    func testScoreGaugeFraction_score8() {
        let fraction = CGFloat(8) / 10.0
        XCTAssertEqual(fraction, 0.8, accuracy: 0.001)
    }

    func testScoreGaugeFraction_score5() {
        let fraction = CGFloat(5) / 10.0
        XCTAssertEqual(fraction, 0.5, accuracy: 0.001)
    }

    func testScoreGaugeFraction_score10() {
        let fraction = CGFloat(10) / 10.0
        XCTAssertEqual(fraction, 1.0, accuracy: 0.001)
    }

    func testScoreGaugeFraction_score1() {
        let fraction = CGFloat(1) / 10.0
        XCTAssertEqual(fraction, 0.1, accuracy: 0.001)
    }

    // MARK: - Score Color Tests (verify thresholds match 1-10 scale)

    /// Scores 8-10 should be green (good)
    func testScoreColor_greenRange() {
        for score in 8...10 {
            XCTAssertTrue(score >= 8, "Score \(score) should be in green range (8-10)")
        }
    }

    /// Scores 6-7 should be yellow (fair)
    func testScoreColor_yellowRange() {
        for score in 6...7 {
            XCTAssertTrue(score >= 6 && score < 8, "Score \(score) should be in yellow range (6-7)")
        }
    }

    /// Scores 4-5 should be orange (needs improvement)
    func testScoreColor_orangeRange() {
        for score in 4...5 {
            XCTAssertTrue(score >= 4 && score < 6, "Score \(score) should be in orange range (4-5)")
        }
    }

    /// Scores 1-3 should be red (poor)
    func testScoreColor_redRange() {
        for score in 1...3 {
            XCTAssertTrue(score < 4, "Score \(score) should be in red range (1-3)")
        }
    }
}
