import SwiftUI
import SwiftData
import Charts

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \NutritionEntry.date, order: .reverse)
    private var allEntries: [NutritionEntry]

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var userProfile: UserProfile? { userProfiles.first }

    // MARK: - Filtered Data

    private var entriesForSelectedDate: [NutritionEntry] {
        let calendar = Calendar.current
        return allEntries.filter { entry in
            calendar.isDate(entry.date, inSameDayAs: selectedDate)
        }
    }

    private var totalCalories: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.calories }
    }

    private var totalProtein: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.proteinGrams }
    }

    private var totalCarbs: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.carbsGrams }
    }

    private var totalFat: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.fatGrams }
    }

    private var totalFiber: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.fiberGrams }
    }

    private var totalSugar: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.sugarGrams }
    }

    private var totalSodium: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.sodiumMg }
    }

    private var totalCholesterol: Double {
        entriesForSelectedDate.reduce(0) { $0 + $1.cholesterolMg }
    }

    private var aggregatedMicronutrients: [String: Double] {
        var combined: [String: Double] = [:]
        for entry in entriesForSelectedDate {
            for (key, value) in entry.micronutrients {
                combined[key, default: 0] += value
            }
        }
        return combined
    }

    /// Last 7 days of calorie data for the trend chart.
    private var weeklyCalorieTrend: [TrendDataPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -6 + offset, to: today) else {
                return nil
            }
            let dayTotal = allEntries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0.0) { $0 + $1.calories }
            return TrendDataPoint(date: date, value: dayTotal)
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                datePickerStrip
                macroRingSection
                macroSummarySection
                additionalNutrientsSection
                micronutrientSection
                calorieTrendSection
            }
            .padding()
        }
        .navigationTitle("Nutrition")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedDate = Calendar.current.startOfDay(for: Date())
                } label: {
                    Text("Today")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
        }
    }

    // MARK: - Date Picker Strip

    private var datePickerStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days: [Date] = (-13...0).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today)
        }

        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { date in
                        dateCell(date: date, isSelected: calendar.isDate(date, inSameDayAs: selectedDate))
                            .id(date)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = date
                                }
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
            .onAppear {
                proxy.scrollTo(today, anchor: .trailing)
            }
        }
    }

    private func dateCell(date: Date, isSelected: Bool) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)

        return VStack(spacing: 4) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2)
                .foregroundStyle(isSelected ? .white : .secondary)

            Text(date.formatted(.dateTime.day()))
                .font(.callout)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(width: 44, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isToday && !isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Macro Ring

    private var macroRingSection: some View {
        MacroRingView(
            calories: totalCalories,
            targetCalories: Double(userProfile?.targetCalories ?? 2200),
            proteinGrams: totalProtein,
            targetProteinGrams: Double(userProfile?.targetProteinGrams ?? 160),
            carbsGrams: totalCarbs,
            targetCarbsGrams: Double(userProfile?.targetCarbsGrams ?? 220),
            fatGrams: totalFat,
            targetFatGrams: Double(userProfile?.targetFatGrams ?? 73)
        )
    }

    // MARK: - Macro Summary

    private var macroSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Macro Summary", systemImage: "chart.bar.fill")
                .font(.headline)

            macroProgressBar(
                label: "Calories",
                current: totalCalories,
                target: Double(userProfile?.targetCalories ?? 2200),
                unit: "kcal",
                color: .orange
            )
            macroProgressBar(
                label: "Protein",
                current: totalProtein,
                target: Double(userProfile?.targetProteinGrams ?? 160),
                unit: "g",
                color: .blue
            )
            macroProgressBar(
                label: "Carbs",
                current: totalCarbs,
                target: Double(userProfile?.targetCarbsGrams ?? 220),
                unit: "g",
                color: .green
            )
            macroProgressBar(
                label: "Fat",
                current: totalFat,
                target: Double(userProfile?.targetFatGrams ?? 73),
                unit: "g",
                color: .orange
            )
            macroProgressBar(
                label: "Fiber",
                current: totalFiber,
                target: Double(userProfile?.targetFiberGrams ?? 30),
                unit: "g",
                color: .brown
            )
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func macroProgressBar(
        label: String,
        current: Double,
        target: Double,
        unit: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current)) / \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(
                            width: min(
                                geometry.size.width * progressFraction(current: current, target: target),
                                geometry.size.width
                            )
                        )
                }
            }
            .frame(height: 8)
        }
    }

    private func progressFraction(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    // MARK: - Additional Nutrients

    private var additionalNutrientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Other Nutrients", systemImage: "info.circle")
                .font(.headline)

            HStack(spacing: 12) {
                nutrientCard(name: "Sugar", value: totalSugar, unit: "g", icon: "cube.fill", color: .pink)
                nutrientCard(name: "Sodium", value: totalSodium, unit: "mg", icon: "drop.fill", color: .cyan)
                nutrientCard(name: "Cholesterol", value: totalCholesterol, unit: "mg", icon: "heart.fill", color: .red)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private func nutrientCard(name: String, value: Double, unit: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value > 0 ? "\(Int(value))" : "--")
                .font(.headline)
                .fontWeight(.bold)

            Text("\(name) (\(unit))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Micronutrient Section

    private var micronutrientSection: some View {
        MicronutrientListView(micronutrients: aggregatedMicronutrients)
    }

    // MARK: - 7-Day Calorie Trend

    private var calorieTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("7-Day Calorie Trend", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            if weeklyCalorieTrend.allSatisfy({ $0.value == 0 }) {
                emptyTrendState
            } else {
                calorieTrendChart
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var calorieTrendChart: some View {
        let targetCal = Double(userProfile?.targetCalories ?? 2200)

        return Chart {
            ForEach(weeklyCalorieTrend) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Calories", point.value)
                )
                .foregroundStyle(
                    point.value >= targetCal
                        ? Color.orange.gradient
                        : Color.blue.gradient
                )
                .cornerRadius(4)
            }

            RuleMark(y: .value("Target", targetCal))
                .foregroundStyle(.red.opacity(0.6))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .annotation(position: .top, alignment: .trailing) {
                    Text("Target")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.8))
                }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
            }
        }
        .frame(height: 180)
    }

    private var emptyTrendState: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title3)
                .foregroundStyle(.quaternary)
            Text("No data yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }
}

#Preview {
    NutritionView()
        .modelContainer(for: [UserProfile.self, NutritionEntry.self])
}
