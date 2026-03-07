import Foundation

// MARK: - Weekly Data Summary

struct WeeklyDataSummary {
    var avgCalories: Double
    var avgProtein: Double
    var avgCarbs: Double
    var avgFat: Double
    var totalWorkouts: Int
    var totalWorkoutMinutes: Double
    var weightChange: Double?
    var currentWeight: Double?
    var bodyFatPercentage: Double?
    var goal: String
}

// MARK: - Photo Analysis Result

struct PhotoAnalysisResult {
    var summary: String
    var muscleDevelopment: String
    var bodyComposition: String
    var comparisonNotes: String?
    var areasOfProgress: [String]
    var areasToImprove: [String]
    var recommendations: [String]
}

// MARK: - Form Analysis Result

struct FormAnalysisResult {
    var overallRating: String
    var feedback: String
    var keyPoints: [FormAnalysisKeyPoint]
}

struct FormAnalysisKeyPoint: Codable {
    var area: String
    var observation: String
    var suggestion: String
    var isPositive: Bool
}

// MARK: - Weekly Review Result

struct WeeklyReviewResult {
    var summary: String
    var trainingFeedback: String
    var nutritionFeedback: String
    var bodyCompFeedback: String
    var recommendations: [String]
    var overallScore: Int?
}

// MARK: - AI Coach Errors

enum AICoachError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case noContent
    case emptyPhotos

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Claude API key is not configured. Add your API key in Settings."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Invalid response received from Claude API."
        case .httpError(let statusCode, let message):
            if let message {
                return "Claude API error (HTTP \(statusCode)): \(message)"
            }
            return "Claude API returned an error. (HTTP \(statusCode))"
        case .decodingError(let error):
            return "Failed to decode Claude API response: \(error.localizedDescription)"
        case .noContent:
            return "Claude API returned an empty response."
        case .emptyPhotos:
            return "No photos provided for analysis."
        }
    }
}

// MARK: - Claude API Response Types

private struct ClaudeAPIResponse: Codable {
    let content: [ClaudeContentBlock]
    let role: String
    let stop_reason: String?
}

private struct ClaudeContentBlock: Codable {
    let type: String
    let text: String?
}

private struct ClaudeAPIError: Codable {
    let type: String?
    let error: ClaudeErrorDetail?
}

private struct ClaudeErrorDetail: Codable {
    let type: String?
    let message: String?
}

// MARK: - AI Coach Service

@Observable
final class AICoachService {

    // MARK: - Properties

    private let apiEndpoint = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    private let anthropicVersion = "2023-06-01"
    private let session: URLSession

    private(set) var isLoading = false

    var isConfigured: Bool {
        return !resolvedAPIKey.isEmpty
    }

    /// Resolves the API key: embedded Secrets key first, then Keychain fallback.
    private var resolvedAPIKey: String {
        let embeddedKey = Secrets.anthropicAPIKey
        if !embeddedKey.isEmpty && embeddedKey != "YOUR_ANTHROPIC_API_KEY_HERE" {
            return embeddedKey
        }
        return KeychainService.retrieve(key: KeychainService.anthropicAPIKey) ?? ""
    }

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Public Methods

