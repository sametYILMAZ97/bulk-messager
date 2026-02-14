import Foundation
import SwiftUI

@MainActor
class MessageHistoryManager: ObservableObject {
    @Published var history: [MessageHistory] = []

    private let historyFileURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("message_history.json")
    }()

    init() {
        loadHistory()
    }

    func addHistory(_ entry: MessageHistory) {
        history.insert(entry, at: 0)
        saveHistory()
    }

    func addHistoryFromResults(_ results: [SendResult], templateName: String? = nil) {
        for result in results {
            let status: HistoryStatus = {
                switch result.status {
                case .sent: return .sent
                case .failed: return .failed
                default: return .cancelled
                }
            }()

            let entry = MessageHistory(
                recipientName: result.contact.fullName,
                recipientPhone: result.phoneNumber,
                messageContent: "",
                timestamp: result.timestamp,
                status: status,
                templateUsed: templateName
            )
            history.insert(entry, at: 0)
        }
        saveHistory()
    }

    func filterHistory(searchText: String, status: HistoryStatus? = nil, startDate: Date? = nil, endDate: Date? = nil) -> [MessageHistory] {
        var filtered = history

        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.recipientName.localizedCaseInsensitiveContains(searchText) ||
                entry.recipientPhone.contains(searchText) ||
                entry.messageContent.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }

        if let startDate = startDate {
            filtered = filtered.filter { $0.timestamp >= startDate }
        }
        if let endDate = endDate {
            filtered = filtered.filter { $0.timestamp <= endDate }
        }

        return filtered
    }

    func getStatistics() -> (total: Int, sent: Int, failed: Int, cancelled: Int) {
        let total = history.count
        let sent = history.filter { $0.status == .sent }.count
        let failed = history.filter { $0.status == .failed }.count
        let cancelled = history.filter { $0.status == .cancelled }.count
        return (total, sent, failed, cancelled)
    }

    func getSuccessRate() -> Double {
        guard !history.isEmpty else { return 0 }
        let sent = history.filter { $0.status == .sent }.count
        return Double(sent) / Double(history.count) * 100.0
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            try data.write(to: historyFileURL)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func loadHistory() {
        do {
            let data = try Data(contentsOf: historyFileURL)
            history = try JSONDecoder().decode([MessageHistory].self, from: data)
        } catch {
            history = []
        }
    }

    func clearHistory() {
        history = []
        saveHistory()
    }

    func clearOlderThan(days: Int) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        history = history.filter { $0.timestamp >= cutoffDate }
        saveHistory()
    }

    func exportToCSV() -> String {
        var csv = "Timestamp,Recipient Name,Phone Number,Status,Template Used,Message Preview\n"

        for entry in history {
            let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
            let messagePreview = entry.messageContent.prefix(50).replacingOccurrences(of: "\"", with: "\"\"")
            let templateUsed = entry.templateUsed ?? "None"
            csv += "\"\(timestamp)\",\"\(entry.recipientName)\",\"\(entry.recipientPhone)\",\"\(entry.status.description)\",\"\(templateUsed)\",\"\(messagePreview)\"\n"
        }

        return csv
    }
}
