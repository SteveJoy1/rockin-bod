import Foundation
import SwiftData

@Model
final class CoachMessage {
    var id: UUID
    var date: Date
    var roleRaw: String
    var content: String
    var contextSummary: String?

    var role: MessageRole {
        get { MessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(
        date: Date = Date(),
        role: MessageRole = .user,
        content: String = "",
        contextSummary: String? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.roleRaw = role.rawValue
        self.content = content
        self.contextSummary = contextSummary
    }
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
}
