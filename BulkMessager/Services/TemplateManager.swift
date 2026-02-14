import Foundation
import SwiftUI

@MainActor
class TemplateManager: ObservableObject {
    @Published var templates: [MessageTemplate] = []
    @Published var selectedTemplate: MessageTemplate?

    private let templatesFileURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("message_templates.json")
    }()

    init() {
        loadTemplates()
    }

    func addTemplate(name: String, content: String) {
        let template = MessageTemplate(name: name, content: content)
        templates.append(template)
        saveTemplates()
    }

    func updateTemplate(_ template: MessageTemplate, name: String, content: String) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index].name = name
            templates[index].content = content
            templates[index].lastModified = Date()
            saveTemplates()
        }
    }

    func deleteTemplate(_ template: MessageTemplate) {
        templates.removeAll { $0.id == template.id }
        if selectedTemplate?.id == template.id {
            selectedTemplate = nil
        }
        saveTemplates()
    }

    func selectTemplate(_ template: MessageTemplate) {
        selectedTemplate = template
    }

    private func saveTemplates() {
        do {
            let data = try JSONEncoder().encode(templates)
            try data.write(to: templatesFileURL)
        } catch {
            print("Failed to save templates: \(error)")
        }
    }

    private func loadTemplates() {
        do {
            let data = try Data(contentsOf: templatesFileURL)
            templates = try JSONDecoder().decode([MessageTemplate].self, from: data)
        } catch {
            createDefaultTemplates()
        }
    }

    private func createDefaultTemplates() {
        templates = [
            MessageTemplate(
                name: "New Number",
                content: "Hey {{name}}! I changed my phone number. My new number is: [YOUR NEW NUMBER]. Please save it! 😊"
            ),
            MessageTemplate(
                name: "Meeting Reminder",
                content: "Hi {{name}}, this is a reminder about our meeting tomorrow. Looking forward to connecting with you!"
            ),
            MessageTemplate(
                name: "Thank You",
                content: "Thank you {{name}} for your time today! It was great talking with you."
            )
        ]
        saveTemplates()
    }
}
