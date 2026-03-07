import SwiftUI

struct PhotoComparisonView: View {
    let before: ProgressPhoto
    let after: ProgressPhoto

    @Environment(\.dismiss) private var dismiss
    @State private var comparisonMode: ComparisonMode = .slider
    @State private var sliderPosition: CGFloat = 0.5

    enum ComparisonMode: String, CaseIterable {
        case slider = "Slider"
        case sideBySide = "Side by Side"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    modeToggle
                        .padding(.top, 8)

                    Spacer()

                    switch comparisonMode {
                    case .slider:
                        sliderComparison
                    case .sideBySide:
                        sideBySideComparison
                    }

                    Spacer()

                    dateLabels
                        .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.8))
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Compare")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        Picker("Mode", selection: $comparisonMode) {
            ForEach(ComparisonMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 40)
        .colorScheme(.dark)
    }

    // MARK: - Slider Comparison

    private var sliderComparison: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                // After photo (full width, behind)
                photoImage(for: after)
                    .frame(width: size.width, height: size.height)
                    .clipped()

                // Before photo (clipped to slider position)
                photoImage(for: before)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .clipShape(
                        HorizontalClip(position: sliderPosition)
                    )

                // Divider line
                Rectangle()
                    .fill(.white)
                    .frame(width: 3)
                    .position(x: size.width * sliderPosition, y: size.height / 2)
                    .shadow(color: .black.opacity(0.4), radius: 4)

                // Slider handle
                sliderHandle
                    .position(x: size.width * sliderPosition, y: size.height / 2)

                // Before/After labels
                HStack {
                    Text("BEFORE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.leading, 12)

                    Spacer()

                    Text("AFTER")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.5), in: Capsule())
                        .padding(.trailing, 12)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newPosition = value.location.x / size.width
                        sliderPosition = min(max(newPosition, 0.02), 0.98)
                    }
            )
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private var sliderHandle: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.3), radius: 4)

            HStack(spacing: 2) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.black.opacity(0.6))
        }
    }

    // MARK: - Side by Side Comparison

    private var sideBySideComparison: some View {
        HStack(spacing: 4) {
            VStack(spacing: 6) {
                photoImage(for: before)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                angleBadge(before.angle)
            }

            VStack(spacing: 6) {
                photoImage(for: after)
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                angleBadge(after.angle)
            }
        }
        .padding(.horizontal, 8)
    }

    private func angleBadge(_ angle: PhotoAngle) -> some View {
        HStack(spacing: 3) {
            Image(systemName: angle.icon)
                .font(.system(size: 10))
            Text(angle.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.white.opacity(0.7))
    }

    // MARK: - Date Labels

    private var dateLabels: some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("Before")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(before.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            if let daysBetween = daysBetween {
                VStack(spacing: 2) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                    Text("\(daysBetween) days")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack(spacing: 2) {
                Text("After")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text(after.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Helpers

    private func photoImage(for photo: ProgressPhoto) -> some View {
        Group {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.quaternary)
                    }
            }
        }
    }

    private var daysBetween: Int? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: before.date, to: after.date)
        guard let days = components.day, days > 0 else { return nil }
        return days
    }
}

// MARK: - Horizontal Clip Shape

private struct HorizontalClip: Shape {
    var position: CGFloat

    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(
            x: 0,
            y: 0,
            width: rect.width * position,
            height: rect.height
        ))
        return path
    }
}

#Preview {
    // Preview with placeholder data
    let beforePhoto = ProgressPhoto(
        date: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
        imageData: Data(),
        angle: .front,
        notes: "Starting point"
    )
    let afterPhoto = ProgressPhoto(
        date: Date(),
        imageData: Data(),
        angle: .front,
        notes: "One month progress"
    )

    PhotoComparisonView(before: beforePhoto, after: afterPhoto)
}
