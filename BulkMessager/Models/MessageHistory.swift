import Foundation

struct MessageHistory: Identifiable, Codable {
    let id: UUID
    let recipientName: String
    let recipientPhone: String
    let messageContent: String
    let timestamp: Date
    let status: HistoryStatus
    let templateUsed: String?
    let metadata: [String: String]

    init(id: UUID = UUID(), recipientName: String, recipientPhone: String, messageContent: String, timestamp: Date = Date(), status: HistoryStatus, templateUsed: String? = nil, metadata: [String: String] = [:]) {
        self.id = id
        self.recipientName = recipientName
        self.recipientPhone = recipientPhone
        self.messageContent = messageContent
        self.timestamp = timestamp
        self.status = status
        self.templateUsed = templateUsed
        self.metadata = metadata
    }

    var statusColor: String {
        status.color
    }

    var statusIcon: String {
        status.iconName
    }
}

enum HistoryStatus: String, Codable {
    case sent
    case failed
    case cancelled

    var color: String {
        switch self {
        case .sent: return "green"
        case .failed: return "red"
        case .cancelled: return "orange"
        }
    }

    var iconName: String {
        switch self {
        case .sent: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }

    var description: String {
        rawValue.capitalized
    }
}
