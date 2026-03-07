import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var id: UUID
    var exerciseName: String
    var setNumber: Int
    var reps: Int?
    var weightKg: Double?
    var durationSeconds: Double?
    var distanceMeters: Double?
    var rpe: Double?
    var isWarmup: Bool
    @Relationship var workoutSession: WorkoutSession?

    var weightLbs: Double? {
        guard let kg = weightKg else { return nil }
        return kg * 2.20462
    }

    init(
        exerciseName: String = "",
        setNumber: Int = 1,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSeconds: Double? = nil,
        distanceMeters: Double? = nil,
        rpe: Double? = nil,
        isWarmup: Bool = false
    ) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.durationSeconds = durationSeconds
        self.distanceMeters = distanceMeters
        self.rpe = rpe
        self.isWarmup = isWarmup
    }
}
