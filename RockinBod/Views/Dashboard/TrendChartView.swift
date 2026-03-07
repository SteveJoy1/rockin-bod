import SwiftUI
import Charts

struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct TrendChartView: View {
    let title: String
    let data: [TrendDataPoint]
    var color: Color = .blue
    var unitLabel: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                if let lastPoint = data.last {
                    Text(formattedValue(lastPoint.value) + (unitLabel.isEmpty ? "" : " \(unitLabel)"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
            }

            if data.isEmpty {
                emptyState
            } else {
                chart
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Chart

    @ViewBuilder
    private var chart: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Value", point.value)
            )
            .foregroundStyle(color)
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))

            AreaMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [color.opacity(0.2), color.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: xAxisStride)) { value in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel()
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
            }
        }
        .frame(height: 150)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.title3)
                .foregroundStyle(.quaternary)
            Text("No data yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    // MARK: - Helpers

    private var yDomain: ClosedRange<Double> {
        let values = data.map(\.value)
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...1
        }
        let padding = (maxVal - minVal) * 0.1
        let lowerBound = Swift.max(0, minVal - padding)
        let upperBound = maxVal + padding
        // Avoid zero-range domain
        if lowerBound == upperBound {
            return (lowerBound - 1)...(upperBound + 1)
        }
        return lowerBound...upperBound
    }

    private var xAxisStride: Int {
        if data.count <= 7 { return 1 }
        if data.count <= 14 { return 2 }
        return 4
    }

    private func formattedValue(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

#Preview {
    let sampleData: [TrendDataPoint] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<14).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -13 + offset, to: today) else {
                return nil
            }
            return TrendDataPoint(date: date, value: 82.0 + Double.random(in: -1.5...1.5))
        }
    }()

    VStack {
        TrendChartView(
            title: "Weight",
            data: sampleData,
            color: .purple,
            unitLabel: "kg"
        )
        TrendChartView(
            title: "Empty Chart",
            data: [],
            color: .orange,
            unitLabel: "kg"
        )
    }
    .padding()
}
