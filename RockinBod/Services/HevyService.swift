import Foundation
import SwiftData

// MARK: - Hevy API Response Types

struct HevyWorkoutsResponse: Codable {
    let page: Int
    let page_count: Int
    let workouts: [HevyWorkout]
}

struct HevyWorkout: Codable {
    let id: String
    let title: String
    let start_time: String
    let end_time: String
    let exercises: [HevyExerciseData]
}

struct HevyExerciseData: Codable {
    let title: String
    let exercise_template_id: String
    let sets: [HevySet]
}

struct HevySet: Codable {
    let type: String // "normal", "warmup", "drop", "failure"
    let weight_kg: Double?
    let reps: Int?
    let duration_seconds: Double?
    let rpe: Double?
}

struct HevyExercise: Codable {
    let id: String
    let title: String
    let type: String?
    let primary_muscle_group: String?
    let secondary_muscle_groups: [String]?
}

struct HevyExercisesResponse: Codable {
    let page: Int
    let page_count: Int
    let exercises: [HevyExercise]
}

// MARK: - Hevy Errors

enum HevyError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Hevy API key is not configured. Add your API key in Settings."
        case .invalidURL:
            return "Invalid Hevy API URL."
        case .invalidResponse:
            return "Invalid response received from Hevy API."
        case .httpError(let statusCode):
            return "Hevy API returned an error. (HTTP \(statusCode))"
        case .decodingError(let error):
            return "Failed to decode Hevy API response: \(error.localizedDescription)"
        case .noData:
            return "No workout data found."
        }
    }
}

// MARK: - Hevy Service

@Observable
final class HevyService {

    // MARK: - Properties

    private let baseURL = "https://api.hevyapp.com/v1"
    private let session: URLSession
    private let dateFormatter: ISO8601DateFormatter

    var apiKey: String? {
        KeychainService.retrieve(key: KeychainService.hevyAPIKey)
    }

