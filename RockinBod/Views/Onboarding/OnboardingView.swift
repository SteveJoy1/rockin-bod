import SwiftUI
import SwiftData

// MARK: - Onboarding Step

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case profile = 1
    case macros = 2
    case services = 3
    case ready = 4

    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .profile: return "Profile"
        case .macros: return "Nutrition"
        case .services: return "Connect"
        case .ready: return "Ready"
        }
    }
}

// MARK: - Height Unit

private enum HeightUnit: String, CaseIterable {
    case cm = "cm"
    case ftIn = "ft/in"
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    var healthKitService: HealthKitService

    // MARK: - Navigation State

    @State private var currentStep: OnboardingStep = .welcome

    // MARK: - Profile State

    @State private var name: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var hasBirthDate: Bool = false
    @State private var heightInCm: Double = 175
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 9
    @State private var heightUnit: HeightUnit = .cm
    @State private var selectedGoal: FitnessGoal = .recomposition

    // MARK: - Macro State

    @State private var targetCalories: Int = 2200
    @State private var targetProtein: Int = 180
    @State private var targetCarbs: Int = 220
    @State private var targetFat: Int = 73
    @State private var targetFiber: Int = 30

    // MARK: - Services State

    @State private var healthKitConnected: Bool = false
    @State private var healthKitError: String?
    @State private var hevyAPIKey: String = ""
    @State private var claudeAPIKey: String = ""
    @State private var isConnectingHealthKit: Bool = false

