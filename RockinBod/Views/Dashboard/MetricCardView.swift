import SwiftUI

struct MetricCardView: View {
    let title: String
    let icon: String
    let value: String
    var subtitle: String? = nil
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    VStack {
        MetricCardView(
            title: "Steps",
            icon: "figure.walk",
            value: "8,432",
            subtitle: "Goal: 10,000",
            color: .green
        )
        MetricCardView(
            title: "Calories",
            icon: "flame.fill",
            value: "1,845",
            color: .orange
        )
    }
    .padding()
}
