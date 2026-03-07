import Foundation
import SwiftData

@Model
final class FormCheckResult {
    var id: UUID
    var date: Date
    var exerciseName: String
    var videoBookmarkData: Data?
    var thumbnailData: Data?
    var feedback: String
    var keyPointsData: Data?
    var overallRatingRaw: String

    var overallRating: FormRating {
        get { FormRating(rawValue: overallRatingRaw) ?? .needsWork }
        set { overallRatingRaw = newValue.rawValue }
    }

    var keyPoints: [FormKeyPoint] {
        get {
            guard let data = keyPointsData else { return [] }
            return (try? JSONDecoder().decode([FormKeyPoint].self, from: data)) ?? []
        }
        set {
            keyPointsData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        date: Date = Date(),
        exerciseName: String = "",
        feedback: String = "",
        overallRating: FormRating = .needsWork,
        keyPoints: [FormKeyPoint] = []
    ) {
        self.id = UUID()
        self.date = date
        self.exerciseName = exerciseName
        self.feedback = feedback
        self.overallRatingRaw = overallRating.rawValue
        self.keyPointsData = try? JSONEncoder().encode(keyPoints)
    }
}

enum FormRating: String, CaseIterable, Codable {
    case excellent = "excellent"
    case good = "good"
    case needsWork = "needs_work"
    case poor = "poor"

    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .needsWork: return "Needs Work"
        case .poor: return "Poor"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .needsWork: return "orange"
        case .poor: return "red"
        }
    }
}

struct FormKeyPoint: Codable, Identifiable {
    var id: UUID
    var area: String
    var observation: String
    var suggestion: String
    var isPositive: Bool

    init(area: String, observation: String, suggestion: String, isPositive: Bool) {
        self.id = UUID()
        self.area = area
        self.observation = observation
        self.suggestion = suggestion
        self.isPositive = isPositive
    }
}
