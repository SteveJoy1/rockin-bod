import SwiftUI
import SwiftData

struct CoachView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CoachMessage.date, order: .forward) private var messages: [CoachMessage]
    @Query private var userProfiles: [UserProfile]

    var aiCoachService: AICoachService
    var dataService: DataAggregationService

    enum CoachTab: String, CaseIterable {
        case chat = "Chat"
        case weeklyReview = "Weekly Review"
        case formCheck = "Form Check"
    }

    @State private var selectedTab: CoachTab = .chat
    @State private var messageText = ""
    @State private var showWeeklyReview = false
    @State private var showFormCheck = false
    @State private var errorMessage: String?
    @State private var scrollTarget: UUID?

    private var userProfile: UserProfile? { userProfiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker
                Picker("Section", selection: $selectedTab) {
                    ForEach(CoachTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Tab content
                switch selectedTab {
                case .chat:
                    chatSection
                case .weeklyReview:
                    weeklyReviewSection
                case .formCheck:
                    formCheckSection
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .sheet(isPresented: $showWeeklyReview) {
                WeeklyReviewView(
                    aiCoachService: aiCoachService,
                    dataService: dataService
                )
            }
            .sheet(isPresented: $showFormCheck) {
                FormCheckView(aiCoachService: aiCoachService)
            }
        }
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(spacing: 0) {
            // Message list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            emptyStateView
                        }

                        ForEach(messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }

                        if aiCoachService.isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .id("loading")
                        }
                    }
                    .padding()
                }
                .onChange(of: scrollTarget) { _, newValue in
                    if let target = newValue {
                        withAnimation {
                            proxy.scrollTo(target, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: aiCoachService.isLoading) { _, isLoading in
                    if isLoading {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input area
            chatInputBar
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Ask Your Coach")
                .font(.headline)

            Text("Get personalized advice on training, nutrition, recovery, and more.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }

    private var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask your coach...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiCoachService.isLoading)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Weekly Review Section

    private var weeklyReviewSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Weekly Review")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Get a comprehensive AI-powered analysis of your training, nutrition, and body composition progress from the past week.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    featureRow(icon: "camera.fill", text: "Take progress photos")
                    featureRow(icon: "chart.xyaxis.line", text: "Review aggregated weekly data")
                    featureRow(icon: "brain", text: "AI-generated coaching feedback")
                    featureRow(icon: "list.bullet.clipboard", text: "Actionable recommendations")
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

                Button {
                    showWeeklyReview = true
                } label: {
                    Label("Start Weekly Review", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!aiCoachService.isConfigured)

                if !aiCoachService.isConfigured {
                    Label("Configure your API key in Settings to use AI features.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
        }
    }

    // MARK: - Form Check Section

    private var formCheckSection: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Form Check")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Record or select a video of your exercise and get AI-powered form analysis with detailed feedback on your technique.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    featureRow(icon: "video.fill", text: "Select or record exercise video")
                    featureRow(icon: "eye.fill", text: "AI analyzes movement frame by frame")
                    featureRow(icon: "checkmark.circle.fill", text: "Get rated on overall form quality")
                    featureRow(icon: "lightbulb.fill", text: "Receive specific improvement tips")
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

                Button {
                    showFormCheck = true
                } label: {
                    Label("Start Form Check", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!aiCoachService.isConfigured)

                if !aiCoachService.isConfigured {
                    Label("Configure your API key in Settings to use AI features.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        // Save user message
        let userMessage = CoachMessage(role: .user, content: trimmedText)
        modelContext.insert(userMessage)
        try? modelContext.save()
        messageText = ""
        scrollTarget = userMessage.id

        // Build context and send to AI
        Task {
            do {
                let context = await buildUserContext()

                // Build message history (recent messages for multi-turn conversation)
                let recentMessages = Array(messages.suffix(20))
                var chatHistory: [(role: String, content: String)] = recentMessages.map {
                    (role: $0.roleRaw, content: $0.content)
                }
                // Append the new user message since @Query may not have updated yet
                chatHistory.append((role: "user", content: trimmedText))

                let response = try await aiCoachService.chat(
                    messages: chatHistory,
                    userContext: context
                )

                let assistantMessage = CoachMessage(
                    role: .assistant,
                    content: response,
                    contextSummary: context
                )
                modelContext.insert(assistantMessage)
                try? modelContext.save()
                scrollTarget = assistantMessage.id
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func buildUserContext() async -> String {
        var lines: [String] = []

        if let profile = userProfile {
            lines.append("User: \(profile.name)")
            lines.append("Goal: \(profile.goal.displayName)")
            lines.append("Target calories: \(profile.targetCalories) kcal")
            lines.append("Target macros: P\(profile.targetProteinGrams)g / C\(profile.targetCarbsGrams)g / F\(profile.targetFatGrams)g")
        }

        // Try to fetch recent data summary
        do {
            let weeklySnapshot = try await dataService.buildWeeklySnapshot(
                weekOf: Date(),
                context: modelContext
            )
            lines.append("This week: \(weeklySnapshot.totalWorkouts) workouts, \(Int(weeklySnapshot.totalWorkoutMinutes)) min total")
            if weeklySnapshot.averageCalories > 0 {
                lines.append("Avg daily: \(Int(weeklySnapshot.averageCalories)) cal, \(Int(weeklySnapshot.averageProtein))g protein, \(Int(weeklySnapshot.averageCarbs))g carbs, \(Int(weeklySnapshot.averageFat))g fat")
            }
            if let currentWeight = weeklySnapshot.weightTrend.end {
                lines.append("Current weight: \(String(format: "%.1f", currentWeight)) kg")
            }
        } catch {
            // Continue without weekly data context
        }

        return lines.isEmpty ? "No data available yet." : lines.joined(separator: "\n")
    }
}

#Preview {
    CoachView(
        aiCoachService: AICoachService(),
        dataService: DataAggregationService(healthKitService: HealthKitService())
    )
    .modelContainer(for: [CoachMessage.self, UserProfile.self, WeeklyReport.self, WorkoutSession.self, NutritionEntry.self, BodyMeasurement.self])
}
