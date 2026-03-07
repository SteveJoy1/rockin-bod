import SwiftUI
import SwiftData

@main
struct RockinBodApp: App {
    let modelContainer: ModelContainer

    @State private var healthKitService = HealthKitService()
    @State private var hevyService = HevyService()
    @State private var cronometerService = CronometerService()
    @State private var renphoService: RenphoService
    @State private var aiCoachService = AICoachService()
    @State private var dataService: DataAggregationService

    init() {
        do {
            let schema = Schema([
                UserProfile.self,
                WorkoutSession.self,
                ExerciseSet.self,
                NutritionEntry.self,
                BodyMeasurement.self,
                ProgressPhoto.self,
                FormCheckResult.self,
                WeeklyReport.self,
                CoachMessage.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        let hk = HealthKitService()
        _healthKitService = State(initialValue: hk)
        _renphoService = State(initialValue: RenphoService(healthKitService: hk))
        _dataService = State(initialValue: DataAggregationService(healthKitService: hk))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                healthKitService: healthKitService,
                hevyService: hevyService,
                cronometerService: cronometerService,
                renphoService: renphoService,
                aiCoachService: aiCoachService,
                dataService: dataService
            )
        }
        .modelContainer(modelContainer)
    }
}
