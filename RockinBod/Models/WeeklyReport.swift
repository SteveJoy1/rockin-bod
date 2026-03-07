import Foundation
import SwiftData

@Model
final class WeeklyReport {
    var id: UUID
    var weekStartDate: Date
    var weekEndDate: Date
    var createdAt: Date
    var summary: String
    var trainingFeedback: String
    var nutritionFeedback: String
    var bodyCompFeedback: String
    var recommendationsData: Data?
    var overallScore: Int?
    // Aggregated stats for the week
    var totalWorkouts: Int
    var totalWorkoutMinutes: Double
    var avgCalories: Double
    var avgProtein: Double
    var avgCarbs: Double
    var avgFat: Double
    var startWeight: Double?
    var endWeight: Double?
    @Relationship(deleteRule: .cascade) var photos: [ProgressPhoto]

    var recommendations: [String] {
        get {
            guard let data = recommendationsData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            recommendationsData = try? JSONEncoder().encode(newValue)
        }
    }

    var weightChange: Double? {
        guard let start = startWeight, let end = endWeight else { return nil }
        return end - start
    }

    init(
        weekStartDate: Date = Date(),
        weekEndDate: Date = Date(),
        summary: String = "",
        trainingFeedback: String = "",
        nutritionFeedback: String = "",
        bodyCompFeedback: String = "",
        recommendations: [String] = [],
        overallScore: Int? = nil,
        totalWorkouts: Int = 0,
        totalWorkoutMinutes: Double = 0,
        avgCalories: Double = 0,
        avgProtein: Double = 0,
        avgCarbs: Double = 0,
        avgFat: Double = 0,
        startWeight: Double? = nil,
        endWeight: Double? = nil
    ) {
        self.id = UUID()
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.createdAt = Date()
        self.summary = summary
        self.trainingFeedback = trainingFeedback
        self.nutritionFeedback = nutritionFeedback
        self.bodyCompFeedback = bodyCompFeedback
        self.recommendationsData = try? JSONEncoder().encode(recommendations)
        self.overallScore = overallScore
        self.totalWorkouts = totalWorkouts
        self.totalWorkoutMinutes = totalWorkoutMinutes
        self.avgCalories = avgCalories
        self.avgProtein = avgProtein
        self.avgCarbs = avgCarbs
        self.avgFat = avgFat
        self.startWeight = startWeight
        self.endWeight = endWeight
        self.photos = []
    }
}
