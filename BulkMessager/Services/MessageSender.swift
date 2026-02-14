import Foundation
import Combine

@MainActor
class MessageSender: ObservableObject {
    @Published var results: [SendResult] = []
    @Published var isSending: Bool = false
    @Published var currentIndex: Int = 0
    @Published var delayBetweenMessages: Double = 2.0 // seconds

    var summary: SendSummary {
        SendSummary(results: results)
    }

    var progress: Double {
        guard !results.isEmpty else { return 0 }
        let completed = results.filter { $0.status.isSuccess || $0.status.isFailed }.count
        return Double(completed) / Double(results.count)
    }

    // MARK: - Send Messages

    func sendMessages(to contacts: [Contact], message: String) async {
        guard !contacts.isEmpty else { return }
        guard !message.isEmpty else { return }

        isSending = true
        currentIndex = 0

        // Initialize results
        results = contacts.compactMap { contact in
            guard let phone = contact.selectedPhoneNumber else { return nil }
            return SendResult(contact: contact, phoneNumber: phone.number, status: .pending)
        }

        for index in results.indices {
            guard isSending else { break } // Allow cancellation

            currentIndex = index
            results[index].status = .sending

            do {
                try await sendMessage(message, to: results[index].phoneNumber)
                results[index].status = .sent
            } catch {
                results[index].status = .failed(error.localizedDescription)
            }

            // Delay between messages to avoid overwhelming Messages.app
            if index < results.count - 1 && isSending {
                try? await Task.sleep(nanoseconds: UInt64(delayBetweenMessages * 1_000_000_000))
            }
        }

        isSending = false
    }

    // MARK: - Send Messages with Templates

    func sendMessagesWithTemplates(to contacts: [(name: String, phone: String, fields: [String: String])], template: String, templateName: String?) async {
        guard !contacts.isEmpty else { return }
        guard !template.isEmpty else { return }

        isSending = true
        currentIndex = 0

        // Initialize results with placeholder Contact objects
        results = contacts.map { contactInfo in
            let placeholderContact = Contact(
                id: UUID().uuidString,
                firstName: contactInfo.fields["firstName"] ?? contactInfo.name,
                lastName: contactInfo.fields["lastName"] ?? "",
                phoneNumbers: [PhoneNumber(label: "", number: contactInfo.phone)]
            )
            return SendResult(contact: placeholderContact, phoneNumber: contactInfo.phone, status: .pending)
        }

        for index in results.indices {
            guard isSending else { break }

            currentIndex = index
            results[index].status = .sending

            // Substitute template variables
            let personalizedMessage = MessageTemplateEngine.substitute(template, with: contacts[index].fields)

            do {
                try await sendMessage(personalizedMessage, to: results[index].phoneNumber)
                results[index].status = .sent
            } catch {
                results[index].status = .failed(error.localizedDescription)
            }

            if index < results.count - 1 && isSending {
                try? await Task.sleep(nanoseconds: UInt64(delayBetweenMessages * 1_000_000_000))
            }
        }

        isSending = false
    }

    func cancel() {
        isSending = false
        for index in results.indices {
            if case .pending = results[index].status {
                results[index].status = .failed("Cancelled")
            }
            if case .sending = results[index].status {
                results[index].status = .failed("Cancelled")
            }
        }
    }

    func reset() {
        results = []
        currentIndex = 0
        isSending = false
    }

    // MARK: - Retry Failed

    func retryFailed(message: String) async {
        guard !isSending else { return }
        isSending = true

        let failedIndices = results.indices.filter { results[$0].status.isFailed }

        for index in failedIndices {
            guard isSending else { break }

            results[index].status = .sending

            do {
                try await sendMessage(message, to: results[index].phoneNumber)
                results[index].status = .sent
            } catch {
                results[index].status = .failed(error.localizedDescription)
            }

            if index != failedIndices.last && isSending {
                try? await Task.sleep(nanoseconds: UInt64(delayBetweenMessages * 1_000_000_000))
            }
        }

        isSending = false
    }

    // MARK: - AppleScript Sending

    private func sendMessage(_ message: String, to phoneNumber: String) async throws {
        let sanitizedMessage = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let sanitizedPhone = phoneNumber
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        // Try SMS service first, then iMessage, then generic buddy as fallback
        let smsScript = """
        tell application "Messages"
            set targetService to 1st account whose service type = SMS
            set targetBuddy to buddy "\(sanitizedPhone)" of targetService
            send "\(sanitizedMessage)" to targetBuddy
        end tell
        """

        let iMessageScript = """
        tell application "Messages"
            set targetService to 1st account whose service type = iMessage
            set targetBuddy to buddy "\(sanitizedPhone)" of targetService
            send "\(sanitizedMessage)" to targetBuddy
        end tell
        """

        do {
            try await runAppleScript(smsScript)
        } catch {
            try await runAppleScript(iMessageScript)
        }
    }

    private func runAppleScript(_ source: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                let appleScript = NSAppleScript(source: source)
                let result = appleScript?.executeAndReturnError(&error)

                DispatchQueue.main.async {
                    if let error = error {
                        let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                        continuation.resume(throwing: MessageSendError.appleScriptError(errorMessage))
                    } else if result == nil {
                        continuation.resume(throwing: MessageSendError.appleScriptError("Script returned nil"))
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }
}

// MARK: - Errors

enum MessageSendError: LocalizedError {
    case appleScriptError(String)
    case noPhoneNumber
    case cancelled

    var errorDescription: String? {
        switch self {
        case .appleScriptError(let message):
            return "Messages error: \(message)"
        case .noPhoneNumber:
            return "No phone number available"
        case .cancelled:
            return "Sending was cancelled"
        }
    }
}
