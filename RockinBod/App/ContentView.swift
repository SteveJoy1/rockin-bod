import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    let healthKitService: HealthKitService
    let hevyService: HevyService
    let cronometerService: CronometerService
    let renphoService: RenphoService
    let aiCoachService: AICoachService
    let dataService: DataAggregationService

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView(
                healthKitService: healthKitService,
                hevyService: hevyService,
                cronometerService: cronometerService,
                renphoService: renphoService,
                aiCoachService: aiCoachService,
                dataService: dataService
            )
        } else {
            OnboardingView(healthKitService: healthKitService)
        }
    }
}

struct MainTabView: View {
    let healthKitService: HealthKitService
    let hevyService: HevyService
    let cronometerService: CronometerService
    let renphoService: RenphoService
    let aiCoachService: AICoachService
    let dataService: DataAggregationService

    @State private var showSettings = false

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView(
                    healthKitService: healthKitService,
                    dataService: dataService
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        settingsButton
                    }
                }
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar.fill")
            }

            NavigationStack {
                NutritionView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            settingsButton
                        }
                    }
            }
            .tabItem {
                Label("Nutrition", systemImage: "fork.knife")
            }

            NavigationStack {
                WorkoutsView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            settingsButton
                        }
                    }
            }
            .tabItem {
                Label("Workouts", systemImage: "dumbbell.fill")
            }

            NavigationStack {
                ProgressTrackingView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            settingsButton
                        }
                    }
            }
            .tabItem {
                Label("Progress", systemImage: "camera.fill")
            }

            NavigationStack {
                CoachView(
                    aiCoachService: aiCoachService,
                    dataService: dataService
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        settingsButton
                    }
                }
            }
            .tabItem {
                Label("Coach", systemImage: "brain.head.profile")
            }
        }
        .tint(.accentColor)
        .sheet(isPresented: $showSettings) {
            SettingsView(
                healthKitService: healthKitService,
                hevyService: hevyService,
                cronometerService: cronometerService,
                renphoService: renphoService,
                aiCoachService: aiCoachService,
                dataService: dataService
            )
        }
        .task {
            if HealthKitService.isAvailable && !healthKitService.isAuthorized {
                try? await healthKitService.requestAuthorization()
            }
        }
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
    }
}
