import SwiftUI

struct MacroRingView: View {
    let calories: Double
    let targetCalories: Double
    let proteinGrams: Double
    let targetProteinGrams: Double
    let carbsGrams: Double
    let targetCarbsGrams: Double
    let fatGrams: Double
    let targetFatGrams: Double

    private let ringWidth: CGFloat = 14
    private let ringSpacing: CGFloat = 6

    private static let proteinColor = Color.blue
    private static let carbsColor = Color.green
    private static let fatColor = Color.orange

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Fat ring (outermost)
                ringLayer(
                    progress: progress(current: fatGrams, target: targetFatGrams),
                    color: Self.fatColor,
                    ringIndex: 0
                )

                // Carbs ring (middle)
                ringLayer(
                    progress: progress(current: carbsGrams, target: targetCarbsGrams),
                    color: Self.carbsColor,
                    ringIndex: 1
                )

                // Protein ring (innermost)
                ringLayer(
                    progress: progress(current: proteinGrams, target: targetProteinGrams),
                    color: Self.proteinColor,
                    ringIndex: 2
                )

                // Center calorie label
                calorieCenter
            }
            .frame(width: ringDiameter(for: 0), height: ringDiameter(for: 0))

            // Legend
            legendRow
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Ring Layer

    private func ringLayer(progress: Double, color: Color, ringIndex: Int) -> some View {
        let diameter = ringDiameter(for: ringIndex)
        return ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: ringWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
        .frame(width: diameter, height: diameter)
    }

    private func ringDiameter(for index: Int) -> CGFloat {
        let outerDiameter: CGFloat = 180
        let step = (ringWidth + ringSpacing) * 2
        return outerDiameter - step * CGFloat(index)
    }

    // MARK: - Center Label

    private var calorieCenter: some View {
        VStack(spacing: 2) {
            Text("\(Int(calories))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("/ \(Int(targetCalories))")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("kcal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: 20) {
            legendItem(
                label: "Protein",
                current: proteinGrams,
                target: targetProteinGrams,
                unit: "g",
                color: Self.proteinColor
            )
            legendItem(
                label: "Carbs",
                current: carbsGrams,
                target: targetCarbsGrams,
                unit: "g",
                color: Self.carbsColor
            )
            legendItem(
                label: "Fat",
                current: fatGrams,
                target: targetFatGrams,
                unit: "g",
                color: Self.fatColor
            )
        }
    }

    private func legendItem(label: String, current: Double, target: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(Int(current))/\(Int(target))\(unit)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Helpers

    private func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return current / target
    }
}

#Preview {
    MacroRingView(
        calories: 1650,
        targetCalories: 2200,
        proteinGrams: 120,
        targetProteinGrams: 160,
        carbsGrams: 180,
        targetCarbsGrams: 220,
        fatGrams: 55,
        targetFatGrams: 73
    )
    .padding()
}