    /// Analyze progress photos with optional comparison to previous week's photos.
    func analyzeProgressPhotos(
        photos: [Data],
        previousPhotos: [Data]? = nil,
        weeklyData: WeeklyDataSummary
    ) async throws -> PhotoAnalysisResult {
        guard !photos.isEmpty else { throw AICoachError.emptyPhotos }

        var contentBlocks: [[String: Any]] = []

        // Add current photos
        for photoData in photos {
            let base64 = photoData.base64EncodedString()
            contentBlocks.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64,
                ],
            ])
        }

        contentBlocks.append([
            "type": "text",
            "text": "These are my current progress photos.",
        ])

        // Add previous photos if available
        if let previousPhotos, !previousPhotos.isEmpty {
            for photoData in previousPhotos {
                let base64 = photoData.base64EncodedString()
                contentBlocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64,
                    ],
                ])
            }

            contentBlocks.append([
                "type": "text",
                "text": "These are my progress photos from the previous week for comparison.",
            ])
        }

        // Add weekly data context and prompt
        let weeklyContext = formatWeeklyDataContext(weeklyData)
        let hasComparison = previousPhotos != nil && !(previousPhotos?.isEmpty ?? true)

        let prompt = """
        You are an expert fitness coach and body composition analyst. Analyze the progress photos provided.

        \(weeklyContext)

        \(hasComparison ? "Compare the current photos to the previous week's photos and note any visible changes." : "This is a baseline set of photos with no previous comparison available.")

        Respond ONLY with a JSON object in this exact format (no markdown, no code fences):
        {
          "summary": "Overall assessment of current physique and progress",
          "muscleDevelopment": "Analysis of visible muscle development and symmetry",
          "bodyComposition": "Assessment of body fat distribution and overall composition",
          \(hasComparison ? "\"comparisonNotes\": \"Changes observed compared to previous photos\"," : "\"comparisonNotes\": null,")
          "areasOfProgress": ["area 1", "area 2"],
          "areasToImprove": ["area 1", "area 2"],
          "recommendations": ["recommendation 1", "recommendation 2"]
        }
        """

        contentBlocks.append([
            "type": "text",
            "text": prompt,
        ])

        let responseText = try await sendRequest(contentBlocks: contentBlocks)
        return try parsePhotoAnalysisResult(from: responseText)
    }

    /// Analyze weightlifting form from extracted video frames.
    func analyzeFormVideo(
        frames: [Data],
        exerciseName: String
    ) async throws -> FormAnalysisResult {
        guard !frames.isEmpty else { throw AICoachError.emptyPhotos }

        var contentBlocks: [[String: Any]] = []

        // Add video frames as images
        for frameData in frames {
            let base64 = frameData.base64EncodedString()
            contentBlocks.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64,
                ],
            ])
        }

        // Add prompt
        let prompt = """
        You are an expert strength and conditioning coach specializing in exercise form analysis. \
        These images are sequential frames extracted from a video of someone performing the exercise: \(exerciseName).

        Analyze the form throughout the movement and provide detailed feedback. Pay attention to:
        - Joint angles and alignment
        - Bar/weight path
        - Stance and foot positioning
        - Core bracing and spinal alignment
        - Range of motion
        - Tempo and control
        - Common mistakes specific to this exercise

        Respond ONLY with a JSON object in this exact format (no markdown, no code fences):
        {
          "overallRating": "excellent" | "good" | "needs_work" | "poor",
          "feedback": "Detailed overall assessment of the form",
          "keyPoints": [
            {
              "area": "Body area or movement phase",
              "observation": "What was observed",
              "suggestion": "How to improve or maintain",
              "isPositive": true or false
            }
          ]
        }
        """

        contentBlocks.append([
            "type": "text",
            "text": prompt,
        ])

        let responseText = try await sendRequest(contentBlocks: contentBlocks, maxTokens: 4096)
        return try parseFormAnalysisResult(from: responseText)
    }

    /// Generate a comprehensive weekly coaching review.
    func generateWeeklyReview(
        weeklyData: WeeklyDataSummary,
        photos: [Data]? = nil,
        previousRecommendations: [String]? = nil
    ) async throws -> WeeklyReviewResult {
        var contentBlocks: [[String: Any]] = []

        // Add photos if available
        if let photos, !photos.isEmpty {
            for photoData in photos {
                let base64 = photoData.base64EncodedString()
                contentBlocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64,
                    ],
                ])
            }
        }

        // Build the prompt
        let weeklyContext = formatWeeklyDataContext(weeklyData)
        var previousRecText = ""
        if let previousRecommendations, !previousRecommendations.isEmpty {
            let joined = previousRecommendations.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
            previousRecText = """

            Previous week's recommendations:
            \(joined)

            Assess whether the user appears to have followed these recommendations based on the data.
            """
        }

        let hasPhotos = photos != nil && !(photos?.isEmpty ?? true)

        let prompt = """
        You are an expert fitness coach providing a comprehensive weekly review. \
        Analyze the following weekly data and provide actionable coaching feedback.

        \(weeklyContext)
        \(previousRecText)

        \(hasPhotos ? "Progress photos from this week are included above for visual assessment." : "No progress photos available this week.")

        Respond ONLY with a JSON object in this exact format (no markdown, no code fences):
        {
          "summary": "Brief overall summary of the week",
          "trainingFeedback": "Detailed feedback on training volume, intensity, and consistency",
          "nutritionFeedback": "Detailed feedback on nutrition adherence and macros",
          "bodyCompFeedback": "Feedback on body composition changes and trends",
          "recommendations": ["recommendation 1", "recommendation 2", "recommendation 3"],
          "overallScore": 1-10 integer or null if insufficient data
        }
        """

        contentBlocks.append([
            "type": "text",
            "text": prompt,
        ])

        let responseText = try await sendRequest(contentBlocks: contentBlocks, maxTokens: 4096)
        return try parseWeeklyReviewResult(from: responseText)
    }

    /// Chat with the AI coach. Supports multi-turn conversations with user context.
    func chat(
        messages: [(role: String, content: String)],
        userContext: String
    ) async throws -> String {
        let systemPrompt = """
        You are an expert fitness and nutrition coach. You provide personalized, evidence-based advice \
        on training, nutrition, recovery, and body composition. Be supportive but honest. Keep responses \
        concise and actionable. Use the user's data context to personalize your advice.

        Current user context:
        \(userContext)
        """

        let apiMessages = messages.map { message -> [String: Any] in
            [
                "role": message.role,
                "content": message.content,
            ]
        }

        let responseText = try await sendChatRequest(
            messages: apiMessages,
            systemPrompt: systemPrompt,
            maxTokens: 2048
        )

        return responseText
    }

    // MARK: - Private API Methods

    /// Send a request with multimodal content blocks (images + text).
    private func sendRequest(
        contentBlocks: [[String: Any]],
        maxTokens: Int = 4096
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        let apiKey = resolvedAPIKey
        guard !apiKey.isEmpty else {
            throw AICoachError.notConfigured
        }

        guard let url = URL(string: apiEndpoint) else {
            throw AICoachError.invalidURL
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                [
                    "role": "user",
                    "content": contentBlocks,
                ],
            ],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return try await executeRequest(request)
    }

    /// Send a chat request with a system prompt and message history.
    private func sendChatRequest(
        messages: [[String: Any]],
        systemPrompt: String,
        maxTokens: Int = 2048
    ) async throws -> String {
        isLoading = true
        defer { isLoading = false }

        let apiKey = resolvedAPIKey
        guard !apiKey.isEmpty else {
            throw AICoachError.notConfigured
        }

        guard let url = URL(string: apiEndpoint) else {
            throw AICoachError.invalidURL
        }

        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": messages,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return try await executeRequest(request)
    }

    /// Execute a URLRequest and extract the text content from Claude's response.
    private func executeRequest(_ request: URLRequest) async throws -> String {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AICoachError.invalidResponse
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AICoachError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from response body
            var errorMessage: String?
            if let errorResponse = try? JSONDecoder().decode(ClaudeAPIError.self, from: data) {
                errorMessage = errorResponse.error?.message
            }
            throw AICoachError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        let apiResponse: ClaudeAPIResponse
        do {
            apiResponse = try JSONDecoder().decode(ClaudeAPIResponse.self, from: data)
        } catch {
            throw AICoachError.decodingError(error)
        }

        // Extract text from the first text content block
        guard let textBlock = apiResponse.content.first(where: { $0.type == "text" }),
              let text = textBlock.text, !text.isEmpty else {
            throw AICoachError.noContent
        }

        return text
    }

    // MARK: - Response Parsing

    /// Parse a PhotoAnalysisResult from Claude's JSON response, with fallback to raw text.
    private func parsePhotoAnalysisResult(from text: String) throws -> PhotoAnalysisResult {
        let cleaned = cleanJSONString(text)

        if let data = cleaned.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let json {
                    return PhotoAnalysisResult(
                        summary: json["summary"] as? String ?? "",
                        muscleDevelopment: json["muscleDevelopment"] as? String ?? "",
                        bodyComposition: json["bodyComposition"] as? String ?? "",
                        comparisonNotes: json["comparisonNotes"] as? String,
                        areasOfProgress: json["areasOfProgress"] as? [String] ?? [],
                        areasToImprove: json["areasToImprove"] as? [String] ?? [],
                        recommendations: json["recommendations"] as? [String] ?? []
                    )
                }
            } catch {
                // Fall through to raw text fallback
            }
        }

        // Fallback: return the raw text as the summary
        return PhotoAnalysisResult(
            summary: text,
            muscleDevelopment: "",
            bodyComposition: "",
            comparisonNotes: nil,
            areasOfProgress: [],
            areasToImprove: [],
            recommendations: []
        )
    }

    /// Parse a FormAnalysisResult from Claude's JSON response, with fallback to raw text.
    private func parseFormAnalysisResult(from text: String) throws -> FormAnalysisResult {
        let cleaned = cleanJSONString(text)

        if let data = cleaned.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let json {
                    var keyPoints: [FormAnalysisKeyPoint] = []

                    if let keyPointsArray = json["keyPoints"] as? [[String: Any]] {
                        for kp in keyPointsArray {
                            let point = FormAnalysisKeyPoint(
                                area: kp["area"] as? String ?? "",
                                observation: kp["observation"] as? String ?? "",
                                suggestion: kp["suggestion"] as? String ?? "",
                                isPositive: kp["isPositive"] as? Bool ?? false
                            )
                            keyPoints.append(point)
                        }
                    }

                    return FormAnalysisResult(
                        overallRating: json["overallRating"] as? String ?? "needs_work",
                        feedback: json["feedback"] as? String ?? "",
                        keyPoints: keyPoints
                    )
                }
            } catch {
                // Fall through to raw text fallback
            }
        }

        // Fallback: return the raw text as feedback
        return FormAnalysisResult(
            overallRating: "needs_work",
            feedback: text,
            keyPoints: []
        )
    }

    /// Parse a WeeklyReviewResult from Claude's JSON response, with fallback to raw text.
    private func parseWeeklyReviewResult(from text: String) throws -> WeeklyReviewResult {
        let cleaned = cleanJSONString(text)

        if let data = cleaned.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                if let json {
                    let overallScore: Int?
                    if let scoreValue = json["overallScore"] {
                        if let intValue = scoreValue as? Int {
                            overallScore = intValue
                        } else if let doubleValue = scoreValue as? Double {
                            overallScore = Int(doubleValue)
                        } else {
                            overallScore = nil
                        }
                    } else {
                        overallScore = nil
                    }

                    return WeeklyReviewResult(
                        summary: json["summary"] as? String ?? "",
                        trainingFeedback: json["trainingFeedback"] as? String ?? "",
                        nutritionFeedback: json["nutritionFeedback"] as? String ?? "",
                        bodyCompFeedback: json["bodyCompFeedback"] as? String ?? "",
                        recommendations: json["recommendations"] as? [String] ?? [],
                        overallScore: overallScore
                    )
                }
            } catch {
                // Fall through to raw text fallback
            }
        }

        // Fallback: return the raw text as the summary
        return WeeklyReviewResult(
            summary: text,
            trainingFeedback: "",
            nutritionFeedback: "",
            bodyCompFeedback: "",
            recommendations: [],
            overallScore: nil
        )
    }

    // MARK: - Helpers

    /// Format weekly data into a human-readable context string for Claude.
    private func formatWeeklyDataContext(_ data: WeeklyDataSummary) -> String {
        var lines: [String] = []
        lines.append("Weekly Data Summary:")
        lines.append("- Goal: \(data.goal)")
        lines.append("- Average daily calories: \(Int(data.avgCalories)) kcal")
        lines.append("- Average daily protein: \(Int(data.avgProtein))g")
        lines.append("- Average daily carbs: \(Int(data.avgCarbs))g")
        lines.append("- Average daily fat: \(Int(data.avgFat))g")
        lines.append("- Total workouts: \(data.totalWorkouts)")
        lines.append("- Total workout minutes: \(Int(data.totalWorkoutMinutes))")

        if let currentWeight = data.currentWeight {
            lines.append("- Current weight: \(String(format: "%.1f", currentWeight)) kg")
        }
        if let weightChange = data.weightChange {
            let direction = weightChange >= 0 ? "+" : ""
            lines.append("- Weight change this week: \(direction)\(String(format: "%.1f", weightChange)) kg")
        }
        if let bodyFat = data.bodyFatPercentage {
            lines.append("- Body fat percentage: \(String(format: "%.1f", bodyFat))%")
        }

        return lines.joined(separator: "\n")
    }

    /// Remove markdown code fences and leading/trailing whitespace from a JSON string.
    private func cleanJSONString(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code fences if present
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