    var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    // MARK: - Initialization

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)

        self.dateFormatter = ISO8601DateFormatter()
        self.dateFormatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
        ]
    }

    // MARK: - Public Methods

    /// Fetch a page of workouts from the Hevy API.
    func fetchWorkouts(page: Int = 1, pageSize: Int = 10) async throws -> HevyWorkoutsResponse {
        let url = try buildURL(path: "/workouts", queryItems: [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
        ])

        let request = try buildRequest(url: url)
        return try await performRequest(request)
    }

    /// Fetch all exercises from the Hevy API, paginating automatically.
    func fetchExercises() async throws -> [HevyExercise] {
        var allExercises: [HevyExercise] = []
        var currentPage = 1
        var totalPages = 1

        while currentPage <= totalPages {
            let url = try buildURL(path: "/exercises", queryItems: [
                URLQueryItem(name: "page", value: String(currentPage)),
                URLQueryItem(name: "pageSize", value: String(100)),
            ])

            let request = try buildRequest(url: url)
            let response: HevyExercisesResponse = try await performRequest(request)

            allExercises.append(contentsOf: response.exercises)
            totalPages = response.page_count
            currentPage += 1
        }

        return allExercises
    }

    /// Import workouts from Hevy since the given date into the local SwiftData store.
    /// Returns the number of workouts imported.
    @MainActor
    func importWorkouts(since: Date, context: ModelContext) async throws -> Int {
        guard isConfigured else { throw HevyError.notConfigured }

        var importedCount = 0
        var currentPage = 1
        var totalPages = 1
        var shouldContinue = true

        while currentPage <= totalPages && shouldContinue {
            let response = try await fetchWorkouts(page: currentPage, pageSize: 20)
            totalPages = response.page_count

            for hevyWorkout in response.workouts {
                // Parse the workout start time
                guard let workoutDate = parseDate(hevyWorkout.start_time) else {
                    continue
                }

                // Stop if the workout is older than the cutoff date
                if workoutDate < since {
                    shouldContinue = false
                    break
                }

                // Check for duplicate imports using Hevy workout ID in sourceIdentifier
                let hevyId = hevyWorkout.id
                let hevySource = "hevy"
                let existingPredicate = #Predicate<WorkoutSession> { session in
                    session.sourceRaw == hevySource && session.sourceIdentifier == hevyId
                }
                let existingDescriptor = FetchDescriptor<WorkoutSession>(predicate: existingPredicate)
                let existingCount = (try? context.fetchCount(existingDescriptor)) ?? 0

                if existingCount > 0 {
                    continue
                }

                // Calculate duration from start and end times
                let durationMinutes: Double
                if let endDate = parseDate(hevyWorkout.end_time) {
                    durationMinutes = endDate.timeIntervalSince(workoutDate) / 60.0
                } else {
                    durationMinutes = 0
                }

                // Create the WorkoutSession
                let workoutSession = WorkoutSession(
                    date: workoutDate,
                    endDate: parseDate(hevyWorkout.end_time),
                    name: hevyWorkout.title,
                    workoutType: inferWorkoutType(from: hevyWorkout),
                    durationMinutes: durationMinutes,
                    source: .hevy,
                    sourceIdentifier: hevyWorkout.id
                )

                // Convert exercises and sets
                var exerciseSets: [ExerciseSet] = []
                for exercise in hevyWorkout.exercises {
                    for (index, hevySet) in exercise.sets.enumerated() {
                        let exerciseSet = ExerciseSet(
                            exerciseName: exercise.title,
                            setNumber: index + 1,
                            reps: hevySet.reps,
                            weightKg: hevySet.weight_kg,
                            durationSeconds: hevySet.duration_seconds,
                            rpe: hevySet.rpe,
                            isWarmup: hevySet.type == "warmup"
                        )
                        exerciseSets.append(exerciseSet)
                    }
                }

                workoutSession.exercises = exerciseSets
                context.insert(workoutSession)
                importedCount += 1
            }

            currentPage += 1
        }

        try context.save()
        return importedCount
    }

    // MARK: - Private Helpers

    /// Build a URL from a path and optional query items.
    private func buildURL(path: String, queryItems: [URLQueryItem] = []) throws -> URL {
        guard var components = URLComponents(string: baseURL + path) else {
            throw HevyError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw HevyError.invalidURL
        }
        return url
    }

    /// Build an authenticated URLRequest.
    private func buildRequest(url: URL, method: String = "GET") throws -> URLRequest {
        guard let key = apiKey, !key.isEmpty else {
            throw HevyError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// Perform a network request and decode the response.
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HevyError.invalidResponse
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HevyError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HevyError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw HevyError.decodingError(error)
        }
    }

    /// Parse an ISO 8601 date string into a Date.
    func parseDate(_ dateString: String) -> Date? {
        // Try with fractional seconds first
        if let date = dateFormatter.date(from: dateString) {
            return date
        }

        // Fallback without fractional seconds
        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]
        return fallbackFormatter.date(from: dateString)
    }

    /// Infer a WorkoutType from the Hevy workout data.
    func inferWorkoutType(from workout: HevyWorkout) -> WorkoutType {
        let titleLower = workout.title.lowercased()

        if titleLower.contains("cardio") || titleLower.contains("run") || titleLower.contains("jog") {
            return .cardio
        }
        if titleLower.contains("hiit") || titleLower.contains("circuit") || titleLower.contains("crossfit") {
            return .hiit
        }
        if titleLower.contains("yoga") || titleLower.contains("stretch") || titleLower.contains("flexibility") {
            return .flexibility
        }
        if titleLower.contains("walk") {
            return .walking
        }
        if titleLower.contains("running") || titleLower.contains("sprint") {
            return .running
        }
        if titleLower.contains("cycling") || titleLower.contains("bike") {
            return .cycling
        }
        if titleLower.contains("swim") {
            return .swimming
        }

        // Default: Hevy is primarily a strength training app
        return .strength
    }
}
