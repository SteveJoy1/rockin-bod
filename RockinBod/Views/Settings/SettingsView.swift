import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]

    var healthKitService: HealthKitService
    var hevyService: HevyService
    var cronometerService: CronometerService
    var renphoService: RenphoService
    var aiCoachService: AICoachService
    var dataService: DataAggregationService

    // MARK: - Profile Form State

    @State private var name: String = ""
    @State private var birthDate: Date = Date()
    @State private var hasBirthDate: Bool = false
    @State private var heightInCm: Double = 175
    @State private var selectedGoal: FitnessGoal = .recomposition
    @State private var targetCalories: Int = 2200
    @State private var targetProtein: Int = 160
    @State private var targetCarbs: Int = 220
    @State private var targetFat: Int = 73
    @State private var targetFiber: Int = 30
    @State private var weeklyReviewDay: Int = 0

    // MARK: - UI State

    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var showClearDataAlert = false
    @State private var profileSaved = false
    @State private var hasLoadedProfile = false
    @State private var cronometerHasSync = false

    // MARK: - Units & Notifications State

    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("dailyReminderEnabled") private var dailyReminderEnabled = true
    @AppStorage("weeklyReviewReminder") private var weeklyReviewReminder = true

    private var userProfile: UserProfile? { userProfiles.first }

    private var hasProfile: Bool { userProfile != nil }

    private static let dayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday",
        "Thursday", "Friday", "Saturday",
    ]

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if hasProfile || hasLoadedProfile {
                    settingsForm
                } else {
                    setupPrompt
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if !hasLoadedProfile {
                    loadProfileData()
                    hasLoadedProfile = true
                }
            }
            .task {
                cronometerHasSync = await cronometerService.hasHealthKitNutritionSync
            }
        }
    }

    // MARK: - Setup Prompt

    private var setupPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Set Up Your Profile")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create your profile to personalize your fitness tracking experience and set your nutrition targets.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                createNewProfile()
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 48)

            Spacer()
        }
    }

    // MARK: - Settings Form

    private var settingsForm: some View {
        Form {
            profileSection
            macroTargetsSection
            unitsSection
            notificationsSection
            integrationsSection
            dataManagementSection
            aboutSection
        }
        .overlay {
            if profileSaved {
                savedBanner
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section("Profile") {
            TextField("Name", text: $name)
                .textContentType(.name)
                .autocorrectionDisabled()

            HStack {
                Text("Height")
                Spacer()
                TextField("cm", value: $heightInCm, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("cm")
                    .foregroundStyle(.secondary)
            }

            Toggle("Birth Date", isOn: $hasBirthDate)

            if hasBirthDate {
                DatePicker(
                    "Birth Date",
                    selection: $birthDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
            }

            Picker("Fitness Goal", selection: $selectedGoal) {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    Text(goal.displayName).tag(goal)
                }
            }

            Picker("Weekly Review Day", selection: $weeklyReviewDay) {
                ForEach(0..<7, id: \.self) { day in
                    Text(Self.dayNames[day]).tag(day)
                }
            }

            Button {
                saveProfile()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Save Profile")
                }
            }
        }
    }

    // MARK: - Macro Targets Section

    private var macroTargetsSection: some View {
        Section("Daily Macro Targets") {
            macroField(label: "Calories", value: $targetCalories, unit: "kcal")
            macroField(label: "Protein", value: $targetProtein, unit: "g")
            macroField(label: "Carbs", value: $targetCarbs, unit: "g")
            macroField(label: "Fat", value: $targetFat, unit: "g")
            macroField(label: "Fiber", value: $targetFiber, unit: "g")
        }
    }

    private func macroField(label: String, value: Binding<Int>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }

    // MARK: - Units Section

    private var unitsSection: some View {
        Section("Units") {
            Picker("Weight & Body", selection: $useMetricUnits) {
                Text("Metric (kg, cm)").tag(true)
                Text("Imperial (lbs, in)").tag(false)
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications", isOn: $notificationsEnabled)

            if notificationsEnabled {
                Toggle("Daily Logging Reminder", isOn: $dailyReminderEnabled)
                Toggle("Weekly Review Reminder", isOn: $weeklyReviewReminder)
            }
        }
    }

    // MARK: - Integrations Section

    private var integrationsSection: some View {
        Section("Integrations") {
            NavigationLink {
                IntegrationSettingsView(
                    healthKitService: healthKitService,
                    hevyService: hevyService,
                    cronometerService: cronometerService,
                    renphoService: renphoService,
                    aiCoachService: aiCoachService
                )
            } label: {
                HStack {
                    Image(systemName: "link")
                    Text("Manage Integrations")
                    Spacer()
                }
            }

            integrationStatusRow(
                name: "Apple Health",
                icon: "heart.fill",
                color: .red,
                isConnected: healthKitService.isAuthorized
            )
            integrationStatusRow(
                name: "Hevy",
                icon: "dumbbell.fill",
                color: .blue,
                isConnected: healthKitService.isAuthorized || hevyService.isConfigured
            )
            integrationStatusRow(
                name: "Cronometer",
                icon: "fork.knife",
                color: .orange,
                isConnected: cronometerHasSync
            )
            integrationStatusRow(
                name: "Renpho",
                icon: "scalemass.fill",
                color: .purple,
                isConnected: renphoService.isAvailable
            )
            integrationStatusRow(
                name: "AI Coach (Claude)",
                icon: "brain",
                color: .green,
                isConnected: aiCoachService.isConfigured
            )
        }
    }

    private func integrationStatusRow(
        name: String,
        icon: String,
        color: Color,
        isConnected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(name)
                .font(.subheadline)

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(isConnected ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(isConnected ? "Connected" : "Not Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Data Management Section

    private var dataManagementSection: some View {
        Section("Data Management") {
            Button {
                Task { await syncAllData() }
            } label: {
                HStack {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(isSyncing ? "Syncing..." : "Sync Now")
                }
            }
            .disabled(isSyncing)

            Button {
                exportData()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Data")
                }
            }

            Button(role: .destructive) {
                showClearDataAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Data")
                }
            }
            .alert("Clear All Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All Data", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all workouts, nutrition entries, body measurements, progress photos, and coaching data. Your profile settings will be preserved. This action cannot be undone.")
            }
        }
        .alert("Sync Error", isPresented: .init(
            get: { syncError != nil },
            set: { if !$0 { syncError = nil } }
        )) {
            Button("OK", role: .cancel) { syncError = nil }
        } message: {
            Text(syncError ?? "An unknown error occurred.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://rockinbod.com/privacy")!) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Link(destination: URL(string: "mailto:feedback@rockinbod.com")!) {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Send Feedback")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Saved Banner

    private var savedBanner: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Profile saved")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 4)
            .padding(.bottom, 32)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: profileSaved)
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func loadProfileData() {
        guard let profile = userProfile else { return }
        name = profile.name
        heightInCm = profile.heightInCm
        selectedGoal = profile.goal
        targetCalories = profile.targetCalories
        targetProtein = profile.targetProteinGrams
        targetCarbs = profile.targetCarbsGrams
        targetFat = profile.targetFatGrams
        targetFiber = profile.targetFiberGrams
        weeklyReviewDay = profile.weeklyReviewDay

        if let bd = profile.birthDate {
            birthDate = bd
            hasBirthDate = true
        } else {
            hasBirthDate = false
        }
    }

    private func createNewProfile() {
        let profile = UserProfile()
        modelContext.insert(profile)
        try? modelContext.save()
        loadProfileData()
        hasLoadedProfile = true
    }

    private func saveProfile() {
        if let profile = userProfile {
            profile.name = name
            profile.heightInCm = heightInCm
            profile.birthDate = hasBirthDate ? birthDate : nil
            profile.goal = selectedGoal
            profile.targetCalories = targetCalories
            profile.targetProteinGrams = targetProtein
            profile.targetCarbsGrams = targetCarbs
            profile.targetFatGrams = targetFat
            profile.targetFiberGrams = targetFiber
            profile.weeklyReviewDay = weeklyReviewDay
            profile.updatedAt = Date()

            try? modelContext.save()

            withAnimation {
                profileSaved = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    profileSaved = false
                }
            }
        }
    }

    private func syncAllData() async {
        isSyncing = true
        defer { isSyncing = false }

        do {
            // Ensure HealthKit authorization
            if !healthKitService.isAuthorized {
                try await healthKitService.requestAuthorization()
            }

            let calendar = Calendar.current
            let today = Date()
            guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today) else { return }

            // Sync HealthKit data (covers Apple Health, Renpho, Cronometer via Health)
            try await dataService.syncHealthKitData(from: twoWeeksAgo, to: today, context: modelContext)

            // Sync Hevy workouts if configured
            if hevyService.isConfigured {
                _ = try await hevyService.importWorkouts(since: twoWeeksAgo, context: modelContext)
            }
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func exportData() {
        // Export is a placeholder for future implementation.
        // This would typically create a JSON/CSV export and present a share sheet.
    }

    private func clearAllData() {
        do {
            try modelContext.delete(model: WorkoutSession.self)
            try modelContext.delete(model: NutritionEntry.self)
            try modelContext.delete(model: BodyMeasurement.self)
            try modelContext.delete(model: ProgressPhoto.self)
            try modelContext.delete(model: FormCheckResult.self)
            try modelContext.delete(model: WeeklyReport.self)
            try modelContext.delete(model: CoachMessage.self)
            try modelContext.save()
        } catch {
            syncError = "Failed to clear data: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let healthKit = HealthKitService()
    SettingsView(
        healthKitService: healthKit,
        hevyService: HevyService(),
        cronometerService: CronometerService(),
        renphoService: RenphoService(healthKitService: healthKit),
        aiCoachService: AICoachService(),
        dataService: DataAggregationService(healthKitService: healthKit)
    )
    .modelContainer(for: [
        UserProfile.self,
        WorkoutSession.self,
        NutritionEntry.self,
        BodyMeasurement.self,
        ProgressPhoto.self,
        FormCheckResult.self,
        WeeklyReport.self,
        CoachMessage.self,
    ])
}
