import SwiftUI

enum AppConstants {
    static let appName = "RockinBod"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    enum API {
        static let anthropicBaseURL = "https://api.anthropic.com/v1"
        static let anthropicVersion = "2023-06-01"
        static let hevyBaseURL = "https://api.hevyapp.com/v1"
        static let defaultModel = "claude-sonnet-4-20250514"
    }

    enum Defaults {
        static let syncDaysBack = 14
        static let trendDays = 30
        static let maxVideoFrames = 8
        static let photoCompressionQuality: CGFloat = 0.8
        static let thumbnailCompressionQuality: CGFloat = 0.6
    }

    enum Colors {
        static let protein = Color.blue
        static let carbs = Color.green
        static let fat = Color.orange
        static let fiber = Color.brown
        static let calories = Color.red
        static let weight = Color.purple
        static let bodyFat = Color.orange
        static let muscleMass = Color.green
        static let steps = Color.teal
        static let heartRate = Color.red
        static let sleep = Color.indigo
    }
}
