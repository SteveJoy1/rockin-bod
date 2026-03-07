import Foundation
import SwiftData

@Model
final class ProgressPhoto {
    var id: UUID
    var date: Date
    var imageData: Data
    var angleRaw: String
    var notes: String?
    @Relationship var weeklyReport: WeeklyReport?

    var angle: PhotoAngle {
        get { PhotoAngle(rawValue: angleRaw) ?? .front }
        set { angleRaw = newValue.rawValue }
    }

    init(
        date: Date = Date(),
        imageData: Data = Data(),
        angle: PhotoAngle = .front,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.imageData = imageData
        self.angleRaw = angle.rawValue
        self.notes = notes
    }
}

enum PhotoAngle: String, CaseIterable, Codable {
    case front = "front"
    case side = "side"
    case back = "back"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .front: return "Front"
        case .side: return "Side"
        case .back: return "Back"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .front: return "person.fill"
        case .side: return "person.fill.turn.right"
        case .back: return "person.fill.turn.left"
        case .custom: return "camera.fill"
        }
    }
}
