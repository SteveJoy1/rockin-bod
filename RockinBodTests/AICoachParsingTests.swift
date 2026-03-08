import XCTest
@testable import RockinBod

final class AICoachParsingTests: XCTestCase {

    var service: AICoachService!

    override func setUp() {
        super.setUp()
        service = AICoachService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - cleanJSONString Tests

    func testCleanJSONString_removesMarkdownCodeFences() {
        let input = "```json\n{\"key\": \"value\"}\n```"
        let result = service.cleanJSONString(input)
        XCTAssertEqual(result, "{\"key\": \"value\"}")
    }

    func testCleanJSONString_removesCodeFencesWithoutLanguage() {
        let input = "```\n{\"key\": \"value\"}\n```"
        let result = service.cleanJSONString(input)
        XCTAssertEqual(result, "{\"key\": \"value\"}")
    }

    func testCleanJSONString_trimsWhitespace() {
        let input = "  \n{\"key\": \"value\"}\n  "
        let result = service.cleanJSONString(input)
        XCTAssertEqual(result, "{\"key\": \"value\"}")
    }

    func testCleanJSONString_passesCleanJSONThrough() {
        let input = "{\"key\": \"value\"}"
        let result = service.cleanJSONString(input)
        XCTAssertEqual(result, "{\"key\": \"value\"}")
    }

    // MARK: - parseWeeklyReviewResult Tests

    func testParseWeeklyReviewResult_validJSON() throws {
        let json = """
        {
            "summary": "Good week overall",
            "trainingFeedback": "Strong lifts",
            "nutritionFeedback": "Hit protein targets",
            "bodyCompFeedback": "Slight improvement",
            "recommendations": ["Increase volume", "Add cardio"],
            "overallScore": 8
        }
        """
        let result = try service.parseWeeklyReviewResult(from: json)
        XCTAssertEqual(result.summary, "Good week overall")
        XCTAssertEqual(result.trainingFeedback, "Strong lifts")
        XCTAssertEqual(result.nutritionFeedback, "Hit protein targets")
        XCTAssertEqual(result.bodyCompFeedback, "Slight improvement")
        XCTAssertEqual(result.recommendations.count, 2)
        XCTAssertEqual(result.overallScore, 8)
    }

    func testParseWeeklyReviewResult_withMarkdownFences() throws {
        let json = """
        ```json
        {
            "summary": "Decent week",
            "trainingFeedback": "Consistent",
            "nutritionFeedback": "Close to targets",
            "bodyCompFeedback": "Stable",
            "recommendations": ["Rest more"],
            "overallScore": 7
        }
        ```
        """
        let result = try service.parseWeeklyReviewResult(from: json)
        XCTAssertEqual(result.summary, "Decent week")
        XCTAssertEqual(result.overallScore, 7)
    }

    func testParseWeeklyReviewResult_fallbackToRawText() throws {
        let rawText = "This is not JSON at all, just a plain response from the AI."
        let result = try service.parseWeeklyReviewResult(from: rawText)
        XCTAssertEqual(result.summary, rawText)
        XCTAssertTrue(result.trainingFeedback.isEmpty)
        XCTAssertTrue(result.nutritionFeedback.isEmpty)
        XCTAssertTrue(result.recommendations.isEmpty)
        XCTAssertNil(result.overallScore)
    }

    func testParseWeeklyReviewResult_nullScore() throws {
        let json = """
        {
            "summary": "Not enough data",
            "trainingFeedback": "",
            "nutritionFeedback": "",
            "bodyCompFeedback": "",
            "recommendations": [],
            "overallScore": null
        }
        """
        let result = try service.parseWeeklyReviewResult(from: json)
        XCTAssertNil(result.overallScore)
    }

    // MARK: - parseFormAnalysisResult Tests

    func testParseFormAnalysisResult_validJSON() throws {
        let json = """
        {
            "overallRating": "good",
            "feedback": "Solid form on the squat",
            "keyPoints": [
                {
                    "area": "Knees",
                    "observation": "Good tracking",
                    "suggestion": "Keep it up",
                    "isPositive": true
                }
            ]
        }
        """
        let result = try service.parseFormAnalysisResult(from: json)
        XCTAssertEqual(result.overallRating, "good")
        XCTAssertEqual(result.feedback, "Solid form on the squat")
        XCTAssertEqual(result.keyPoints.count, 1)
        XCTAssertTrue(result.keyPoints.first?.isPositive ?? false)
    }

    func testParseFormAnalysisResult_fallbackToRawText() throws {
        let rawText = "Your squat form looks good overall."
        let result = try service.parseFormAnalysisResult(from: rawText)
        XCTAssertEqual(result.overallRating, "needs_work")
        XCTAssertEqual(result.feedback, rawText)
        XCTAssertTrue(result.keyPoints.isEmpty)
    }
}
