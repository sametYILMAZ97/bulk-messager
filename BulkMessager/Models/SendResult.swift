import Foundation

enum SendStatus: Equatable {
    case pending
    case sending
    case sent
    case failed(String)

    var description: String {
        switch self {
        case .pending:
            return "Pending"
        case .sending:
            return "Sending…"
        case .sent:
            return "Sent"
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    var iconName: String {
        switch self {
        case .pending:
            return "clock"
        case .sending:
            return "arrow.up.circle"
        case .sent:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.circle.fill"
        }
    }

    var isSuccess: Bool {
        if case .sent = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }
}

struct SendResult: Identifiable {
    let id = UUID()
    let contact: Contact
    let phoneNumber: String
    var status: SendStatus
    let timestamp: Date

    init(contact: Contact, phoneNumber: String, status: SendStatus = .pending) {
        self.contact = contact
        self.phoneNumber = phoneNumber
        self.status = status
        self.timestamp = Date()
    }
}

struct SendSummary {
    let total: Int
    let sent: Int
    let failed: Int
    let pending: Int

    var isComplete: Bool {
        pending == 0
    }

    var successRate: Double {
        guard total > 0 else { return 0 }
        return Double(sent) / Double(total) * 100.0
    }

    init(results: [SendResult]) {
        self.total = results.count
        self.sent = results.filter { $0.status.isSuccess }.count
        self.failed = results.filter { $0.status.isFailed }.count
        self.pending = results.filter {
            if case .pending = $0.status { return true }
            if case .sending = $0.status { return true }
            return false
        }.count
    }
}
