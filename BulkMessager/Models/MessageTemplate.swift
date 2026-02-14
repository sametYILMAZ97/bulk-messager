import Foundation

struct MessageTemplate: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var name: String
    var content: String
    let createdAt: Date
    var lastModified: Date

    init(id: UUID = UUID(), name: String, content: String, createdAt: Date = Date(), lastModified: Date = Date()) {
        self.id = id
        self.name = name
        self.content = content
        self.createdAt = createdAt
        self.lastModified = lastModified
    }

    var variables: [String] {
        MessageTemplateEngine.extractVariables(from: content)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MessageTemplate, rhs: MessageTemplate) -> Bool {
        lhs.id == rhs.id
    }
}

struct MessageTemplateEngine {
    static func substitute(_ template: String, with fields: [String: String]) -> String {
        var result = template
        let pattern = #"\{\{([a-zA-Z0-9_]+)\}\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return template
        }

        let nsString = template as NSString
        let matches = regex.matches(in: template, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            if match.numberOfRanges >= 2 {
                let fullMatchRange = match.range(at: 0)
                let variableRange = match.range(at: 1)
                let variableName = nsString.substring(with: variableRange)
                let replacement = fields[variableName.lowercased()] ?? ""
                result = (result as NSString).replacingCharacters(in: fullMatchRange, with: replacement)
            }
        }

        return result
    }

    static func extractVariables(from template: String) -> [String] {
        let pattern = #"\{\{([a-zA-Z0-9_]+)\}\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let nsString = template as NSString
        let matches = regex.matches(in: template, options: [], range: NSRange(location: 0, length: nsString.length))

        var variables: [String] = []
        for match in matches {
            if match.numberOfRanges >= 2 {
                let variableRange = match.range(at: 1)
                let variableName = nsString.substring(with: variableRange)
                if !variables.contains(variableName) {
                    variables.append(variableName)
                }
            }
        }

        return variables
    }

    static func preview(template: String, for contact: any ContactRepresentable) -> String {
        substitute(template, with: contact.customFields)
    }
}
