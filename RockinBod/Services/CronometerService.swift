import Foundation
import SwiftData
import HealthKit

// MARK: - Cronometer Errors

enum CronometerError: LocalizedError {
    case invalidCSVFormat
    case missingRequiredColumns([String])
    case dateParsingFailed(String)
    case noRecordsFound
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidCSVFormat:
            return "The file is not a valid Cronometer CSV export."
        case .missingRequiredColumns(let columns):
            return "Missing required columns: \(columns.joined(separator: ", "))"
        case .dateParsingFailed(let dateString):
            return "Failed to parse date: \(dateString)"
        case .noRecordsFound:
            return "No nutrition records found in the CSV file."
        case .encodingError:
            return "Failed to read the CSV file. Ensure it is UTF-8 encoded."
        }
    }
}

// MARK: - Cronometer CSV Column Mapping

/// Maps Cronometer's "Daily Nutrition" CSV column headers to internal fields and micronutrient keys.
private struct CronometerColumnMap {

    // Required macro columns (case-insensitive matching)
    static let date = "date"
    static let calories = "energy (kcal)"
    static let protein = "protein (g)"
    static let carbs = "carbs (g)"
    static let fat = "fat (g)"
    static let fiber = "fiber (g)"
    static let sugar = "sugars (g)"
    static let sodium = "sodium (mg)"
    static let cholesterol = "cholesterol (mg)"

    static let requiredColumns: Set<String> = [
        date, calories,
    ]

    /// Mapping from Cronometer CSV header (lowercased) to MicronutrientKeys constant.
    static let micronutrientMapping: [String: String] = [
        "vitamin a (mcg)": MicronutrientKeys.vitaminA,
        "vitamin a (µg)": MicronutrientKeys.vitaminA,
        "vitamin c (mg)": MicronutrientKeys.vitaminC,
        "vitamin d (mcg)": MicronutrientKeys.vitaminD,
        "vitamin d (µg)": MicronutrientKeys.vitaminD,
        "vitamin e (mg)": MicronutrientKeys.vitaminE,
        "vitamin k (mcg)": MicronutrientKeys.vitaminK,
        "vitamin k (µg)": MicronutrientKeys.vitaminK,
        "vitamin b6 (mg)": MicronutrientKeys.vitaminB6,
        "b6 (mg)": MicronutrientKeys.vitaminB6,
        "vitamin b12 (mcg)": MicronutrientKeys.vitaminB12,
        "vitamin b12 (µg)": MicronutrientKeys.vitaminB12,
        "b12 (mcg)": MicronutrientKeys.vitaminB12,
        "b12 (µg)": MicronutrientKeys.vitaminB12,
        "thiamin (mg)": MicronutrientKeys.thiamin,
        "thiamine (mg)": MicronutrientKeys.thiamin,
        "riboflavin (mg)": MicronutrientKeys.riboflavin,
        "niacin (mg)": MicronutrientKeys.niacin,
        "folate (mcg)": MicronutrientKeys.folate,
        "folate (µg)": MicronutrientKeys.folate,
        "calcium (mg)": MicronutrientKeys.calcium,
        "iron (mg)": MicronutrientKeys.iron,
        "magnesium (mg)": MicronutrientKeys.magnesium,
        "phosphorus (mg)": MicronutrientKeys.phosphorus,
        "potassium (mg)": MicronutrientKeys.potassium,
        "zinc (mg)": MicronutrientKeys.zinc,
        "selenium (mcg)": MicronutrientKeys.selenium,
        "selenium (µg)": MicronutrientKeys.selenium,
        "omega-3 (g)": MicronutrientKeys.omega3,
    ]
}

// MARK: - Cronometer Service

@Observable
final class CronometerService {

    // MARK: - Properties

    private let healthStore: HKHealthStore?
    private let calendar = Calendar.current

