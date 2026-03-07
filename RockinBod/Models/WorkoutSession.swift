import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var id: UUID
    var date: Date
    var endDate: Date?
    var name: String
    var workoutTypeRaw: String
    var durationMinutes: Double
    var caloriesBurned: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var sourceRaw: String
    var notes: String?
    @Relationship(deleteRule: .cascade) var exercises: [ExerciseSet]

    var workoutType: WorkoutType {
        get { WorkoutType(rawValue: workoutTypeRaw) ?? .strength }
        set { workoutTypeRaw = newValue.rawValue }
    }

    var source: DataSource {
        get { DataSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        date: Date = Date(),
        endDate: Date? = nil,
        name: String = "",
        workoutType: WorkoutType = .strength,
        durationMinutes: Double = 0,
        caloriesBurned: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        source: DataSource = .manual,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.endDate = endDate
        self.name = name
        self.workoutTypeRaw = workoutType.rawValue
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.sourceRaw = source.rawValue
        self.notes = notes
        self.exercises = []
    }
}

enum WorkoutType: String, CaseIterable, Codable {
    case strength = "strength"
    case cardio = "cardio"
    case hiit = "hiit"
    case flexibility = "flexibility"
    case sports = "sports"
    case walking = "walking"
    case running = "running"
    case cycling = "cycling"
    case swimming = "swimming"
    case other = "other"

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .cardio: return "Cardio"
        case .hiit: return "HIIT"
        case .flexibility: return "Flexibility"
        case .sports: return "Sports"
        case .walking: return "Walking"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio: return "heart.fill"
        case .hiit: return "bolt.heart.fill"
        case .flexibility: return "figure.flexibility"
        case .sports: return "sportscourt.fill"
        case .walking: return "figure.walk"
        case .running: return "figure.run"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .other: return "figure.mixed.cardio"
        }
    }
}

enum DataSource: String, CaseIterable, Codable {
    case healthKit = "healthkit"
    case hevy = "hevy"
    case cronometer = "cronometer"
    case renpho = "renpho"
    case manual = "manual"

    var displayName: String {
        switch self {
        case .healthKit: return "Apple Health"
        case .hevy: return "Hevy"
        case .cronometer: return "Cronometer"
        case .renpho: return "Renpho"
        case .manual: return "Manual"
        }
    }
}
