import SwiftUI

// MARK: - Date Extensions

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) ?? self
    }

    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? self
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    var shortDateString: String {
        let formatter = DateFormatter()
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: self)
        }
    }

    var dayOfWeekString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }

    var monthDayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

// MARK: - Double Extensions

extension Double {
    var kgToLbs: Double { self * 2.20462 }
    var lbsToKg: Double { self / 2.20462 }
    var cmToInches: Double { self / 2.54 }
    var inchesToCm: Double { self * 2.54 }

    var formattedOneDecimal: String {
        String(format: "%.1f", self)
    }

    var formattedNoDecimal: String {
        String(format: "%.0f", self)
    }

    var formattedCalories: String {
        "\(Int(self)) kcal"
    }

    var formattedGrams: String {
        "\(formattedOneDecimal)g"
    }

    var formattedKg: String {
        "\(formattedOneDecimal) kg"
    }

    var formattedLbs: String {
        "\(kgToLbs.formattedOneDecimal) lbs"
    }

    var formattedPercentage: String {
        "\(formattedOneDecimal)%"
    }

    var formattedMinutes: String {
        let hours = Int(self) / 60
        let mins = Int(self) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins) min"
    }
}

// MARK: - Int Extensions

extension Int {
    var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Data Extensions

extension Data {
    var sizeString: String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useKB, .useMB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: Int64(count))
    }
}

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
