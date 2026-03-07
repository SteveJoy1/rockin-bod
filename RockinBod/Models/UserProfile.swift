import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var birthDate: Date?
    var heightInCm: Double
    var goalRaw: String
    var targetCalories: Int
    var targetProteinGrams: Int
    var targetCarbsGrams: Int
    var targetFatGrams: Int
    var targetFiberGrams: Int
    var weeklyReviewDay: Int // 0 = Sunday, 1 = Monday, etc.
    var createdAt: Date
    var updatedAt: Date

    var goal: FitnessGoal {
        get { FitnessGoal(rawValue: goalRaw) ?? .recomposition }
        set { goalRaw = newValue.rawValue }
    }

    init(
        name: String = "",
        birthDate: Date? = nil,
        heightInCm: Double = 175,
        goal: FitnessGoal = .recomposition,
        targetCalories: Int = 2200,
        targetProteinGrams: Int = 160,
        targetCarbsGrams: Int = 220,
        targetFatGrams: Int = 73,
        targetFiberGrams: Int = 30,
        weeklyReviewDay: Int = 0
    ) {
        self.name = name
        self.birthDate = birthDate
        self.heightInCm = heightInCm
        self.goalRaw = goal.rawValue
        self.targetCalories = targetCalories
        self.targetProteinGrams = targetProteinGrams
        self.targetCarbsGrams = targetCarbsGrams
        self.targetFatGrams = targetFatGrams
        self.targetFiberGrams = targetFiberGrams
        self.weeklyReviewDay = weeklyReviewDay
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum FitnessGoal: String, CaseIterable, Codable {
    case loseFat = "lose_fat"
    case buildMuscle = "build_muscle"
    case recomposition = "recomposition"
    case maintain = "maintain"
    case improveEndurance = "improve_endurance"

    var displayName: String {
        switch self {
        case .loseFat: return "Lose Fat"
        case .buildMuscle: return "Build Muscle"
        case .recomposition: return "Body Recomposition"
        case .maintain: return "Maintain"
        case .improveEndurance: return "Improve Endurance"
        }
    }
}
