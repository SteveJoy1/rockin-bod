import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    var id: UUID
    var date: Date
    var sourceRaw: String
    var weightKg: Double?
    var bodyFatPercentage: Double?
    var muscleMassKg: Double?
    var bmi: Double?
    var boneMassKg: Double?
    var waterPercentage: Double?
    var visceralFat: Double?
    var metabolicAge: Int?
    var basalMetabolicRate: Double?
    // Optional tape measurements
    var chestCm: Double?
    var waistCm: Double?
    var hipsCm: Double?
    var leftArmCm: Double?
    var rightArmCm: Double?
    var leftThighCm: Double?
    var rightThighCm: Double?

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var weightLbs: Double? {
        guard let kg = weightKg else { return nil }
        return kg * 2.20462
    }

    init(
        date: Date = Date(),
        source: DataSource = .manual,
        weightKg: Double? = nil,
        bodyFatPercentage: Double? = nil,
        muscleMassKg: Double? = nil,
        bmi: Double? = nil,
        boneMassKg: Double? = nil,
        waterPercentage: Double? = nil,
        visceralFat: Double? = nil,
        metabolicAge: Int? = nil,
        basalMetabolicRate: Double? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.sourceRaw = source.rawValue
        self.weightKg = weightKg
        self.bodyFatPercentage = bodyFatPercentage
        self.muscleMassKg = muscleMassKg
        self.bmi = bmi
        self.boneMassKg = boneMassKg
        self.waterPercentage = waterPercentage
        self.visceralFat = visceralFat
        self.metabolicAge = metabolicAge
        self.basalMetabolicRate = basalMetabolicRate
    }
}
