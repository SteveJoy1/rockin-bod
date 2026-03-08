import SwiftUI
import SwiftData
import Charts

struct BodyMetricsChartView: View {
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var allMeasurements: [BodyMeasurement]

    @AppStorage("useMetricUnits") private var useMetricUnits = true
    @State private var selectedRange: DateRange = .threeMonths

    enum DateRange: String, CaseIterable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case all = "All"

        var days: Int? {
            switch self {
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            case .all: return nil
            }
        }
    }

    private var filteredMeasurements: [BodyMeasurement] {
        guard let days = selectedRange.days else {
            return allMeasurements
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return allMeasurements.filter { $0.date >= cutoff }
    }

    // Chronological order for charts (oldest first)
    private var chronologicalMeasurements: [BodyMeasurement] {
        filteredMeasurements.reversed()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dateRangeSelector
                weightSummaryCard
                weightChart
                bodyFatChart
                muscleMassChart
                bmiChart
                tapeMeasurementsChart
            }
            .padding()
        }
        .navigationTitle("Body Metrics")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Date Range Selector

    private var dateRangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(DateRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedRange == range
                                ? Color.accentColor
                                : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(selectedRange == range ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Weight Summary Card

    private var weightSummaryCard: some View {
        let weights = chronologicalMeasurements.compactMap { $0.weightKg }

        return Group {
            if !weights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Weight Summary", systemImage: "scalemass.fill")
                        .font(.headline)

                    HStack(spacing: 0) {
                        statItem(
                            label: "Current",
                            value: formattedWeight(weights.last),
                            color: .primary
                        )

                        Divider()
                            .frame(height: 40)

                        statItem(
                            label: "Change",
                            value: formattedChange(from: weights.first, to: weights.last),
                            color: changeColor(from: weights.first, to: weights.last)
                        )

                        Divider()
                            .frame(height: 40)

                        statItem(
                            label: "Min",
                            value: formattedWeight(weights.min()),
                            color: .green
                        )

                        Divider()
                            .frame(height: 40)

                        statItem(
                            label: "Max",
                            value: formattedWeight(weights.max()),
                            color: .red
                        )
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Charts

    private var weightUnit: String { useMetricUnits ? "kg" : "lbs" }
    private var lengthUnit: String { useMetricUnits ? "cm" : "in" }

    private func convertedWeightData(_ data: [TrendDataPoint]) -> [TrendDataPoint] {
        useMetricUnits ? data : data.map { TrendDataPoint(date: $0.date, value: $0.value.kgToLbs) }
    }

    private func convertedLengthData(_ data: [TrendDataPoint]) -> [TrendDataPoint] {
        useMetricUnits ? data : data.map { TrendDataPoint(date: $0.date, value: $0.value.cmToInches) }
    }

    private var weightChart: some View {
        TrendChartView(
            title: "Weight",
            data: convertedWeightData(trendData(for: \.weightKg)),
            color: .purple,
            unitLabel: weightUnit
        )
    }

    @ViewBuilder
    private var bodyFatChart: some View {
        let data = trendData(for: \.bodyFatPercentage)
        if !data.isEmpty {
            TrendChartView(
                title: "Body Fat",
                data: data,
                color: .orange,
                unitLabel: "%"
            )
        }
    }

    @ViewBuilder
    private var muscleMassChart: some View {
        let data = trendData(for: \.muscleMassKg)
        if !data.isEmpty {
            TrendChartView(
                title: "Muscle Mass",
                data: convertedWeightData(data),
                color: .green,
                unitLabel: weightUnit
            )
        }
    }

    @ViewBuilder
    private var bmiChart: some View {
        let data = trendData(for: \.bmi)
        if !data.isEmpty {
            TrendChartView(
                title: "BMI",
                data: data,
                color: .blue,
                unitLabel: ""
            )
        }
    }

    // MARK: - Tape Measurements Charts

    @ViewBuilder
    private var tapeMeasurementsChart: some View {
        let waistData = trendData(for: \.waistCm)
        let chestData = trendData(for: \.chestCm)
        let hipsData = trendData(for: \.hipsCm)
        let armData = trendData(for: \.leftArmCm)
        let thighData = trendData(for: \.leftThighCm)

        let hasTapeData = !waistData.isEmpty || !chestData.isEmpty || !hipsData.isEmpty ||
                          !armData.isEmpty || !thighData.isEmpty

        if hasTapeData {
            VStack(alignment: .leading, spacing: 12) {
                Label("Tape Measurements", systemImage: "ruler")
                    .font(.headline)
                    .padding(.horizontal)

                if !waistData.isEmpty {
                    TrendChartView(
                        title: "Waist",
                        data: convertedLengthData(waistData),
                        color: .red,
                        unitLabel: lengthUnit
                    )
                }

                if !chestData.isEmpty {
                    TrendChartView(
                        title: "Chest",
                        data: convertedLengthData(chestData),
                        color: .blue,
                        unitLabel: lengthUnit
                    )
                }

                if !hipsData.isEmpty {
                    TrendChartView(
                        title: "Hips",
                        data: convertedLengthData(hipsData),
                        color: .purple,
                        unitLabel: lengthUnit
                    )
                }

                if !armData.isEmpty {
                    TrendChartView(
                        title: "Arms (L)",
                        data: convertedLengthData(armData),
                        color: .teal,
                        unitLabel: lengthUnit
                    )
                }

                if !thighData.isEmpty {
                    TrendChartView(
                        title: "Thighs (L)",
                        data: convertedLengthData(thighData),
                        color: .cyan,
                        unitLabel: lengthUnit
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func trendData(for keyPath: KeyPath<BodyMeasurement, Double?>) -> [TrendDataPoint] {
        chronologicalMeasurements.compactMap { measurement in
            guard let value = measurement[keyPath: keyPath] else { return nil }
            return TrendDataPoint(date: measurement.date, value: value)
        }
    }

    private func formattedWeight(_ weight: Double?) -> String {
        guard let weight else { return "--" }
        return String(format: "%.1f kg", weight)
    }

    private func formattedChange(from first: Double?, to last: Double?) -> String {
        guard let first, let last else { return "--" }
        let change = last - first
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.1f kg", sign, change)
    }

    private func changeColor(from first: Double?, to last: Double?) -> Color {
        guard let first, let last else { return .secondary }
        let change = last - first
        if abs(change) < 0.1 { return .secondary }
        // Weight loss is typically green, gain is red (can be contextual)
        return change < 0 ? .green : .red
    }
}

#Preview {
    NavigationStack {
        BodyMetricsChartView()
    }
    .modelContainer(for: [BodyMeasurement.self])
}
