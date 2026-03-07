import SwiftUI

struct MicronutrientListView: View {
    let micronutrients: [String: Double]

    @State private var vitaminsExpanded = true
    @State private var mineralsExpanded = true

    private var vitaminKeys: [(key: String, name: String, unit: String, dailyValue: Double)] {
        MicronutrientKeys.allKeys.filter { entry in
            entry.name.localizedCaseInsensitiveContains("vitamin")
                || ["Thiamin", "Riboflavin", "Niacin", "Folate"].contains(entry.name)
        }
    }

    private var mineralKeys: [(key: String, name: String, unit: String, dailyValue: Double)] {
        MicronutrientKeys.allKeys.filter { entry in
            !vitaminKeys.contains(where: { $0.key == entry.key })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Micronutrients", systemImage: "leaf.fill")
                .font(.headline)

            nutrientSection(
                title: "Vitamins",
                icon: "pill.fill",
                keys: vitaminKeys,
                isExpanded: $vitaminsExpanded
            )

            nutrientSection(
                title: "Minerals",
                icon: "atom",
                keys: mineralKeys,
                isExpanded: $mineralsExpanded
            )
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - Section

    private func nutrientSection(
        title: String,
        icon: String,
        keys: [(key: String, name: String, unit: String, dailyValue: Double)],
        isExpanded: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Spacer()

                    sectionScoreBadge(keys: keys)

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)

            if isExpanded.wrappedValue {
                VStack(spacing: 10) {
                    ForEach(keys, id: \.key) { entry in
                        nutrientRow(entry: entry)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Section Score Badge

    private func sectionScoreBadge(
        keys: [(key: String, name: String, unit: String, dailyValue: Double)]
    ) -> some View {
        let tracked = keys.filter { micronutrients[$0.key] != nil }
        let adequate = tracked.filter { entry in
            let amount = micronutrients[entry.key] ?? 0
            return percentOfDV(amount: amount, dailyValue: entry.dailyValue) >= 0.8
        }
        let count = tracked.isEmpty ? 0 : adequate.count
        let total = tracked.count

        return Text("\(count)/\(total)")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }

    // MARK: - Nutrient Row

    private func nutrientRow(
        entry: (key: String, name: String, unit: String, dailyValue: Double)
    ) -> some View {
        let amount = micronutrients[entry.key] ?? 0
        let fraction = percentOfDV(amount: amount, dailyValue: entry.dailyValue)
        let color = colorForFraction(fraction)

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                Text(formattedAmount(amount, unit: entry.unit))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(formattedPercent(fraction))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .frame(width: 48, alignment: .trailing)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(
                            width: min(
                                geometry.size.width * min(fraction, 1.0),
                                geometry.size.width
                            )
                        )
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Helpers

    private func percentOfDV(amount: Double, dailyValue: Double) -> Double {
        guard dailyValue > 0 else { return 0 }
        return amount / dailyValue
    }

    private func colorForFraction(_ fraction: Double) -> Color {
        switch fraction {
        case 0.8...:
            return .green
        case 0.5..<0.8:
            return .yellow
        default:
            return .red
        }
    }

    private func formattedAmount(_ amount: Double, unit: String) -> String {
        if amount == 0 { return "-- \(unit)" }
        if amount >= 100 {
            return "\(Int(amount)) \(unit)"
        }
        return String(format: "%.1f \(unit)", amount)
    }

    private func formattedPercent(_ fraction: Double) -> String {
        "\(Int(fraction * 100))%"
    }
}

#Preview {
    ScrollView {
        MicronutrientListView(micronutrients: [
            MicronutrientKeys.vitaminA: 750,
            MicronutrientKeys.vitaminC: 95,
            MicronutrientKeys.vitaminD: 8,
            MicronutrientKeys.vitaminE: 12,
            MicronutrientKeys.vitaminK: 100,
            MicronutrientKeys.vitaminB6: 1.5,
            MicronutrientKeys.vitaminB12: 2.0,
            MicronutrientKeys.thiamin: 1.0,
            MicronutrientKeys.riboflavin: 0.9,
            MicronutrientKeys.niacin: 14,
            MicronutrientKeys.folate: 320,
            MicronutrientKeys.calcium: 900,
            MicronutrientKeys.iron: 15,
            MicronutrientKeys.magnesium: 350,
            MicronutrientKeys.phosphorus: 1000,
            MicronutrientKeys.potassium: 3200,
            MicronutrientKeys.zinc: 9,
            MicronutrientKeys.selenium: 48,
            MicronutrientKeys.omega3: 1.2,
        ])
        .padding()
    }
}
