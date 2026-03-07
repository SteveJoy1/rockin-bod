import Foundation
import SwiftData

@Model
final class NutritionEntry {
    var id: UUID
    var date: Date
    var sourceRaw: String
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
    var sugarGrams: Double
    var sodiumMg: Double
    var cholesterolMg: Double
    // Micronutrients stored as JSON-encoded dictionary
    var micronutrientsData: Data?

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var micronutrients: [String: Double] {
        get {
            guard let data = micronutrientsData else { return [:] }
            return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
        }
        set {
            micronutrientsData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        date: Date = Date(),
        source: DataSource = .manual,
        calories: Double = 0,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double = 0,
        sugarGrams: Double = 0,
        sodiumMg: Double = 0,
        cholesterolMg: Double = 0,
        micronutrients: [String: Double] = [:]
    ) {
        self.id = UUID()
        self.date = date
        self.sourceRaw = source.rawValue
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMg = sodiumMg
        self.cholesterolMg = cholesterolMg
        self.micronutrientsData = try? JSONEncoder().encode(micronutrients)
    }
}

struct MicronutrientKeys {
    static let vitaminA = "vitamin_a_mcg"
    static let vitaminC = "vitamin_c_mg"
    static let vitaminD = "vitamin_d_mcg"
    static let vitaminE = "vitamin_e_mg"
    static let vitaminK = "vitamin_k_mcg"
    static let vitaminB6 = "vitamin_b6_mg"
    static let vitaminB12 = "vitamin_b12_mcg"
    static let thiamin = "thiamin_mg"
    static let riboflavin = "riboflavin_mg"
    static let niacin = "niacin_mg"
    static let folate = "folate_mcg"
    static let calcium = "calcium_mg"
    static let iron = "iron_mg"
    static let magnesium = "magnesium_mg"
    static let phosphorus = "phosphorus_mg"
    static let potassium = "potassium_mg"
    static let zinc = "zinc_mg"
    static let selenium = "selenium_mcg"
    static let omega3 = "omega3_g"

    static let allKeys: [(key: String, name: String, unit: String, dailyValue: Double)] = [
        (vitaminA, "Vitamin A", "mcg", 900),
        (vitaminC, "Vitamin C", "mg", 90),
        (vitaminD, "Vitamin D", "mcg", 20),
        (vitaminE, "Vitamin E", "mg", 15),
        (vitaminK, "Vitamin K", "mcg", 120),
        (vitaminB6, "Vitamin B6", "mg", 1.7),
        (vitaminB12, "Vitamin B12", "mcg", 2.4),
        (thiamin, "Thiamin", "mg", 1.2),
        (riboflavin, "Riboflavin", "mg", 1.3),
        (niacin, "Niacin", "mg", 16),
        (folate, "Folate", "mcg", 400),
        (calcium, "Calcium", "mg", 1300),
        (iron, "Iron", "mg", 18),
        (magnesium, "Magnesium", "mg", 420),
        (phosphorus, "Phosphorus", "mg", 1250),
        (potassium, "Potassium", "mg", 4700),
        (zinc, "Zinc", "mg", 11),
        (selenium, "Selenium", "mcg", 55),
        (omega3, "Omega-3", "g", 1.6),
    ]
}
