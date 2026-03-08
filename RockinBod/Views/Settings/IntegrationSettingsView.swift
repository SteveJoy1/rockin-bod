import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct IntegrationSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    var healthKitService: HealthKitService
    var hevyService: HevyService
    var cronometerService: CronometerService
    var renphoService: RenphoService
    var aiCoachService: AICoachService

    // MARK: - Hevy State

    @State private var hevyAPIKey: String = ""
    @State private var hevyImportSinceDate: Date = Calendar.current.date(
        byAdding: .month, value: -1, to: Date()
    ) ?? Date()
    @State private var hevyImportResult: Int?
    @State private var isImportingHevy = false

    // MARK: - Cronometer State

    @State private var showCSVImporter = false
    @State private var cronometerImportResult: Int?
    @State private var isImportingCronometer = false

    // MARK: - General State

    @State private var errorMessage: String?
    @State private var showError = false

    // MARK: - Body

    var body: some View {
        Form {
            appleHealthSection
            hevySection
            cronometerSection
            renphoSection
            aiCoachSection
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSavedKeys()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - Apple Health Section

    private var appleHealthSection: some View {
        Section {
            HStack {
                Label("Apple Health", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                Spacer()
                statusBadge(isConnected: healthKitService.isAuthorized)
            }

            if healthKitService.isAuthorized {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reading data from Apple Health:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Group {
                        healthDataTypeRow("Workouts", icon: "figure.run")
                        healthDataTypeRow("Steps", icon: "figure.walk")
                        healthDataTypeRow("Active Energy", icon: "flame.fill")
                        healthDataTypeRow("Resting Heart Rate", icon: "heart.fill")
                        healthDataTypeRow("Body Measurements", icon: "scalemass.fill")
                        healthDataTypeRow("Nutrition", icon: "fork.knife")
                        healthDataTypeRow("Sleep Analysis", icon: "moon.fill")
                    }
                }
            } else {
                Button {
                    Task {
                        do {
                            try await healthKitService.requestAuthorization()
                        } catch {
                            showError(error.localizedDescription)
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "link.badge.plus")
                        Text("Connect Apple Health")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Apple Health provides workouts, steps, heart rate, body composition, nutrition, and sleep data.")
        }
    }

    private func healthDataTypeRow(_ name: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(name)
                .font(.caption)
        }
    }

    // MARK: - Hevy Section

    private var hevySection: some View {
        Section {
            HStack {
                Label("Hevy", systemImage: "dumbbell.fill")
                    .foregroundStyle(.blue)
                Spacer()
                statusBadge(isConnected: hevyService.isConfigured)
            }

            // Primary: HealthKit sync (recommended)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("Apple Health Sync (Recommended)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text("Hevy automatically syncs your workouts to Apple Health. RockinBod reads this data through Apple Health \u{2014} no setup required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if healthKitService.isAuthorized {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Apple Health connected \u{2014} Hevy workouts sync automatically")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                        Text("Connect Apple Health above to enable automatic sync")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Optional: API key for detailed data
            DisclosureGroup("Advanced: API Key for Detailed Data") {
                Text("The Hevy API provides detailed set-by-set data (reps, weight, RPE) that Apple Health doesn't include. Requires a Hevy Pro subscription.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("Hevy API Key", text: $hevyAPIKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                HStack(spacing: 12) {
                    Button {
                        saveHevyKey()
                    } label: {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Save Key")
                        }
                        .font(.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(hevyAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if hevyService.isConfigured {
                        Button(role: .destructive) {
                            removeHevyKey()
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Remove")
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if hevyService.isConfigured {
                    Divider()

                    DatePicker(
                        "Import since",
                        selection: $hevyImportSinceDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )

                    Button {
                        Task { await importHevyWorkouts() }
                    } label: {
                        HStack {
                            if isImportingHevy {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text(isImportingHevy ? "Importing..." : "Import Workouts")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isImportingHevy)

                    if let result = hevyImportResult {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("\(result) workout\(result == 1 ? "" : "s") imported")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("Hevy")
        } footer: {
            Text("Hevy syncs workout data through Apple Health automatically. For detailed set/rep data, you can optionally connect with an API key (requires Hevy Pro).")
        }
    }

    // MARK: - Cronometer Section

    private var cronometerSection: some View {
        Section {
            HStack {
                Label("Cronometer", systemImage: "fork.knife")
                    .foregroundStyle(.orange)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Cronometer syncs nutrition data through Apple Health. Ensure \"Apple Health\" is enabled in your Cronometer app settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("CSV Import")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("You can also import Cronometer's Daily Nutrition CSV export directly.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showCSVImporter = true
            } label: {
                HStack {
                    if isImportingCronometer {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "doc.badge.plus")
                    }
                    Text(isImportingCronometer ? "Importing..." : "Import CSV File")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isImportingCronometer)
            .fileImporter(
                isPresented: $showCSVImporter,
                allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
                allowsMultipleSelection: false
            ) { result in
                handleCSVImport(result)
            }

            if let result = cronometerImportResult {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(result) day\(result == 1 ? "" : "s") of nutrition imported")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Cronometer")
        } footer: {
            Text("Cronometer provides detailed nutrition tracking including micronutrients.")
        }
    }

    // MARK: - Renpho Section

    private var renphoSection: some View {
        Section {
            HStack {
                Label("Renpho", systemImage: "scalemass.fill")
                    .foregroundStyle(.purple)
                Spacer()
                statusBadge(isConnected: renphoService.isAvailable)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Renpho scale data syncs through Apple Health. Ensure your Renpho app is connected to Apple Health to share weight and body composition data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !healthKitService.isAuthorized {
                Text("Connect Apple Health above to enable Renpho data sync.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Renpho")
        } footer: {
            Text("Renpho smart scales sync weight, body fat percentage, and other body composition metrics through Apple Health.")
        }
    }

    // MARK: - AI Coach Section

    private var aiCoachSection: some View {
        Section {
            HStack {
                Label("AI Coach (Claude)", systemImage: "brain")
                    .foregroundStyle(.green)
                Spacer()
                statusBadge(isConnected: aiCoachService.isConfigured)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("AI coaching is built into RockinBod. The AI Coach can analyze your progress photos, review your weekly data, check your exercise form, and provide personalized coaching advice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("AI Coach")
        } footer: {
            Text("Powered by Claude. No setup required.")
        }
    }

    // MARK: - Helpers

    private func statusBadge(isConnected: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConnected ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 8, height: 8)
            Text(isConnected ? "Connected" : "Not Connected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Key Management

    private func loadSavedKeys() {
        // Pre-populate fields with masked indicators if keys exist.
        // We do not load the actual key values into the text fields for security.
        if hevyService.isConfigured {
            hevyAPIKey = ""
        }
    }

    private func saveHevyKey() {
        let trimmed = hevyAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try KeychainService.save(key: KeychainService.hevyAPIKey, value: trimmed)
            hevyAPIKey = ""
        } catch {
            showError("Failed to save Hevy API key: \(error.localizedDescription)")
        }
    }

    private func removeHevyKey() {
        do {
            try KeychainService.delete(key: KeychainService.hevyAPIKey)
            hevyAPIKey = ""
            hevyImportResult = nil
        } catch {
            showError("Failed to remove Hevy API key: \(error.localizedDescription)")
        }
    }

    // MARK: - Hevy Import

    private func importHevyWorkouts() async {
        isImportingHevy = true
        hevyImportResult = nil
        defer { isImportingHevy = false }

        do {
            let count = try await hevyService.importWorkouts(
                since: hevyImportSinceDate,
                context: modelContext
            )
            hevyImportResult = count
        } catch {
            showError("Hevy import failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Cronometer CSV Import

    private func handleCSVImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                isImportingCronometer = true
                cronometerImportResult = nil
                defer { isImportingCronometer = false }

                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        showError("Unable to access the selected file.")
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    let data = try Data(contentsOf: url)
                    let count = try await cronometerService.importFromCSV(
                        data: data,
                        context: modelContext
                    )
                    cronometerImportResult = count
                } catch {
                    showError("CSV import failed: \(error.localizedDescription)")
                }
            }

        case .failure(let error):
            showError("File selection failed: \(error.localizedDescription)")
        }
    }

}

#Preview {
    let healthKit = HealthKitService()
    NavigationStack {
        IntegrationSettingsView(
            healthKitService: healthKit,
            hevyService: HevyService(),
            cronometerService: CronometerService(),
            renphoService: RenphoService(healthKitService: healthKit),
            aiCoachService: AICoachService()
        )
    }
    .modelContainer(for: [
        UserProfile.self,
        WorkoutSession.self,
        NutritionEntry.self,
        BodyMeasurement.self,
    ])
}