    // MARK: - Completion

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if currentStep != .welcome {
                stepIndicator
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            TabView(selection: $currentStep) {
                welcomeStep
                    .tag(OnboardingStep.welcome)
                profileStep
                    .tag(OnboardingStep.profile)
                macrosStep
                    .tag(OnboardingStep.macros)
                servicesStep
                    .tag(OnboardingStep.services)
                readyStep
                    .tag(OnboardingStep.ready)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                if step != .welcome {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)

                        Text(step.title)
                            .font(.caption2)
                            .foregroundStyle(step.rawValue <= currentStep.rawValue ? .primary : .secondary)
                    }

                    if step != .ready {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .offset(y: -6)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 12) {
                Text("RockinBod")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your AI-powered fitness coach")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                featureBullet(icon: "chart.line.uptrend.xyaxis", text: "Track workouts, nutrition, and body metrics")
                featureBullet(icon: "brain", text: "AI coaching and weekly progress reviews")
                featureBullet(icon: "heart.fill", text: "Apple Health and third-party integrations")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { currentStep = .profile }
            } label: {
                Text("Get Started")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func featureBullet(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Step 2: Profile Setup

    private var profileStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                sectionHeader(title: "Profile Setup", subtitle: "Tell us about yourself to personalize your experience.")

                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Height
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Height")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("Unit", selection: $heightUnit) {
                            ForEach(HeightUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }

                    if heightUnit == .cm {
                        HStack {
                            TextField("Height", value: $heightInCm, format: .number)
                                .keyboardType(.decimalPad)
                                .padding(12)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text("cm")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 12) {
                            HStack {
                                TextField("Feet", value: $heightFeet, format: .number)
                                    .keyboardType(.numberPad)
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text("ft")
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                TextField("Inches", value: $heightInches, format: .number)
                                    .keyboardType(.numberPad)
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text("in")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Birth Date
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Birth Date (optional)", isOn: $hasBirthDate)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if hasBirthDate {
                        DatePicker(
                            "Birth Date",
                            selection: $birthDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxHeight: 150)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Fitness Goal
                VStack(alignment: .leading, spacing: 10) {
                    Text("Fitness Goal")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(FitnessGoal.allCases, id: \.self) { goal in
                        goalCard(goal: goal)
                    }
                }

                // Navigation
                HStack(spacing: 16) {
                    Button {
                        withAnimation { currentStep = .welcome }
                    } label: {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        syncHeightToMetric()
                        prefillMacros(for: selectedGoal)
                        withAnimation { currentStep = .macros }
                    } label: {
                        Text("Next")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func goalCard(goal: FitnessGoal) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedGoal = goal }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: goalIcon(for: goal))
                    .font(.title2)
                    .foregroundStyle(selectedGoal == goal ? .white : .accentColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(selectedGoal == goal ? .white : .primary)

                    Text(goalDescription(for: goal))
                        .font(.caption)
                        .foregroundStyle(selectedGoal == goal ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                if selectedGoal == goal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding(14)
            .background(selectedGoal == goal ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func goalIcon(for goal: FitnessGoal) -> String {
        switch goal {
        case .loseFat: return "flame.fill"
        case .buildMuscle: return "dumbbell.fill"
        case .recomposition: return "arrow.triangle.2.circlepath"
        case .maintain: return "equal.circle.fill"
        case .improveEndurance: return "figure.run"
        }
    }

    private func goalDescription(for goal: FitnessGoal) -> String {
        switch goal {
        case .loseFat: return "Reduce body fat while preserving muscle mass"
        case .buildMuscle: return "Maximize muscle growth with a caloric surplus"
        case .recomposition: return "Build muscle and lose fat simultaneously"
        case .maintain: return "Maintain current weight and body composition"
        case .improveEndurance: return "Boost cardiovascular fitness and stamina"
        }
    }

    // MARK: - Step 3: Macro Targets

    private var macrosStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                sectionHeader(
                    title: "Daily Macro Targets",
                    subtitle: "We've pre-filled targets based on your goal. Adjust them to fit your needs."
                )

                macroInputCard(
                    label: "Calories",
                    value: $targetCalories,
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange,
                    description: "Total daily energy intake"
                )

                macroInputCard(
                    label: "Protein",
                    value: $targetProtein,
                    unit: "g",
                    icon: "fish.fill",
                    color: .red,
                    description: "Essential for muscle repair and growth"
                )

                macroInputCard(
                    label: "Carbohydrates",
                    value: $targetCarbs,
                    unit: "g",
                    icon: "leaf.fill",
                    color: .green,
                    description: "Primary fuel source for training"
                )

                macroInputCard(
                    label: "Fat",
                    value: $targetFat,
                    unit: "g",
                    icon: "drop.fill",
                    color: .yellow,
                    description: "Supports hormones and nutrient absorption"
                )

                macroInputCard(
                    label: "Fiber",
                    value: $targetFiber,
                    unit: "g",
                    icon: "circle.grid.cross.fill",
                    color: .brown,
                    description: "Supports digestion and gut health"
                )

                // Calorie breakdown summary
                calorieBreakdown

                // Navigation
                HStack(spacing: 16) {
                    Button {
                        withAnimation { currentStep = .profile }
                    } label: {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        withAnimation { currentStep = .services }
                    } label: {
                        Text("Next")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func macroInputCard(
        label: String,
        value: Binding<Int>,
        unit: String,
        icon: String,
        color: Color,
        description: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                HStack(spacing: 4) {
                    TextField("", value: value, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .leading)
                }
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var calorieBreakdown: some View {
        let proteinCals = targetProtein * 4
        let carbsCals = targetCarbs * 4
        let fatCals = targetFat * 9
        let totalMacroCals = proteinCals + carbsCals + fatCals

        return VStack(spacing: 8) {
            Text("Macro Calorie Breakdown")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                macroCaloriePill(label: "P", calories: proteinCals, color: .red)
                macroCaloriePill(label: "C", calories: carbsCals, color: .green)
                macroCaloriePill(label: "F", calories: fatCals, color: .yellow)
            }

            if totalMacroCals != targetCalories {
                Text("Macro total: \(totalMacroCals) kcal (target: \(targetCalories) kcal)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func macroCaloriePill(label: String, calories: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label): \(calories) kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Step 4: Connect Services

    private var servicesStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                sectionHeader(
                    title: "Connect Services",
                    subtitle: "Link your fitness apps for automatic data syncing."
                )

                // Apple Health
                serviceCard(
                    icon: "heart.fill",
                    iconColor: .red,
                    title: "Apple Health",
                    description: "Sync workouts, body measurements, nutrition, and sleep data.",
                    isRequired: false
                ) {
                    if healthKitConnected || healthKitService.isAuthorized {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            connectHealthKit()
                        } label: {
                            HStack(spacing: 6) {
                                if isConnectingHealthKit {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "link")
                                }
                                Text("Connect")
                            }
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isConnectingHealthKit)
                    }
                }

                if let error = healthKitError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }

                // Hevy API Key
                serviceCard(
                    icon: "dumbbell.fill",
                    iconColor: .blue,
                    title: "Hevy",
                    description: "Import your workout history and exercise data. Requires an API key from your Hevy account.",
                    isRequired: false
                ) {
                    EmptyView()
                }

                apiKeyInput(
                    placeholder: "Hevy API Key (optional)",
                    value: $hevyAPIKey
                )

                // Claude API Key
                serviceCard(
                    icon: "brain",
                    iconColor: .purple,
                    title: "Claude AI Coach",
                    description: "Get personalized coaching advice, weekly reviews, and form analysis powered by Claude.",
                    isRequired: false
                ) {
                    EmptyView()
                }

                apiKeyInput(
                    placeholder: "Anthropic API Key (optional)",
                    value: $claudeAPIKey
                )

                Text("API keys are stored securely in your device's Keychain. You can add or update these later in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                // Navigation
                HStack(spacing: 16) {
                    Button {
                        withAnimation { currentStep = .macros }
                    } label: {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        saveAPIKeys()
                        withAnimation { currentStep = .ready }
                    } label: {
                        Text("Next")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func serviceCard<ActionContent: View>(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isRequired: Bool,
        @ViewBuilder action: () -> ActionContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if !isRequired {
                            Text("Optional")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                action()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func apiKeyInput(placeholder: String, value: Binding<String>) -> some View {
        SecureField(placeholder, text: value)
            .textContentType(.password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 4)
    }

    // MARK: - Step 5: Ready

    private var readyStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Here's a summary of your setup:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Summary Cards
                VStack(spacing: 12) {
                    summaryRow(icon: "person.fill", label: "Name", value: name.isEmpty ? "Not set" : name)
                    summaryRow(icon: "ruler", label: "Height", value: formattedHeight)
                    summaryRow(icon: "target", label: "Goal", value: selectedGoal.displayName)
                    summaryRow(icon: "flame.fill", label: "Calories", value: "\(targetCalories) kcal")
                    summaryRow(
                        icon: "chart.bar.fill",
                        label: "Macros",
                        value: "\(targetProtein)g P / \(targetCarbs)g C / \(targetFat)g F"
                    )
                    summaryRow(
                        icon: "heart.fill",
                        label: "Apple Health",
                        value: (healthKitConnected || healthKitService.isAuthorized) ? "Connected" : "Not connected"
                    )
                    summaryRow(
                        icon: "dumbbell.fill",
                        label: "Hevy",
                        value: hevyAPIKey.isEmpty ? "Not configured" : "Configured"
                    )
                    summaryRow(
                        icon: "brain",
                        label: "AI Coach",
                        value: claudeAPIKey.isEmpty ? "Not configured" : "Configured"
                    )
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("You can change any of these settings later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Navigation
                HStack(spacing: 16) {
                    Button {
                        withAnimation { currentStep = .services }
                    } label: {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        completeOnboarding()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "figure.strengthtraining.traditional")
                            Text("Start Training")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)

                Spacer(minLength: 32)
            }
            .padding(24)
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Computed Properties

    private var formattedHeight: String {
        if heightUnit == .ftIn {
            return "\(heightFeet)'\(heightInches)\""
        } else {
            return "\(Int(heightInCm)) cm"
        }
    }

    // MARK: - Actions

    private func syncHeightToMetric() {
        if heightUnit == .ftIn {
            let totalInches = Double(heightFeet * 12 + heightInches)
            heightInCm = totalInches * 2.54
        }
    }

    private func prefillMacros(for goal: FitnessGoal) {
        switch goal {
        case .loseFat:
            targetCalories = 1800
            targetProtein = 180
            targetCarbs = 150
            targetFat = 60
        case .buildMuscle:
            targetCalories = 2800
            targetProtein = 200
            targetCarbs = 300
            targetFat = 80
        case .recomposition:
            targetCalories = 2200
            targetProtein = 180
            targetCarbs = 220
            targetFat = 73
        case .maintain:
            targetCalories = 2400
            targetProtein = 160
            targetCarbs = 250
            targetFat = 80
        case .improveEndurance:
            targetCalories = 2600
            targetProtein = 150
            targetCarbs = 325
            targetFat = 72
        }
        targetFiber = 30
    }

    private func connectHealthKit() {
        isConnectingHealthKit = true
        healthKitError = nil
        Task {
            do {
                try await healthKitService.requestAuthorization()
                await MainActor.run {
                    healthKitConnected = true
                    isConnectingHealthKit = false
                }
            } catch {
                await MainActor.run {
                    healthKitError = error.localizedDescription
                    isConnectingHealthKit = false
                }
            }
        }
    }

    private func saveAPIKeys() {
        if !hevyAPIKey.isEmpty {
            try? KeychainService.save(key: KeychainService.hevyAPIKey, value: hevyAPIKey)
        }
        if !claudeAPIKey.isEmpty {
            try? KeychainService.save(key: KeychainService.anthropicAPIKey, value: claudeAPIKey)
        }
    }

    private func completeOnboarding() {
        syncHeightToMetric()

        let profile = UserProfile(
            name: name,
            birthDate: hasBirthDate ? birthDate : nil,
            heightInCm: heightInCm,
            goal: selectedGoal,
            targetCalories: targetCalories,
            targetProteinGrams: targetProtein,
            targetCarbsGrams: targetCarbs,
            targetFatGrams: targetFat,
            targetFiberGrams: targetFiber,
            weeklyReviewDay: 0
        )
        modelContext.insert(profile)
        try? modelContext.save()

        saveAPIKeys()

        hasCompletedOnboarding = true
    }
}

// MARK: - Preview

#Preview {
    OnboardingView(healthKitService: HealthKitService())
        .modelContainer(for: UserProfile.self, inMemory: true)
}