    /// Date formatters for Cronometer CSV date column (tries multiple formats).
    private static let dateFormatters: [DateFormatter] = {
        let formats = ["yyyy-MM-dd", "M/d/yyyy", "MM/dd/yyyy", "d-MMM-yyyy"]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            return formatter
        }
    }()

    // MARK: - Initialization

    init() {
        if HKHealthStore.isHealthDataAvailable() {
            self.healthStore = HKHealthStore()
        } else {
            self.healthStore = nil
        }
    }

    // MARK: - HealthKit Nutrition Sync Check

    /// Checks whether HealthKit contains any dietary energy data, which indicates
    /// that Cronometer (or another nutrition app) is syncing to Apple Health.
    var hasHealthKitNutritionSync: Bool {
        get async {
            guard let store = healthStore,
                  let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
                return false
            }

            let now = Date()
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            let predicate = HKQuery.predicateForSamples(
                withStart: sevenDaysAgo,
                end: now,
                options: .strictStartDate
            )

            return await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: energyType,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: nil
                ) { _, samples, _ in
                    let hasData = (samples?.isEmpty == false)
                    continuation.resume(returning: hasData)
                }
                store.execute(query)
            }
        }
    }

    // MARK: - CSV Import

    /// Imports Cronometer's "Daily Nutrition" CSV export into SwiftData.
    ///
    /// - Parameters:
    ///   - data: Raw CSV file data (UTF-8 encoded).
    ///   - context: The SwiftData model context to insert records into.
    /// - Returns: The number of new `NutritionEntry` records created.
    @MainActor
    func importFromCSV(data: Data, context: ModelContext) async throws -> Int {
        guard let csvString = String(data: data, encoding: .utf8) else {
            throw CronometerError.encodingError
        }

        let rows = parseCSVRows(csvString)

        guard rows.count >= 2 else {
            throw CronometerError.invalidCSVFormat
        }

        // Parse header row
        let headers = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }

        // Validate required columns exist
        let headerSet = Set(headers)
        let missingRequired = CronometerColumnMap.requiredColumns.subtracting(headerSet)
        if !missingRequired.isEmpty {
            throw CronometerError.missingRequiredColumns(Array(missingRequired).sorted())
        }

        // Build column index lookup
        var columnIndex: [String: Int] = [:]
        for (index, header) in headers.enumerated() {
            columnIndex[header] = index
        }

        // Identify which micronutrient columns are present
        var microColumns: [(columnIndex: Int, microKey: String)] = []
        for (header, microKey) in CronometerColumnMap.micronutrientMapping {
            if let idx = columnIndex[header] {
                microColumns.append((columnIndex: idx, microKey: microKey))
            }
        }

        // Parse data rows
        var importedCount = 0
        let dataRows = rows.dropFirst()

        for row in dataRows {
            guard row.count >= headers.count else { continue }

            // Parse the date
            guard let dateIndex = columnIndex[CronometerColumnMap.date] else { continue }
            let dateString = row[dateIndex].trimmingCharacters(in: .whitespaces)
            guard let entryDate = Self.parseDate(dateString) else { continue }

            let normalizedDate = calendar.startOfDay(for: entryDate)

            // Check for existing entry on this date from Cronometer (deduplicate)
            let existingPredicate = #Predicate<NutritionEntry> { entry in
                entry.sourceRaw == "cronometer"
            }
            let descriptor = FetchDescriptor<NutritionEntry>(predicate: existingPredicate)
            let existingEntries = (try? context.fetch(descriptor)) ?? []

            let alreadyExists = existingEntries.contains { entry in
                calendar.isDate(entry.date, inSameDayAs: normalizedDate)
            }

            if alreadyExists {
                continue
            }

            // Parse macro values
            let calories = doubleValue(from: row, columnIndex: columnIndex, key: CronometerColumnMap.calories)
            let protein = doubleValue(from: row, columnIndex: columnIndex, key: CronometerColumnMap.protein)
            let carbs = doubleValue(from: row, columnIndex: columnIndex, key: CronometerColumnMap.carbs)
            let fat = doubleValue(from: row, columnIndex: columnIndex, key: CronometerColumnMap.fat)
            let fiber = doubleValue(from: row, columnIndex: columnIndex, key: CronometerColumnMap.fiber)
            let sugar = doubleValue(from: row, columnIndex: columnIndex, key: CronometerColumnMap.sugar)
            let sodium = doubleValue(from: row, columnIndex: columnIndex, key: CronometerColumnMap.sodium)
            let cholesterol = doubleValue(from: row, columnIndex: columnIndex, key: CronometerColumnMap.cholesterol)

            // Parse micronutrient values
            var micros: [String: Double] = [:]
            for micro in microColumns {
                guard micro.columnIndex < row.count else { continue }
                let rawValue = row[micro.columnIndex].trimmingCharacters(in: .whitespaces)
                if let value = Double(rawValue), value > 0 {
                    micros[micro.microKey] = value
                }
            }

            // Create and insert the NutritionEntry
            let entry = NutritionEntry(
                date: normalizedDate,
                source: .cronometer,
                calories: calories,
                proteinGrams: protein,
                carbsGrams: carbs,
                fatGrams: fat,
                fiberGrams: fiber,
                sugarGrams: sugar,
                sodiumMg: sodium,
                cholesterolMg: cholesterol,
                micronutrients: micros
            )

            context.insert(entry)
            importedCount += 1
        }

        if importedCount == 0 && dataRows.isEmpty {
            throw CronometerError.noRecordsFound
        }

        try context.save()
        return importedCount
    }

    // MARK: - Private Helpers

    /// Parse a date string trying multiple formats common in Cronometer exports.
    private static func parseDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    /// Safely extract a Double value from a CSV row using the column index lookup.
    private func doubleValue(
        from row: [String],
        columnIndex: [String: Int],
        key: String
    ) -> Double {
        guard let idx = columnIndex[key], idx < row.count else { return 0 }
        let raw = row[idx].trimmingCharacters(in: .whitespaces)
        return Double(raw) ?? 0
    }

    /// Parse a CSV string into rows of fields, handling quoted fields with commas and newlines.
    private func parseCSVRows(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        let characters = Array(csv)
        var i = 0

        while i < characters.count {
            let char = characters[i]

            if insideQuotes {
                if char == "\"" {
                    // Check for escaped quote ("")
                    if i + 1 < characters.count && characters[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        insideQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(char)
                    i += 1
                    continue
                }
            }

            switch char {
            case "\"":
                insideQuotes = true
            case ",":
                currentRow.append(currentField)
                currentField = ""
            case "\r":
                // Handle \r\n or standalone \r
                currentRow.append(currentField)
                currentField = ""
                if !currentRow.allSatisfy({ $0.isEmpty }) || !rows.isEmpty {
                    rows.append(currentRow)
                }
                currentRow = []
                if i + 1 < characters.count && characters[i + 1] == "\n" {
                    i += 1
                }
            case "\n":
                currentRow.append(currentField)
                currentField = ""
                if !currentRow.allSatisfy({ $0.isEmpty }) || !rows.isEmpty {
                    rows.append(currentRow)
                }
                currentRow = []
            default:
                currentField.append(char)
            }

            i += 1
        }

        // Handle last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}
